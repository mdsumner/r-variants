# 05-sharded.R -- a sharded Zarr V3 product: Sentinel-2 L2A from the EOPF
# sample service. ASCII only.
#
# Bands are matrices, so every read here is m[i, j]: the MatrixSubset()
# path in R, separate from the array path. Each band is one shard file
# holding many inner chunks; a chunk is a byte range of the shard.
here <- function() {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  if (length(f)) dirname(f[1]) else "scripts"
}
source(file.path(here(), "_bench.R"))
suppressPackageStartupMessages(library(zaro))
options(zaro.verbose = FALSE,
        zaro.max_con = as.integer(Sys.getenv("BOOK_MAX_CON", "8")))
count_http()

eopf <- zaro(paste0("https://s3.explorer.eopf.copernicus.eu/esa-zarr-sentinel-explorer-fra/",
                    "tests-output/sentinel-2-l2a/",
                    "S2C_MSIL2A_20260120T084301_N0511_R064_T36UXA_20260120T122910.zarr"))
r120 <- zaro_dataset(eopf, group = "measurements/reflectance/r120m")
r10 <- zaro_dataset(eopf, group = "measurements/reflectance/r10m")
b120 <- zaro_array(r120, "b04")                 # x, y
b10 <- zaro_array(r10, "b04")
cat("b04 at 120 m:", paste(dim(b120), collapse = " x "),
    " at 10 m:", paste(dim(b10), collapse = " x "), "\n")

bench("whole band at 120 m: b[, ]", b120, b120[, ])
bench("1000 x 1000 window at 10 m: b[5001:6000, 5001:6000]", b10,
      b10[5001:6000, 5001:6000])
bench("every 10th pixel of a 4000 x 4000 window at 10 m", b10,
      b10[seq(3001, 7000, 10), seq(3001, 7000, 10)])
finish()
