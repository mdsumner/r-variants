# baseline

Stock R-devel at the same r-svn commit as the other variants, with no
patches. Build it at the same `r_ref` as a patched variant to compare like
with like: same R revision, same compiler, same configure options. Only the
patch differs.

The consumer script installs altarr's `exp/r-hook` branch and runs its tests
and demo. On this variant `altarr:::has_array_subset()` is `FALSE`, so
`x[i, j, k]` reads element by element: the "before" column for the
array-subset variant.
