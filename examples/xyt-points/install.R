# Packages for the xyt examples. altarr and zaro come from GitHub; blosc
# decodes the CMEMS chunks. ASCII only.
repos <- "https://cloud.r-project.org"
need <- c("remotes", "curl", "jsonlite", "nanoparquet", "S7", "blosc")
miss <- need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
if (length(miss)) install.packages(miss, repos = repos)
if (!requireNamespace("altarr", quietly = TRUE))
  remotes::install_github("hypertidy/altarr", upgrade = "never")
if (!requireNamespace("zaro", quietly = TRUE))
  remotes::install_github("hypertidy/zaro", upgrade = "never")
if (nzchar(Sys.getenv("XYT_MIZU")) && !requireNamespace("mizu", quietly = TRUE))
  install.packages("mizu", repos = repos)
