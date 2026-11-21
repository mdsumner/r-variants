# book.R -- helpers the chapters use to run a script under each R build
# and tabulate what came back. Base R and knitr only. ASCII only.
#
# A chapter never measures anything itself. It calls book_run("NN-name.R"),
# which runs scripts/NN-name.R once per R build (patched first, so a warm
# cache or CDN never flatters the patch) and collects one row per read.
#
#   BOOK_R_STOCK     Rscript of stock R-devel     (/opt/R/baseline/bin/Rscript)
#   BOOK_R_PATCHED   Rscript of patched R-devel   (/opt/R/variant/bin/Rscript)
#   BOOK_MODE        live (default) or offline: offline skips network scripts
#   BOOK_TIMEOUT     seconds allowed per script per build (default 1800)

book_builds <- function() {
  b <- c(patched = Sys.getenv("BOOK_R_PATCHED", "/opt/R/variant/bin/Rscript"),
         stock = Sys.getenv("BOOK_R_STOCK", "/opt/R/baseline/bin/Rscript"))
  b[file.exists(b)]
}

book_run <- function(script, live = FALSE) {
  name <- sub("\\.R$", "", script)
  dir.create("results", showWarnings = FALSE)
  keep <- file.path("results", paste0(name, ".csv"))
  earlier <- function(why) {
    if (!file.exists(keep)) {
      cat("No results for this example yet:", why, "\n")
      return(NULL)
    }
    res <- utils::read.csv(keep, stringsAsFactors = FALSE)
    attr(res, "stamp") <- paste0("Earlier run (", why, "): ", book_stamp_of(res))
    res
  }
  if (live && identical(Sys.getenv("BOOK_MODE", "live"), "offline")) {
    return(earlier("this render was offline"))
  }
  builds <- book_builds()
  if (!length(builds)) return(earlier("no R build found, see BOOK_R_STOCK and BOOK_R_PATCHED"))
  parts <- list()
  for (b in names(builds)) {
    out <- tempfile(fileext = ".csv")
    log <- file.path("results", sprintf("%s.%s.log", name, b))
    status <- suppressWarnings(system2(
      builds[[b]], shQuote(file.path("scripts", script)),
      stdout = log, stderr = log, env = paste0("BOOK_OUT=", shQuote(out)),
      timeout = as.numeric(Sys.getenv("BOOK_TIMEOUT", "1800"))))
    if (identical(as.integer(status), 0L) && file.exists(out)) {
      r <- utils::read.csv(out, stringsAsFactors = FALSE)
      r$build <- b
      parts[[b]] <- r
    } else {
      cat(sprintf("The %s build did not finish %s (status %s). End of its log:\n",
                  b, script, status))
      if (file.exists(log)) cat(utils::tail(readLines(log, warn = FALSE), 15), sep = "\n")
      cat("\n")
    }
  }
  if (length(parts) < length(builds)) {
    old <- if (length(parts)) NULL else earlier("this run failed")
    if (!is.null(old) || !length(parts)) return(old)
  }
  res <- do.call(rbind, parts)
  rownames(res) <- NULL
  res$run <- format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC")
  res$host <- Sys.info()[["nodename"]]
  if (length(parts) == length(builds)) utils::write.csv(res, keep, row.names = FALSE)
  attr(res, "stamp") <- book_stamp_of(res)
  res
}

book_stamp_of <- function(res) {
  rev <- vapply(unique(res$build), function(b)
    sprintf("%s r%s", b, res$svn_rev[res$build == b][1]), "")
  sprintf("%s on %s; R-devel %s", res$run[1], res$host[1],
          paste(rev, collapse = ", "))
}

book_table <- function(res) {
  if (is.null(res) || !nrow(res)) return(invisible(NULL))
  builds <- intersect(c("stock", "patched"), unique(res$build))
  cases <- unique(res$case)
  col <- function(b, v) {
    r <- res[res$build == b, , drop = FALSE]
    r[[v]][match(cases, r$case)]
  }
  num <- function(v, digits = 0) {
    ifelse(is.na(v), "", formatC(as.numeric(v), format = "f", digits = digits,
                                 big.mark = ","))
  }
  b1 <- builds[length(builds)]
  out <- data.frame(Read = cases, Values = num(col(b1, "n")),
                    Chunks = num(col(b1, "chunks")),
                    check.names = FALSE, stringsAsFactors = FALSE)
  if (!all(is.na(col(b1, "mb")))) out[["MB"]] <- num(col(b1, "mb"), 1)
  for (v in list(c("Fetch calls", "fetch_calls", 0), c("Requests", "requests", 0),
                 c("Seconds", "seconds", 2))) {
    for (b in builds) {
      x <- col(b, v[2])
      if (!all(is.na(x))) out[[paste0(v[1], ", ", b)]] <- num(x, as.integer(v[3]))
    }
  }
  if (length(builds) == 2L) {
    out[["Faster by"]] <- sprintf("%.1fx", col("stock", "seconds") /
                                    pmax(col("patched", "seconds"), 0.001))
    same <- as.character(col("stock", "check")) == as.character(col("patched", "check"))
    out[["Same values"]] <- ifelse(is.na(same), "", ifelse(same, "yes", "NO"))
  }
  knitr::kable(out, align = c("l", rep("r", ncol(out) - 1L)),
               caption = attr(res, "stamp"))
}

# Element calls per build: the count the tables leave out.
book_elt <- function(res) {
  if (is.null(res) || !nrow(res)) return(invisible(NULL))
  builds <- intersect(c("stock", "patched"), unique(res$build))
  cases <- unique(res$case)
  out <- data.frame(Read = cases, check.names = FALSE, stringsAsFactors = FALSE)
  for (b in builds) {
    r <- res[res$build == b, , drop = FALSE]
    out[[paste0("Element calls, ", b)]] <-
      formatC(r$elt[match(cases, r$case)], format = "f", digits = 0, big.mark = ",")
  }
  knitr::kable(out, align = c("l", rep("r", ncol(out) - 1L)))
}

# What each build is, for the preface.
book_stamp <- function() {
  builds <- book_builds()
  if (!length(builds)) {
    cat("No R builds found at BOOK_R_STOCK / BOOK_R_PATCHED.\n")
    return(invisible(NULL))
  }
  for (b in names(builds)) {
    cat("==", b, "==\n")
    v <- file.path(dirname(dirname(builds[[b]])), "VARIANT.txt")
    if (file.exists(v)) cat(readLines(v, warn = FALSE), sep = "\n")
    code <- paste0(
      "cat(R.version.string, '\\n');",
      "for (p in c('altarr', 'zaro', 'tabularberg', 'blosc')) cat(sprintf('%-12s %s\\n', p, ",
      "tryCatch(as.character(utils::packageVersion(p)), error = function(e) 'not installed')));",
      "cat('array-subset method compiled into altarr:', ",
      "isTRUE(tryCatch(altarr:::has_array_subset(), error = function(e) FALSE)), '\\n')")
    cat(suppressWarnings(system2(builds[[b]], c("-e", shQuote(code)),
                                 stdout = TRUE, stderr = TRUE)), sep = "\n")
    cat("\n")
  }
  cat("rendered:", format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC"), "on",
      Sys.info()[["nodename"]], "\n")
  cat("mode:", Sys.getenv("BOOK_MODE", "live"), "\n")
}
