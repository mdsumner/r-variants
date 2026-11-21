# 06-icechunk.R -- seal dives and the ocean model under them, both from
# Icechunk repositories on Source Cooperative. ASCII only.
#
# meop-ctd-2024: IMOS seal CTD profiles (MEOP quality control), one cube of
#   126,518 profiles by 1000 levels (1 dbar). Each profile is one virtual
#   chunk: 4000 bytes of a classic netCDF file in the IMOS public bucket.
# bluelink-daily-temp: BRAN temperature, daily from 1993, (xt_ocean,
#   yt_ocean, st_ocean 51, Time) in chunks of 300 x 300 x 1 x 1. Virtual
#   chunks: byte ranges of netCDF files on NCI's THREDDS server, so a model
#   profile under one dive is 51 chunks.
#
# THREDDS accepts about 4 concurrent requests: BOOK_THREDDS_CON (default 4).
here <- function() {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  if (length(f)) dirname(f[1]) else "scripts"
}
source(file.path(here(), "_bench.R"))
suppressPackageStartupMessages(library(zaro))
options(zaro.verbose = FALSE,
        zaro.max_con = as.integer(Sys.getenv("BOOK_THREDDS_CON", "4")))
if (!requireNamespace("tabularberg", quietly = TRUE)) {
  cat("tabularberg is not installed in this R; nothing run\n")
  quit(status = 0)
}
count_http()

coop <- "https://data.source.coop/ausantarctic/ausantarctic-scratch/"
open_repo <- function(path) {
  s <- zaro_icechunk(paste0(coop, path), authorize = "https://", direct = TRUE)
  cat(path, "snapshot", s@snapshot, "\n")
  zaro_dataset(s)
}

## the seals
meop <- open_repo("imos-tracking/meop-ctd-2024/icechunk")
obs_t <- zaro_array(meop, "TEMP_ADJUSTED", cf = TRUE)   # N_LEVELS, N_PROF
obs_p <- zaro_array(meop, "PRES_ADJUSTED", cf = TRUE)
cat("TEMP_ADJUSTED:", paste(dim(obs_t), collapse = " x "), "\n")
juld <- as.vector(zaro_read(meop, "JULD"))               # days since 1950-01-01
plat <- as.vector(zaro_read(meop, "LATITUDE"))
plon <- as.vector(zaro_read(meop, "LONGITUDE"))
tag <- as.vector(zaro_read(meop, "tag"))
ok <- is.finite(juld) & is.finite(plat) & is.finite(plon) &
  juld > 25202 & juld < 25567 &                          # the year 2019
  plat > -60 & plat < -45 & plon > 60 & plon < 90        # Kerguelen plateau
stopifnot(any(ok))
one <- which(ok & tag == tag[which(ok)[1]])              # one animal
sel <- one[unique(round(seq(1, length(one), length.out = 5)))]
dives <- data.frame(profile = sel, lon = plon[sel], lat = plat[sel],
                    date = as.Date("1950-01-01") + floor(juld[sel]))
print(dives)

## the model
bran <- open_repo("bluelink/bluelink-daily-temp/icechunk")
temp <- zaro_array(bran, "temp", cf = TRUE)              # degrees C, land as NA
cat("temp:", paste(dim(temp), collapse = " x "), "\n")
xt <- as.vector(zaro_read(bran, "xt_ocean"))
yt <- as.vector(zaro_read(bran, "yt_ocean"))
zt <- as.vector(zaro_read(bran, "st_ocean"))
tunits <- bran$arrays$Time@attributes$units
days <- as.Date(sub("^days since ([0-9-]+).*", "\\1", tunits)) +
  as.vector(zaro_read(bran, "Time"))
wrap <- function(v) ((v + 180) %% 360) - 180
i <- vapply(dives$lon, function(v) which.min(abs(wrap(xt - v))), 1L)
j <- vapply(dives$lat, function(v) which.min(abs(yt - v)), 1L)
k <- vapply(as.numeric(dives$date), function(v) which.min(abs(as.numeric(days) - v)), 1L)
nz <- dim(temp)[3]
nd <- length(sel)

seal <- bench("seal: 5 dives of one animal, TEMP_ADJUSTED[, dives]", obs_t, obs_t[, sel])
a <- bench("model: the profile under each dive, a loop of temp[i, j, , t]", temp,
           vapply(seq_len(nd), function(p) temp[i[p], j[p], , k[p]], numeric(nz)))
idx <- cbind(rep(i, each = nz), rep(j, each = nz), rep(seq_len(nz), nd), rep(k, each = nz))
b <- bench("model: the same values as one matrix subscript, temp[idx]", temp, temp[idx])
stopifnot(isTRUE(all.equal(as.vector(a), b)))

## both, for the figure in the chapter
if (dir.exists("results")) {
  pres <- obs_p[, sel]
  out <- rbind(
    data.frame(dive = rep(seq_len(nd), each = nrow(seal)), source = "seal",
               depth = as.vector(pres), temp = as.vector(seal)),
    data.frame(dive = rep(seq_len(nd), each = nz), source = "model",
               depth = rep(zt, nd), temp = as.vector(a)))
  out <- out[is.finite(out$depth) & is.finite(out$temp), ]
  out$label <- sprintf("%s  %.1fE %.1fS", dives$date, dives$lon, -dives$lat)[out$dive]
  utils::write.csv(out, "results/06-dives.csv", row.names = FALSE)
}
finish()
