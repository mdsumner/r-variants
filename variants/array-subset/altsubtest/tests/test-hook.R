## Tests for the proposed Extract_array_subset ALTREP method.
## On an R without the method every check still runs: the counts differ.
library(altsubtest)
a <- array(as.double(1:60), c(3, 4, 5))
m <- matrix(as.double(1:12), 3, 4)
same <- function(x, y) stopifnot(identical(x, y))
cnt <- function() altsub_counts(reset = TRUE)

## 1. honest method: identical to base R for many subscript forms
x <- altsub(a); mx <- altsub(m)
cases <- list(
  quote(X[1:2, 2:3, 4]), quote(X[, , 1]), quote(X[3, 4, 5]),
  quote(X[c(3, NA, 1), -1, c(TRUE, FALSE)]), quote(X[integer(0), , 1]),
  quote(X[2, , , drop = FALSE]), quote(X[c(1, 1, 2), 4:1, 5]))
for (e in cases) {
  cnt()
  same(eval(e, list(X = x)), eval(e, list(X = a)))
  cat(deparse(e), " method:", altsub_counts()[["method"]],
      " elt:", altsub_counts()[["elt"]], "\n")
}
for (e in list(quote(X[2:3, c(4, NA)]), quote(X[, 2]), quote(X[-2, ]))) {
  cnt()
  same(eval(e, list(X = mx)), eval(e, list(X = m)))
  cat(deparse(e), " method:", altsub_counts()[["method"]],
      " elt:", altsub_counts()[["elt"]], "\n")
}

## 2. dimnames: R subsets them; the wrapper forwards
dn <- a; dimnames(dn) <- list(letters[1:3], NULL, LETTERS[1:5])
xd <- altsub(dn); cnt()
same(xd[c("b", "c"), 2, "E"], dn[c("b", "c"), 2, "E"])
cat("dimnames method:", altsub_counts()[["method"]], "\n")
xw <- altsub(a); dimnames(xw) <- dimnames(dn)
cat("after dimnames<-, wrapper:",
    grepl("wrap_real", capture.output(.Internal(inspect(xw)))[1]), "\n")
cnt(); same(xw[c("b", "c"), 2, "E"], dn[c("b", "c"), 2, "E"])
cat("wrapper method:", altsub_counts()[["method"]], "\n")

## 3. declining gives the element loop
cnt(); same(altsub(a, "decline")[1:2, 2, 3], a[1:2, 2, 3])
print(altsub_counts())

## 4. misbehaving methods
err <- function(expr) tryCatch({ expr; "no error" },
                               error = function(e) conditionMessage(e))
cat("rnull :", err(altsub(a, "rnull")[1, 1, 1]), "\n")
cat("badlen:", err(altsub(a, "badlen")[1:2, 1, 1]), "\n")
cat("attrib:", err(altsub(a, "attrib")[1:2, 1, 1]), "\n")
xs <- altsub(a, "shared")
r1 <- xs[1:2, 1, 1]; r2 <- xs[1:2, 1, 1]
same(r1, a[1:2, 1, 1]); same(attributes(r1), NULL)
cat("shared: ok, result is a fresh copy\n")

## 5. a method that writes into the subscripts it was given
ii <- c(3L, 2L)
xs <- altsub(dn, "scribble")
got <- tryCatch(xs[ii, 1, 1:2], error = function(e) conditionMessage(e))
print(got); cat("caller's ii is still", ii, "\n")

## 6. out-of-bounds errors: compare a plain and an ALTREP matrix
oob <- function(X) tryCatch(X[5, 9], error = function(e)
  c(class = class(e)[1], subscript = e$subscript, index = e$index))
print(rbind(plain = oob(m), altrep = oob(mx)))
seqm <- 1:12; dim(seqm) <- c(3L, 4L)   # compact sequence, still ALTREP
print(rbind(plain = oob(matrix(1:12, 3)), compact = oob(seqm)))
oob3 <- function(X) tryCatch(X[5, 9, 1], error = function(e)
  c(subscript = e$subscript, index = e$index))
print(rbind(plain = oob3(a), altrep = oob3(x)))

## 7. gctorture over the hook
gctorture(TRUE)
r <- x[1:2, 2:3, 4:5]; rm <- mx[2:3, 1:2]; rd <- xd[c("b", "c"), 2, "E"]
gctorture(FALSE)
same(r, a[1:2, 2:3, 4:5]); same(rm, m[2:3, 1:2])
cat("gctorture: ok\nall done\n")
