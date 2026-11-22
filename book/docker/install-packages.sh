#!/usr/bin/env bash
# Install the same packages into both builds of R, and check that altarr
# found the method in the patched one and not in the stock one.
set -euo pipefail

ALTARR_REF="${ALTARR_REF:-exp/r-hook}"
ZARO_REF="${ZARO_REF:-main}"
TABULARBERG_REF="${TABULARBERG_REF:-main}"
WITH_ICECHUNK="${WITH_ICECHUNK:-true}"

# a ref is a branch, a tag or a commit (the workflow passes commits, so that
# a new commit upstream rebuilds this layer instead of reusing the cache)
fetch_ref() {
  git init -q "$3"
  git -C "$3" fetch -q --depth 1 "https://github.com/$1.git" "$2"
  git -C "$3" checkout -q FETCH_HEAD
  echo "== $1 at $(git -C "$3" rev-parse --short HEAD) ($2)"
}
fetch_ref hypertidy/altarr "$ALTARR_REF" /tmp/altarr
fetch_ref hypertidy/zaro "$ZARO_REF" /tmp/zaro
if [ "$WITH_ICECHUNK" = "true" ]; then
  fetch_ref hypertidy/tabularberg "$TABULARBERG_REF" /tmp/tabularberg
fi

if [ "$WITH_ICECHUNK" = "true" ]; then
  curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
  export PATH="$HOME/.cargo/bin:$PATH"
fi

for home in /opt/R/baseline /opt/R/variant; do
  echo "== packages for $home"
  "$home/bin/Rscript" -e '
    pk <- c("curl", "jsonlite", "nanoparquet", "S7", "blosc")
    install.packages(pk, Ncpus = parallel::detectCores())
    ok <- vapply(pk, requireNamespace, logical(1), quietly = TRUE)
    if (!all(ok)) stop("not installed: ", paste(pk[!ok], collapse = ", "))'
  "$home/bin/R" CMD INSTALL --preclean --no-docs /tmp/altarr
  "$home/bin/R" CMD INSTALL --preclean --no-docs /tmp/zaro
  if [ "$WITH_ICECHUNK" = "true" ]; then
    # from source at a known commit (the Rust build fetches its crates)
    "$home/bin/Rscript" -e '
      install.packages(c("DBI", "jsonlite"), Ncpus = parallel::detectCores())
      stopifnot(requireNamespace("DBI", quietly = TRUE))'
    ICECHUNK_FEATURES=minimal NOT_CRAN=true \
      "$home/bin/R" CMD INSTALL --preclean --no-docs /tmp/tabularberg
    "$home/bin/Rscript" -e '
      stopifnot("chunks" %in% names(formals(tabularberg::ic_chunk_refs)))'
  fi
done

/opt/R/baseline/bin/Rscript -e 'stopifnot(!altarr:::has_array_subset())'
/opt/R/variant/bin/Rscript -e 'stopifnot(altarr:::has_array_subset())'

rm -rf /tmp/altarr /tmp/zaro /tmp/tabularberg "$HOME/.cargo/registry" /tmp/Rtmp*
echo "== packages installed"
