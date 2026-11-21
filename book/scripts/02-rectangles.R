# 02-rectangles.R -- x[i, j, k] and m[i, j] on a simulated store. ASCII only.
#
# 1000 x 800 x 60 doubles in chunks of 100 x 100 x 10, and a 4000 x 3000
# matrix in chunks of 256 x 256. Nothing is allocated: values are computed
# from position, and each fetch call sleeps 50 ms (BOOK_LATENCY).
here <- function() {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  if (length(f)) dirname(f[1]) else "scripts"
}
source(file.path(here(), "_bench.R"))

x <- synthetic(c(1000, 800, 60), c(100, 100, 10))
m <- synthetic(c(4000, 3000), c(256, 256))

a <- bench("block: x[1:250, 1:250, 1:15]", x, x[1:250, 1:250, 1:15])
bench("strided slice: x[seq(1, 1000, 50), , 30]", x, x[seq(1, 1000, 50), , 30])
p <- bench("series at one cell: x[500, 400, ]", x, x[500, 400, ])
bench("matrix window: m[1001:1600, 1001:1400]", m, m[1001:1600, 1001:1400])
e <- bench("the workaround: altarr_extract(x, 500, 400, )", x,
           altarr_extract(x, 500, 400, ))

stopifnot(identical(p, e), identical(dim(a), c(250L, 250L, 15L)),
          a[250, 250, 15] == 249 + 249 * 1000 + 14 * 800000)
finish()
