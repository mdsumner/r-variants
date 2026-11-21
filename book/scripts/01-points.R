# 01-points.R -- values at 300 scattered (x, y, t) points. ASCII only.
#
# A synthetic array with the layout of the CMEMS global waves Zarr (chunks
# of 4 lon x 8 lat x many time steps), shortened in time. The same job two
# ways: one x[cbind(i, j, k)], and a loop of x[i, j, k].
here <- function() {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  if (length(f)) dirname(f[1]) else "scripts"
}
source(file.path(here(), "_bench.R"))

x <- synthetic(c(1800, 851, 4000), c(4, 8, 1000))

set.seed(1)
n <- 300
idx <- cbind(sample(1201:1700, n, replace = TRUE),   # 60E to 160E
             sample(76:176, n, replace = TRUE),      # 65S to 45S
             sample(4000, n, replace = TRUE))

a <- bench("300 points: one x[cbind(i, j, k)]", x, x[idx])
b <- bench("300 points: a loop of x[i, j, k]", x,
           vapply(seq_len(n), function(p) x[idx[p, 1], idx[p, 2], idx[p, 3]],
                  numeric(1)))
stopifnot(identical(a, b))
stopifnot(a[1] == (idx[1, 1] - 1) + (idx[1, 2] - 1) * 1800 +
            (idx[1, 3] - 1) * 1800 * 851)
finish()
