# 04-virtual.R -- BRAN ocean temperature through a virtual store.
# ASCII only.
#
# The data are monthly NetCDF files on NCI's THREDDS server. A kerchunk
# Parquet reference store on Source Cooperative (built by raad.virtualize)
# says where each chunk's bytes are; zaro reads those byte ranges in
# place. temp is (xt_ocean 3600, yt_ocean 1500, st_ocean 51, Time 12265:
# daily from 1993), int16, chunks of 300 x 300 x 1 x 1.
# THREDDS accepts about 4 concurrent requests: BOOK_THREDDS_CON (default 4).
here <- function() {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  if (length(f)) dirname(f[1]) else "scripts"
}
source(file.path(here(), "_bench.R"))
suppressPackageStartupMessages(library(zaro))
options(zaro.verbose = FALSE,
        zaro.max_con = as.integer(Sys.getenv("BOOK_THREDDS_CON", "4")))
count_http()

bran <- zaro(paste0("virtualizarr://https://data.source.coop/ausantarctic/",
                    "ausantarctic-scratch/bluelink/bluelink-daily-temp/kerchunk"))
ds <- zaro_dataset(bran)
temp <- zaro_array(ds, "temp", cf = TRUE)       # degrees C, land as NA
cat("temp:", paste(dim(temp), collapse = " x "), "\n")

xt <- as.vector(zaro_read(ds, "xt_ocean"))
yt <- as.vector(zaro_read(ds, "yt_ocean"))
i <- which.min(abs(xt - 150))                   # east of Tasmania
j <- which.min(abs(yt - -42))
jj <- which(yt >= -50 & yt <= -40)
nt <- dim(temp)[4]

bench("surface map, one day: temp[, , 1, day]", temp, temp[, , 1, nt])
bench("profile, 51 depths at one cell: temp[i, j, , day]", temp, temp[i, j, , nt])
bench("section, 40S to 50S by depth: temp[i, jj, , day]", temp, temp[i, jj, , nt])
bench("surface series, 30 days at one cell: temp[i, j, 1, days]", temp,
      temp[i, j, 1, (nt - 29):nt])
finish()
