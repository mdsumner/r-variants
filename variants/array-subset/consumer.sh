#!/usr/bin/env bash
# Patched R-devel: altarr compiles the method in, and x[i, j, k] is planned.
set -euo pipefail
cat /opt/R/variant/VARIANT.txt
git clone -q --depth 1 --branch exp/r-hook https://github.com/hypertidy/altarr.git /tmp/altarr
R CMD INSTALL /tmp/altarr
Rscript -e 'stopifnot(altarr:::has_array_subset())'
Rscript /tmp/altarr/tests/test-altarr.R
Rscript /tmp/altarr/r-patch/demo.R
