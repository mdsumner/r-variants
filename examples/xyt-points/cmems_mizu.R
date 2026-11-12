# cmems_mizu.R -- the CMEMS extraction with chunk decode on a mizu pool
#
# After altarr has planned the batch and zaro_fetch() has fetched it, the
# remaining cost is decoding: blosc, then type conversion, then CF masking
# and unpacking, for every chunk, on R's main thread. Here the fetch stays
# in the main process (one curl pool) and the decode is spread over a mizu
# task pool on the same machine; mizu moves vectors through shared memory
# rather than sockets, so decoded chunks come back without serializing.
#
# It also times fetch and decode separately, which shows whether decode is
# worth parallelising for a given store and batch: with lz4 and a few
# hundred chunks, HTTP usually dominates; with zlib or zstd, or thousands
# of chunks (station time series), decode becomes visible.
#
#   XYT_MIZU=1 Rscript install.R
#   Rscript cmems_mizu.R [VAR] [N] [WORKERS]     defaults VHM0, 300, 4
# ASCII only.

library(zaro)
library(altarr)
library(mizu)
source("xyt_extract.R")

zarr_url <- paste0("https://s3.waw3-1.cloudferro.com/mdl-arco-geo-032/arco/",
                   "GLOBAL_MULTIYEAR_WAV_001_032/",
                   "cmems_mod_glo_wav_my_0.2deg_PT3H-i_202411/geoChunked.zarr")
args <- commandArgs(TRUE)
var <- if (length(args) >= 1) args[1] else "VHM0"
n <- if (length(args) >= 2) as.integer(args[2]) else 300L
nw <- if (length(args) >= 3) as.integer(args[3]) else 4L

zi <- function(f) getFromNamespace(f, "zaro")

timing <- new.env()
timing$fetch <- 0; timing$decode <- 0

# an altarr fetch: plan + pooled HTTP here, decode on the pool (or locally)
mizu_fetch_factory <- function(store, path, meta, spec, pool) {
  force(store); force(path); force(meta); force(spec); force(pool)
  d <- spec$dim; cs <- spec$chunk
  transform <- zi("cf_transform")(meta, spec$type)
  stored <- switch(zi("dtype_info")(meta@data_type)$what,
                   logical = "logical", integer = "integer", "double")
  fill <- suppressWarnings(as.double(
    zi("coerce_fill_value")(meta@fill_value, meta@data_type))[1L])
  dec <- function(task, meta, cs, d, stored, fill, transform) {
    st <- task$cc * cs + 1L
    ext <- as.integer(pmin(cs, d - st + 1L))
    post <- if (is.null(transform)) identity else transform
    if (is.null(task$raw)) return(post(rep(fill, prod(ext))))
    cast <- switch(stored, logical = as.logical, integer = as.integer, as.double)
    v <- cast(getFromNamespace("decode_planned", "zaro")(task$raw, meta, task$ref))
    post(getFromNamespace("clip_chunk", "zaro")(v, cs, ext))
  }
  function(chunks) {
    chunks <- matrix(as.integer(chunks), ncol = length(d))
    zidx <- chunks[, rev(seq_len(ncol(chunks))), drop = FALSE]
    t0 <- Sys.time()
    plan <- zaro_plan(store, path, meta = meta, chunks = zidx, verbose = FALSE)
    raws <- zaro_fetch(store, plan, verbose = FALSE)
    t1 <- Sys.time()
    tasks <- lapply(seq_len(nrow(chunks)), function(r)
      list(cc = chunks[r, ], raw = raws[[r]], ref = plan[r, ]))
    out <- if (is.null(pool)) {
      lapply(tasks, dec, meta = meta, cs = cs, d = d, stored = stored,
             fill = fill, transform = transform)
    } else {
      mizu_collect(mizu_map(pool, tasks, dec, meta = meta, cs = cs, d = d,
                            stored = stored, fill = fill,
                            transform = transform))
    }
    t2 <- Sys.time()
    timing$fetch <- timing$fetch + as.numeric(t1 - t0, units = "secs")
    timing$decode <- timing$decode + as.numeric(t2 - t1, units = "secs")
    out
  }
}

store <- zaro(zarr_url, verbose = FALSE)
meta <- zi("resolve_array_meta")(store, var, NULL, FALSE)
spec <- zi("zaro_array_spec")(meta)
spec$type <- "double"
rd <- function(v) as.numeric(unlist(zaro_read(store, v, verbose = FALSE)))
tunits <- zaro_meta(store, "time", verbose = FALSE)@attributes$units
mult <- c(seconds = 1, minutes = 60, hours = 3600, days = 86400)
epoch <- as.POSIXct(sub(".* since ", "", tunits), tz = "UTC")
co <- list(x = rd("longitude"), y = rd("latitude"),
           t = rd("time") * mult[[sub(" since.*", "", tunits)]])

set.seed(1)
px <- runif(n, 60, 160); py <- runif(n, -65, -45)
pt <- as.numeric(difftime(as.POSIXct("2024-01-01", tz = "UTC") +
                            runif(n, 0, 90 * 86400), epoch, units = "secs"))

pool <- mizu_pool(n_workers = nw)
on.exit(mizu_pool_stop(pool), add = TRUE)

res <- list()
for (mode in c("serial", "mizu")) {
  timing$fetch <- 0; timing$decode <- 0
  x <- altarr(spec$dim, spec$chunk,
              mizu_fetch_factory(store, var, meta, spec,
                                 if (mode == "mizu") pool else NULL),
              dimnames = spec$dimnames, type = "double")
  res[[mode]] <- xyt_extract(x, co, px, py, pt)
  s <- altarr_stats(x)
  cat(sprintf("%-6s decode: %d chunks, fetch %.2f s, decode %.2f s\n", mode,
              as.integer(s[["chunks_fetched"]]), timing$fetch, timing$decode))
}
stopifnot(identical(res$serial, res$mizu))
cat("serial and mizu decode give identical values\n")
