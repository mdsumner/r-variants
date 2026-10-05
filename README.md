# r-variants

R-devel built with proposed changes, on demand, so people can try a change
to R instead of only reading about it.

Each variant is a directory of patches against the
[r-devel/r-svn](https://github.com/r-devel/r-svn) git mirror of R's
Subversion repository, plus a script that tests the result with a package
that uses the change. A GitHub Actions workflow builds a variant when you ask
it to, against the latest R-devel or a pinned revision, runs the tests, and
can publish the build as a container image:

```sh
docker run --rm -it ghcr.io/mdsumner/r-variants:array-subset
```

## Variants

| Variant | What it changes | Consumer |
| --- | --- | --- |
| [`baseline`](variants/baseline) | Nothing: stock R-devel, for comparison at the same revision | altarr, without the hook |
| [`array-subset`](variants/array-subset) | ALTREP `Extract_array_subset` method: `x[i, j, k]` on an ALTREP array is offered as one request | [altarr](https://github.com/hypertidy/altarr) `exp/r-hook` |

## How this relates to what already exists

- **[r-devel/r-svn](https://github.com/r-devel/r-svn)** builds and checks
  every R-devel commit on 8 configurations, and runs the same suite on pull
  requests: the route the [R Development
  Guide](https://contributor.r-project.org/rdevguide/chapters/lifecycle_of_a_patch.html)
  recommends for checking a patch before it goes to R core. r-variants uses
  r-svn as its source. When a variant is ready for R core, a pull request on
  r-svn is the next step.
- **[R Dev Container](https://contributor.r-project.org/r-dev-env)** is a
  ready-made environment for building R and hacking on it interactively.
- **[r-debug](https://github.com/cynkra/r-debug)** images ship R-devel built
  with sanitizers and valgrind, for debugging packages.

r-variants covers what sits between those: a named, proposed change, kept
current against R-devel, tested with the downstream code it is for, and
published so anyone can run it in a minute.

## Running a build

Actions tab, **build**, **Run workflow**, then fill in:

| Input | Meaning | Default |
| --- | --- | --- |
| `variant` | a directory under `variants/` | `array-subset` |
| `r_ref` | r-devel/r-svn commit, branch or tag | `main` (latest R-devel) |
| `make_check` | also run R's own `make check` | off (adds about 15 minutes) |
| `publish` | push the image to ghcr.io if the consumer tests pass | off |

A build takes 10 to 15 minutes. Re-running the same variant at the same R
commit reuses the cached build. Published images are tagged with the variant
name, and with the variant plus the svn revision (`array-subset-r90638`), so
an exact build can always be pulled again.

Nothing runs on R-devel's own schedule. The only automatic job is
**patches-apply**: once a week, and on every push that touches a variant, it
checks that each variant's patches still apply to the latest R-devel. It
compiles nothing and takes about a minute.

## Using an image

```sh
docker run --rm -it ghcr.io/mdsumner/r-variants:array-subset
```

R is in `/opt/R/variant`, compilers and common system libraries are
included, and `install.packages()` uses the CRAN cloud mirror.
`/opt/R/variant/VARIANT.txt` records what the image is: variant, r-svn
commit, svn revision and the sha256 of each patch. The recommended packages
(Matrix, survival and so on) are not built in; install them from CRAN if
needed.

## Adding a variant

1. Make a directory `variants/<name>/` (lower case, digits and `-`).
2. Put patches in `variants/<name>/patches/`, named so they sort in the
   order they apply (`0001-...patch`). `git format-patch` output or a plain
   `git diff` both work.
3. Write `variants/<name>/README.md`: what changes, why, and where it is
   discussed.
4. Optionally add `variants/<name>/consumer.sh`, run inside the built image
   after the build, to test the change with real code.
5. Optionally add `variants/<name>/variant.env` setting
   `EXTRA_CONFIGURE_ARGS` (for example `--enable-strict-barrier`).

## Building without Docker

`scripts/build-r.sh` is the whole build, and runs on any Debian or Ubuntu
machine with R's build dependencies (the `apt-get` line in
`docker/Dockerfile`):

```sh
VARIANT_DIR=variants/array-subset PREFIX=$HOME/R/array-subset \
  SRC_DIR=/tmp/r-src BUILD_DIR=/tmp/r-build scripts/build-r.sh
$HOME/R/array-subset/bin/R
```

Set `R_SVN_REF` to pin a revision, and `KEEP_SOURCE=true` to keep the
source tree for debugging.
