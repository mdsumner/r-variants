## Wrap a double array 'x' in an ALTREP object whose Extract_array_subset
## method behaves according to 'mode':
##   "ok"        compute the values (the honest implementation)
##   "decline"   return C NULL, so R uses its element loop
##   "rnull"     return R_NilValue (an R NULL) instead of C NULL
##   "badlen"    return one value too few
##   "attrib"    return the right values with a names attribute
##   "shared"    return the right values from a vector the class keeps
##   "scribble"  compute the values, then overwrite the subscripts it was given
altsub <- function(x, mode = "ok") {
  modes <- c("ok", "decline", "rnull", "badlen", "attrib", "shared", "scribble")
  m <- match(mode, modes) - 1L
  if (is.na(m)) stop("unknown mode")
  ans <- .Call(C_altsub_make, as.double(x), m)
  dim(ans) <- dim(x)
  dimnames(ans) <- dimnames(x)
  ans
}
## c(method = calls to Extract_array_subset, elt = Elt calls)
altsub_counts <- function(reset = FALSE) .Call(C_altsub_counts, reset)
