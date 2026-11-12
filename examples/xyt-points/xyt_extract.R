# xyt_extract.R -- values at (x, y, t) points from any R array, lazy or not
#
# Works on an ordinary array and on an altarr lazy array alike: the work is
# turning coordinates into one index matrix and calling x[idx] once. With
# altarr that single call plans the distinct chunks the points need and
# hands them to fetch() in one batch, so neighbouring points share chunks
# and a concurrent fetch gets the whole set at once.
#
# Coordinates are 1-D and sorted (ascending or descending). Dimension order
# is (x, y, t), as zaro_array(), GDAL7 as_altarr() and ndr present it.
# ASCII only.

# fractional index of v along a sorted coordinate (1-based, clamped)
frac_index <- function(coord, v) {
  if (coord[1] > coord[length(coord)]) {
    return(length(coord) + 1 - frac_index(rev(coord), v))
  }
  i <- findInterval(v, coord, all.inside = TRUE)
  f <- (v - coord[i]) / (coord[i + 1L] - coord[i])
  pmin(pmax(i + f, 1), length(coord))
}

#' @param x array or altarr, dims (x, y, t)
#' @param coords list(x =, y =, t =) of 1-D coordinate vectors
#' @param px,py,pt point coordinates (pt numeric in the units of coords$t)
#' @param method "nearest", or "linear" (bilinear in space, linear in t:
#'   an 8-value stencil per point, still a single x[idx] call)
xyt_extract <- function(x, coords, px, py, pt, method = c("nearest", "linear")) {
  method <- match.arg(method)
  fi <- frac_index(coords$x, px)
  fj <- frac_index(coords$y, py)
  ft <- frac_index(coords$t, pt)
  if (method == "nearest") {
    idx <- cbind(round(fi), round(fj), round(ft))
    return(x[idx])
  }
  d <- dim(x)
  i0 <- pmin(floor(fi), d[1] - 1L); wi <- fi - i0
  j0 <- pmin(floor(fj), d[2] - 1L); wj <- fj - j0
  t0 <- pmin(floor(ft), d[3] - 1L); wt <- ft - t0
  n <- length(px)
  corners <- expand.grid(a = 0:1, b = 0:1, c = 0:1)
  idx <- do.call(rbind, lapply(seq_len(8), function(k)
    cbind(i0 + corners$a[k], j0 + corners$b[k], t0 + corners$c[k])))
  v <- matrix(x[idx], n, 8)          # one call for every corner of every point
  pick <- function(on, w) if (on == 1L) w else 1 - w
  w <- vapply(seq_len(8), function(k)
    pick(corners$a[k], wi) * pick(corners$b[k], wj) * pick(corners$c[k], wt),
    numeric(n))
  rowSums(v * w)
}

# self-test on an ordinary array: a linear field is reproduced exactly
if (sys.nframe() == 0L) {
  cx <- seq(100, 160, by = 0.5); cy <- seq(-30, -60, by = -0.5)
  ct <- as.numeric(0:99)
  f <- function(x, y, t) 2 * x - 3 * y + 0.5 * t
  a <- outer(outer(cx, cy, function(x, y) 2 * x - 3 * y), 0.5 * ct, "+")
  set.seed(2)
  px <- runif(200, 100, 160); py <- runif(200, -60, -30); pt <- runif(200, 0, 99)
  co <- list(x = cx, y = cy, t = ct)
  lin <- xyt_extract(a, co, px, py, pt, "linear")
  stopifnot(isTRUE(all.equal(lin, f(px, py, pt))))
  nn <- xyt_extract(a, co, px, py, pt, "nearest")
  stopifnot(max(abs(nn - f(px, py, pt))) <= 2 * 0.25 + 3 * 0.25 + 0.5 * 0.5 + 1e-9)
  cat("xyt_extract self-test ok\n")
}
