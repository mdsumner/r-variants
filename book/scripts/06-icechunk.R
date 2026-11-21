# 06-icechunk.R -- Bluelink (BRAN) temperature from an Icechunk repository,
# at the places and times of seal dives. ASCII only.
#
# The repository is on Source Cooperative (public). Its chunks are virtual:
# byte ranges of the BRAN netCDF files on NCI's THREDDS server. temp is
# (xt_ocean, yt_ocean, st_ocean 51, Time), daily from 1993, in chunks of
# 300 x 300 x 1 x 1, so a model profile under one dive is 51 chunks.
# THREDDS accepts about 4 concurrent requests: BOOK_THREDDS_CON (default 4).
#
# The dives below are made up (Kerguelen plateau, 2019) until the IMOS
# seal CTD profile store supplies real ones.
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

repo <- paste0("https://data.source.coop/ausantarctic/ausantarctic-scratch/",
               "bluelink/bluelink-daily-temp/icechunk")
store <- zaro_icechunk(repo, authorize = "https://", direct = TRUE)
cat("snapshot:", store@snapshot, "\n")
ds <- zaro_dataset(store)
temp <- zaro_array(ds, "temp", cf = TRUE)       # degrees C, land as NA
cat("temp:", paste(dim(temp), collapse = " x "), "\n")

xt <- as.vector(zaro_read(ds, "xt_ocean"))
yt <- as.vector(zaro_read(ds, "yt_ocean"))
tunits <- zaro_meta(store, "Time")@attributes$units
days <- as.Date(sub("^days since ([0-9-]+).*", "\\1", tunits)) +
  as.vector(zaro_read(ds, "Time"))
cat("time:", format(range(days)), "\n")

dives <- data.frame(lon = c(71.4, 73.1, 75.6), lat = c(-49.8, -51.2, -52.9),
                    date = as.Date(c("2019-03-04", "2019-03-11", "2019-03-19")))
i <- vapply(((dives$lon + 180) %% 360) - 180, function(v) which.min(abs(((xt + 180) %% 360) - 180 - v)), 1L)
j <- vapply(dives$lat, function(v) which.min(abs(yt - v)), 1L)
k <- vapply(dives$date, function(v) which.min(abs(as.numeric(days - v))), 1L)
nz <- dim(temp)[3]

a <- bench("model profile under each of 3 dives: a loop of temp[i, j, , t]", temp,
           vapply(seq_along(i), function(p) temp[i[p], j[p], , k[p]], numeric(nz)))
idx <- cbind(rep(i, each = nz), rep(j, each = nz), rep(seq_len(nz), 3), rep(k, each = nz))
b <- bench("the same values as one matrix subscript: temp[idx]", temp, temp[idx])
bench("three days around one dive: temp[i, j, , (t-1):(t+1)]", temp,
      temp[i[1], j[1], , (k[1] - 1):(k[1] + 1)])
stopifnot(isTRUE(all.equal(as.vector(a), b)))
finish()
