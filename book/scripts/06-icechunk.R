# 06-icechunk.R -- an Icechunk repository, pinned to a tag. ASCII only.
#
# Uses the small repository tabularberg writes to tempdir(): array
# from_bin is four virtual chunks (byte ranges of a binary file). The read
# is the same x[i, j] as everywhere else; the store resolves each chunk
# through the snapshot's manifest.
here <- function() {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  if (length(f)) dirname(f[1]) else "scripts"
}
source(file.path(here(), "_bench.R"))
suppressPackageStartupMessages(library(zaro))
options(zaro.verbose = FALSE)
if (!requireNamespace("tabularberg", quietly = TRUE)) {
  cat("tabularberg is not installed in this R; nothing run\n")
  quit(status = 0)
}

ex <- tabularberg::ic_example_repo()
store <- zaro_icechunk(ex$path, tag = "v1", authorize = ex$authorize)
cat("snapshot:", store@snapshot, "\n")
x <- zaro_array(store, "from_bin")
cat("from_bin:", paste(dim(x), collapse = " x "), "\n")

bench("whole array: x[, ]", x, x[, ])
bench("a corner: x[1:4, 1:4]", x, x[1:4, 1:4])
finish()
