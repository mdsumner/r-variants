# offline.R -- point extraction at (x, y, t) from a lazy array, no network
#
# A synthetic lazy array with the layout of the CMEMS global waves Zarr
# (geoChunked: chunks of 17720 time x 8 lat x 4 lon, 0.2 degree grid,
# 3-hourly), shortened in time so it runs anywhere. Each value is a known
# function of (lon, lat, time), so results can be checked exactly. The
# fetch sleeps `latency` seconds per call, standing in for one round of
# concurrent HTTP requests.
#
# Shows:
#   1. x[cbind(i, j, k)] for 300 points is one fetch call, touching only
#      the distinct chunks the points fall in
#   2. a per-point loop makes 300 fetch calls for the same chunks
#   3. bilinear-in-space, linear-in-time interpolation (8 values per
#      point) is still one call, and touches barely more chunks
#
# Runs the same on the baseline and array-subset images: point extraction
# uses x[matrix], which base R already hands to altarr whole.
# ASCII only.

library(altarr)
source("xyt_extract.R")

lon <- seq(-180, 179.8, by = 0.2)               # 1800
lat <- seq(-80, 90, by = 0.2)                   # 851, south to north
tim <- seq(0, by = 3 * 3600, length.out = 4000) # 3-hourly seconds
d <- c(length(lon), length(lat), length(tim))   # R order: lon, lat, time
cs <- c(4L, 8L, 1000L)                          # reversed Zarr chunks, time shortened

field <- function(x, y, t) sin(x / 20) + cos(y / 15) + t / 86400 / 100

latency <- as.numeric(Sys.getenv("XYT_LATENCY", "0.05"))
fetch <- function(chunks) {
  Sys.sleep(latency)
  lapply(seq_len(nrow(chunks)), function(r) {
    st <- chunks[r, ] * cs + 1L
    en <- pmin(st + cs - 1L, d)
    g <- expand.grid(i = st[1]:en[1], j = st[2]:en[2], k = st[3]:en[3])
    field(lon[g$i], lat[g$j], tim[g$k])
  })
}
x <- altarr(d, cs, fetch, dimnames = list(lon = NULL, lat = NULL, time = NULL))

set.seed(1)
n <- 300
px <- runif(n, 60, 160); py <- runif(n, -65, -45)
pt <- runif(n, 0, max(tim))
co <- list(x = lon, y = lat, t = tim)

cat("lazy array:", paste(dim(x), collapse = " x "), " chunks:",
    paste(cs, collapse = " x "), "\n")
cat(sprintf("chunk: %d values, %.1f MB as float32 at full CMEMS length\n",
            prod(cs), 17720 * 8 * 4 * 4 / 1e6))

report <- function(label, expr) {
  altarr_reset(x)
  tm <- system.time(v <- force(expr))[["elapsed"]]
  s <- altarr_stats(x)
  cat(sprintf("%-34s fetch calls %4d  chunks %4d  %6.2f s\n", label,
              as.integer(s[["fetch_calls"]]), as.integer(s[["chunks_fetched"]]), tm))
  v
}

v1 <- report("planned, nearest (one x[idx])", xyt_extract(x, co, px, py, pt))
idx <- cbind(round(frac_index(lon, px)), round(frac_index(lat, py)),
             round(frac_index(tim, pt)))
v2 <- report("per-point loop", vapply(seq_len(n), function(p)
  x[idx[p, , drop = FALSE]], numeric(1)))
v3 <- report("planned, linear (8-value stencil)",
             xyt_extract(x, co, px, py, pt, method = "linear"))

stopifnot(identical(v1, v2))
stopifnot(isTRUE(all.equal(v1, field(lon[idx[, 1]], lat[idx[, 2]], tim[idx[, 3]]))))
cat("nearest values exact; linear max abs diff from the field:",
    signif(max(abs(v3 - field(px, py, pt))), 3), "\n")
