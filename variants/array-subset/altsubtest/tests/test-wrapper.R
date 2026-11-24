## Wrapper forwarding (R wrapper objects made by .Internal(wrap_meta())) and compact sequences.
library(altsubtest)
a <- array(as.double(1:60), c(3, 4, 5))
x <- altsub(a)
w <- .Internal(wrap_meta(x, 0L, 0L))
print(capture.output(.Internal(inspect(w)))[1:2])
altsub_counts(TRUE); stopifnot(identical(w[1:2, 3, 4:5], a[1:2, 3, 4:5])); print(altsub_counts(TRUE))
pw <- .Internal(wrap_meta(a, 0L, 0L))   # wrapper around a non-ALTREP array
stopifnot(identical(pw[1:2, 3, 4:5], a[1:2, 3, 4:5])); cat("plain wrapper ok\n")
## compact sequence arrays still work
s <- 1:24; dim(s) <- 2:4
print(capture.output(.Internal(inspect(s)))[1])
stopifnot(identical(s[2, 2:3, 4], (1:24)[c(22, 24)] ))
cat("ok\n")
