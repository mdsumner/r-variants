# 03-cmems.R -- Copernicus Marine Zarr V2 stores, read in place. ASCII only.
#
# Global daily sea level (1/8 degree, 1993 on) is published twice: chunked
# for maps (timeChunked) and for time series (geoChunked). Global 3-hourly
# waves (0.2 degree, 1980 on) is read from its geoChunked copy. Public, no
# credentials. BOOK_MAX_CON (default 8) caps concurrent connections.
here <- function() {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  if (length(f)) dirname(f[1]) else "scripts"
}
source(file.path(here(), "_bench.R"))
suppressPackageStartupMessages(library(zaro))
options(zaro.verbose = FALSE,
        zaro.max_con = as.integer(Sys.getenv("BOOK_MAX_CON", "8")))
count_http()

host <- "https://s3.waw3-1.cloudferro.com/"
sl <- paste0("SEALEVEL_GLO_PHY_L4_MY_008_047/",
             "cmems_obs-sl_glo_phy-ssh_my_allsat-l4-duacs-0.125deg_P1D_202411/")
ds_t <- zaro_dataset(zaro(paste0(host, "mdl-arco-time-045/arco/", sl, "timeChunked.zarr")))
ds_g <- zaro_dataset(zaro(paste0(host, "mdl-arco-geo-045/arco/", sl, "geoChunked.zarr")))
sla_t <- zaro_array(ds_t, "sla", cf = TRUE)     # longitude, latitude, time
sla_g <- zaro_array(ds_g, "sla", cf = TRUE)
cat("sea level:", paste(dim(sla_t), collapse = " x "), "\n")

lon <- as.vector(zaro_read(ds_t, "longitude"))
lat <- as.vector(zaro_read(ds_t, "latitude"))
i <- which.min(abs(lon - 155))                  # Tasman Sea
j <- which.min(abs(lat - -35))
ix <- which(lon >= 145 & lon <= 165)
iy <- which(lat >= -45 & lat <= -25)
nt <- dim(sla_t)[3]

bench("sea level, one day's map: sla[, , day]", sla_t, sla_t[, , nt])
bench("sea level, Tasman Sea for 14 days: sla[ix, iy, days]", sla_t,
      sla_t[ix, iy, (nt - 13):nt])
bench("sea level, every day at one cell: sla[i, j, ]", sla_g, sla_g[i, j, ])

wav <- zaro(paste0(host, "mdl-arco-geo-032/arco/GLOBAL_MULTIYEAR_WAV_001_032/",
                   "cmems_mod_glo_wav_my_0.2deg_PT3H-i_202411/geoChunked.zarr"))
hs <- zaro_array(wav, "VHM0", cf = TRUE)        # longitude, latitude, time
cat("waves:", paste(dim(hs), collapse = " x "), "\n")
wlon <- as.numeric(unlist(zaro_read(wav, "longitude")))
wlat <- as.numeric(unlist(zaro_read(wav, "latitude")))
wi <- which.min(abs(wlon - 140))                # Southern Ocean, south of Australia
wj <- which.min(abs(wlat - -50))
wt <- dim(hs)[3]

bench("waves, every 3 hours since 1980 at one cell: hs[i, j, ]", hs, hs[wi, wj, ])
bench("waves, a year in a 2 degree box: hs[i:(i+9), j:(j+9), year]", hs,
      hs[wi:(wi + 9), wj:(wj + 9), (wt - 2919):wt])
finish()
