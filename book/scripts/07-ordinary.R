# 07-ordinary.R -- R code that was not written for lazy arrays. ASCII only.
#
# The same simulated store as 02-rectangles.R, with names on the time
# dimension. Every read below is plain base R.
here <- function() {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  if (length(f)) dirname(f[1]) else "scripts"
}
source(file.path(here(), "_bench.R"))

x <- synthetic(c(1000, 800, 60), c(100, 100, 10),
               dimnames = list(NULL, NULL, paste0("t", 1:60)))

# negative, logical and character subscripts: R resolves them all
keep <- rep(c(TRUE, FALSE), 400)
bench("x[-(1:900), keep, \"t30\"]", x, x[-(1:900), keep, "t30"])

# a function written for ordinary arrays
time_mean <- function(a, i, j) apply(a[i, j, , drop = FALSE], c(1, 2), mean)
bench("apply() over x[101:150, 201:260, , drop = FALSE]", x,
      time_mean(x, 101:150, 201:260))

# a loop over time steps
bench("for each of 20 steps: sum(x[201:400, 301:500, k])", x,
      vapply(1:20, function(k) sum(x[201:400, 301:500, k]), numeric(1)))

# R's own wrapper object, made by changing attributes on a shared array
y <- x
dimnames(y) <- list(lon = NULL, lat = NULL, time = paste0("t", 1:60))
bench("after dimnames<- on a copy: y[1:250, 1:250, 1:15]", x, y[1:250, 1:250, 1:15])
finish()
