# array-subset

An optional ALTREP method, `Extract_array_subset`, so that `x[i, j, k]` on
an ALTREP array can be answered as one planned request instead of one
element at a time.

R's `MatrixSubset()` and `ArraySubset()` in `src/main/subset.c` offer the
method the subscripts they have already normalized (one 1-based integer
vector per dimension, `NA` allowed), with the array's `dim`. If the method
returns `NULL`, or the class has none, R extracts element by element as
before. R still checks bounds and sets `dim`, `dimnames` and `drop`. Wrapper
objects forward the method. The method table is allocated by R, so adding a
method does not change the ABI for compiled packages.

- Patch: `patches/0001-ALTREP-Extract_array_subset.patch` (6 files, about
  100 lines, with a NEWS entry). First written against svn r90638;
  revised 2026-10-26 against r90726.
- Consumer: [altarr](https://github.com/hypertidy/altarr), branch
  `exp/r-hook`, which implements the method behind
  `#ifdef R_ALTREP_HAS_EXTRACT_ARRAY_SUBSET`.
- Background: [What R does today with an ALTREP that has a dim and no
  class](https://hypertidy.org/posts/2026-10-01_altrep-dim-no-class/).
- Design notes and measurements:
  [`r-patch/README.md`](https://github.com/hypertidy/altarr/blob/exp/r-hook/r-patch/README.md)
  on altarr's `exp/r-hook` branch.

## Try it

```sh
docker run --rm -it ghcr.io/mdsumner/r-variants:array-subset
```

```r
install.packages("remotes")
remotes::install_github("hypertidy/altarr@exp/r-hook")
library(altarr)
altarr:::has_array_subset()          # TRUE
x <- altarr_zarr_v2(altarr_example_zarr())
y <- x[1:40, 1:20, 1:3]
altarr_stats(x)[c("array_subset", "elt", "fetch_calls")]   # 1, 0, 1
```

Compare with stock R (for example the `r-base` image), where the same
lines give `array_subset` 0 and thousands of `elt` reads. More
before/after commands are in
[issue #4](https://github.com/mdsumner/r-variants/issues/4).

## Rebuild without Docker

On Debian or Ubuntu with R's build dependencies installed:

```sh
R_SVN_REF=<r-svn commit> VARIANT_DIR=variants/array-subset \
  MAKE_CHECK=true PREFIX=$HOME/R-array-subset scripts/build-r.sh
```

This fetches that R-devel commit from the r-devel/r-svn mirror, applies
`patches/*.patch`, builds R and runs `make check`.

## Test package

`altsubtest/` is a minimal ALTREP double class that implements the
method, with switchable misbehaviour (declining, returning `R_NilValue`,
a wrong length, attributes, a shared result, writing into `subs`). On the
patched R:

```sh
R CMD INSTALL variants/array-subset/altsubtest
Rscript variants/array-subset/altsubtest/tests/test-hook.R
Rscript variants/array-subset/altsubtest/tests/test-wrapper.R
```

On stock R it still builds (the method is behind
`#ifdef R_ALTREP_HAS_EXTRACT_ARRAY_SUBSET`), so the same scripts show the
element-by-element counts.

## How the patch was made

The patch was written with Claude Code (Anthropic) running Claude Opus
5.5, then reviewed line by line and revised by Michael Sumner, who is the
accountable author. See `HOW-MADE.txt`.
