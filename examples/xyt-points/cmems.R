# cmems.R -- the same extraction from the live CMEMS global waves Zarr
#
# Store: GLOBAL_MULTIYEAR_WAV_001_032, 0.2 degree, 3-hourly, geoChunked
# (chunks 17720 time x 8 lat x 4 lon; blosc lz4 with byte shuffle). Public,
# no credentials. zaro_array() presents a variable as a lazy
# (longitude, latitude, time) array; one x[cbind(i, j, k)] plans the
# distinct chunks of all points and zaro_fetch() GETs them through one curl
# pool capped at getOption("zaro.max_con", 8) connections.
#
#   Rscript cmems.R [VAR] [N]      defaults VHM0, 300
#
# Compare with a terra version of the same job, which groups points by
# chunk key by hand and runs groups across worker processes: the chunk
# count (bytes moved) is the same; the planning and the concurrency here
# come from altarr and zaro.
# ASCII only.

options(zaro.max_con = as.integer(Sys.getenv("XYT_MAX_CON", "8")))
library(zaro)
library(altarr)
source("xyt_extract.R")

zarr_url <- paste0("https://s3.waw3-1.cloudferro.com/mdl-arco-geo-032/arco/",
                   "GLOBAL_MULTIYEAR_WAV_001_032/",
                   "cmems_mod_glo_wav_my_0.2deg_PT3H-i_202411/geoChunked.zarr")

args <- commandArgs(TRUE)
var <- if (length(args) >= 1) args[1] else "VHM0"
n <- if (length(args) >= 2) as.integer(args[2]) else 300L

t_open <- system.time({
  store <- zaro(zarr_url, verbose = FALSE)
  x <- zaro_array(store, var, cf = TRUE, verbose = FALSE)
  rd <- function(v) as.numeric(unlist(zaro_read(store, v, verbose = FALSE)))
  tunits <- zaro_meta(store, "time", verbose = FALSE)@attributes$units
  mult <- c(seconds = 1, minutes = 60, hours = 3600, days = 86400)
  epoch <- as.POSIXct(sub(".* since ", "", tunits), tz = "UTC")
  co <- list(x = rd("longitude"), y = rd("latitude"),
             t = rd("time") * mult[[sub(" since.*", "", tunits)]])
})[["elapsed"]]
cat(sprintf("%s: %s (%s), opened in %.1f s\n", var,
            paste(dim(x), collapse = " x "),
            paste(names(dimnames(x)), collapse = ", "), t_open))
cat("time:", format(epoch + range(co$t)), "\n")

set.seed(1)
xyt <- data.frame(x = runif(n, 60, 160), y = runif(n, -65, -45),
                  t = as.POSIXct("2024-01-01", tz = "UTC") +
                    runif(n, 0, 90 * 86400))
pt <- as.numeric(difftime(xyt$t, epoch, units = "secs"))

altarr_reset(x)
tm <- system.time(xyt[[var]] <- xyt_extract(x, co, ((xyt$x + 180) %% 360) - 180,
                                            xyt$y, pt))[["elapsed"]]
s <- altarr_stats(x)
cat(sprintf("%d points: %d fetch call(s), %d chunks, %.1f s\n", n,
            as.integer(s[["fetch_calls"]]), as.integer(s[["chunks_fetched"]]), tm))
print(head(xyt, 10))
cat("NA rate (land, ice):", round(mean(is.na(xyt[[var]])), 3), "\n")
write.csv(xyt, sprintf("xyt_%s.csv", var), row.names = FALSE)
