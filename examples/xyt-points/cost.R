# xyt_cost.R -- what point extraction at (x, y, t) costs, by chunk layout
#
# Base R only; no data is read. For a set of (i, j, t) array indices this
# counts the chunks each strategy touches, which is what drives bytes moved
# and round trips for compressed chunked stores (Zarr, NetCDF4, COG): a
# compressed chunk is all or nothing.
#
# Strategies:
#   per_point    each point read on its own (one chunk per point, no reuse;
#                roughly a naive loop, or a reader without a block cache)
#   per_layer    one read per distinct time step, each read touching the
#                spatial chunks its points fall in (layer-wise extract)
#   series       the full time series at each point, then pick t (what an
#                extract over all layers of a multi-layer raster does)
#   planned      the distinct chunks of the whole index set, fetched in one
#                batch (altarr x[cbind(i, j, t)])
#
# ASCII only.

chunk_id <- function(idx, chunk, grid) {
  cc <- sweep(idx - 1L, 2L, chunk, "%/%")
  as.numeric(cc %*% cumprod(c(1, grid[-length(grid)])))
}

xyt_cost <- function(idx, dim, chunk, bytes_per_value = 2) {
  grid <- ceiling(dim / chunk)
  cid <- chunk_id(idx, chunk, grid)
  cb <- prod(chunk) * bytes_per_value
  n <- nrow(idx)
  # per_layer: group by t, distinct chunks within each layer
  per_layer <- sum(tapply(cid, idx[, 3], function(z) length(unique(z))))
  # series: every point reads every chunk along t at its (i, j)
  sp <- unique(chunk_id(cbind(idx[, 1:2, drop = FALSE], 1L), chunk, grid))
  series <- length(sp) * grid[3]
  planned <- length(unique(cid))
  data.frame(strategy = c("per_point", "per_layer", "series", "planned"),
             chunks = c(n, per_layer, series, planned),
             round_trips = c(n, length(unique(idx[, 3])), length(sp), 1),
             MB = c(n, per_layer, series, planned) * cb / 1e6)
}

set.seed(1)
dim <- c(3600L, 1500L, 5479L)        # BRAN2023-like lon x lat x day, 15 years

layouts <- list(
  "1 day x 300 x 300 (map chunks)"   = c(300L, 300L, 1L),
  "30 days x 100 x 100 (balanced)"   = c(100L, 100L, 30L),
  "365 days x 30 x 30 (series)"      = c(30L, 30L, 365L)
)

# A: 1000 random points, random days (e.g. observation match-up)
A <- cbind(sample(dim[1], 1000, TRUE), sample(dim[2], 1000, TRUE),
           sample(dim[3], 1000, TRUE))

# B: an animal track, 4 fixes a day for 250 days, slow random walk
nB <- 1000
B <- cbind(pmin(pmax(round(2000 + cumsum(rnorm(nB, 0, 2))), 1), dim[1]),
           pmin(pmax(round(400 + cumsum(rnorm(nB, 0, 2))), 1), dim[2]),
           3000L + (seq_len(nB) - 1L) %/% 4L)

# C: 50 fixed stations, every day of 2 years
st <- cbind(sample(dim[1], 50, TRUE), sample(dim[2], 50, TRUE))
days <- 4000:(4000 + 729)
C <- cbind(rep(st[, 1], length(days)), rep(st[, 2], length(days)),
           rep(days, each = 50))

cases <- list("A: 1000 random xyt" = A, "B: track 1000 fixes" = B,
              "C: 50 stations x 730 days" = C)

for (cn in names(cases)) {
  cat("\n==", cn, "(", nrow(cases[[cn]]), "points ) ==\n")
  for (ln in names(layouts)) {
    r <- xyt_cost(cases[[cn]], dim, layouts[[ln]])
    r$MB <- round(r$MB, 1)
    cat("--", ln, "\n")
    print(r, row.names = FALSE)
  }
}

# Linear interpolation stencil: 8 corner values per point instead of 1.
# Planned cost barely moves, because corners almost always share chunks.
stencil <- function(idx) {
  co <- expand.grid(a = 0:1, b = 0:1, c = 0:1)
  out <- do.call(rbind, lapply(seq_len(8), function(k)
    sweep(idx, 2L, c(co$a[k], co$b[k], co$c[k]), "+")))
  pmin(out, matrix(dim, nrow(out), 3, byrow = TRUE))
}
cat("\n== linear stencil (8 values per point), planned chunks ==\n")
for (cn in names(cases)) for (ln in names(layouts)) {
  p1 <- length(unique(chunk_id(cases[[cn]], layouts[[ln]], ceiling(dim / layouts[[ln]]))))
  p8 <- length(unique(chunk_id(stencil(cases[[cn]]), layouts[[ln]], ceiling(dim / layouts[[ln]]))))
  cat(sprintf("%-28s %-34s nearest %6d  linear %6d\n", cn, ln, p1, p8))
}
