# _bench.R -- shared by the scripts in this directory. ASCII only.
#
# bench(case, x, expr) resets the lazy array x, evaluates expr, and records
# what it cost: seconds, altarr's counters, and (for zaro stores) the HTTP
# requests and bytes behind them. finish() writes one row per read to the
# file named by BOOK_OUT, which is how the book collects results; run by
# hand, a script just prints.

suppressPackageStartupMessages(library(altarr))

.book <- new.env()
.book$rows <- list()
.book$requests <- 0
.book$bytes <- 0
.book$counting <- FALSE

# TRUE when this R has the method and altarr was compiled to use it
has_hook <- function() {
  isTRUE(tryCatch(altarr:::has_array_subset(), error = function(e) FALSE))
}

book_add_http <- function(requests, bytes) {
  .book$requests <- .book$requests + requests
  .book$bytes <- .book$bytes + bytes
  invisible(NULL)
}

# zaro's lazy arrays do not report HTTP totals themselves, so watch
# zaro_fetch(): every batch a lazy array reads goes through it, and its
# result carries the requests and bytes of that batch.
count_http <- function() {
  ok <- tryCatch({
    suppressMessages(trace("zaro_fetch", where = asNamespace("zaro"),
      print = FALSE,
      exit = quote(try({
        .s <- attr(returnValue(), "stats")
        if (!is.null(.s)) book_add_http(.s$requests, .s$bytes)
      }, silent = TRUE))))
    TRUE
  }, error = function(e) FALSE)
  .book$counting <- ok
  invisible(ok)
}

bench <- function(case, x, expr) {
  altarr_reset(x)
  .book$requests <- 0
  .book$bytes <- 0
  secs <- system.time(v <- expr)[["elapsed"]]
  s <- altarr_stats(x)
  g <- function(n) if (n %in% names(s)) as.numeric(s[[n]]) else NA_real_
  row <- data.frame(
    case = case, hook = has_hook(), svn_rev = as.character(R.version[["svn rev"]]),
    seconds = secs, fetch_calls = g("fetch_calls"), chunks = g("chunks_fetched"),
    elt = g("elt"), array_subset = g("array_subset"),
    requests = if (.book$counting) .book$requests else NA_real_,
    mb = if (.book$counting) .book$bytes / 1e6 else NA_real_,
    n = length(v), check = sprintf("%.10g", sum(as.numeric(v), na.rm = TRUE)),
    stringsAsFactors = FALSE)
  .book$rows[[length(.book$rows) + 1L]] <- row
  cat(sprintf("%-58s %8.2f s  fetch calls %5.0f  chunks %5.0f  elt %10.0f%s\n",
              case, secs, row$fetch_calls, row$chunks, row$elt,
              if (.book$counting) sprintf("  requests %4.0f  %.1f MB",
                                          row$requests, row$mb) else ""))
  invisible(v)
}

finish <- function() {
  res <- do.call(rbind, .book$rows)
  out <- Sys.getenv("BOOK_OUT", "")
  if (nzchar(out)) utils::write.csv(res, out, row.names = FALSE)
  invisible(res)
}

# A lazy array with no data behind it: the value of a cell is its 0-based
# position in the array, and every fetch call sleeps `latency` seconds,
# standing in for one round of concurrent requests to a remote store.
synthetic <- function(d, cs, latency = as.numeric(Sys.getenv("BOOK_LATENCY", "0.05")), ...) {
  d <- as.integer(d)
  cs <- as.integer(cs)
  stride <- cumprod(c(1, d))[seq_along(d)]
  fetch <- function(chunks) {
    Sys.sleep(latency)
    chunks <- matrix(chunks, ncol = length(d))
    lapply(seq_len(nrow(chunks)), function(r) {
      st <- chunks[r, ] * cs
      n <- pmin(cs, d - st)
      v <- 0
      for (a in rev(seq_along(d))) {
        v <- outer((st[a] + seq_len(n[a]) - 1) * stride[a], v, "+")
      }
      as.vector(v)
    })
  }
  altarr(d, cs, fetch, ...)
}

cat(R.version.string, "\n")
cat("array-subset method in use:", has_hook(), "\n\n")
