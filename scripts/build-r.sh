#!/usr/bin/env bash
# Build R-devel from the r-devel/r-svn git mirror, with a variant's patches.
#
# Used by docker/Dockerfile, and runnable on its own (Debian/Ubuntu with the
# build dependencies installed). Everything is set through the environment:
#
#   R_SVN_REF    commit, branch or tag of r-devel/r-svn          (default: main)
#   VARIANT_DIR  the variant's directory, holding patches/*.patch  (required)
#   PREFIX       where R is installed                (default: /opt/R/variant)
#   SRC_DIR      where the source is fetched       (default: /usr/src/r-svn)
#   BUILD_DIR    out-of-tree build directory      (default: /usr/src/r-build)
#   MAKE_CHECK   true to run 'make check' before installing  (default: false)
#   KEEP_SOURCE  true to keep the source and build trees     (default: false)
#
# A variant may also have variant.env, sourced before configure, which can
# set EXTRA_CONFIGURE_ARGS.
set -euo pipefail

R_SVN_REF="${R_SVN_REF:-main}"
: "${VARIANT_DIR:?VARIANT_DIR must name the variant directory}"
PREFIX="${PREFIX:-/opt/R/variant}"
SRC_DIR="${SRC_DIR:-/usr/src/r-svn}"
BUILD_DIR="${BUILD_DIR:-/usr/src/r-build}"
MAKE_CHECK="${MAKE_CHECK:-false}"
KEEP_SOURCE="${KEEP_SOURCE:-false}"
VARIANT_DIR="$(cd "$VARIANT_DIR" && pwd)"

echo "== R source: r-devel/r-svn @ $R_SVN_REF"
rm -rf "$SRC_DIR" && mkdir -p "$SRC_DIR" && cd "$SRC_DIR"
git init -q .
git remote add origin https://github.com/r-devel/r-svn.git
git fetch -q --depth 1 origin "$R_SVN_REF"
git checkout -q FETCH_HEAD
R_SVN_COMMIT="$(git rev-parse HEAD)"

# The git mirror has no svn metadata, and R's build refuses to start
# without a revision stamp. Same inference as r-devel/actions/checkout:
# the svn revision is in the commit message's git-svn-id line.
SVN_REV="$(git log -n1 --format=%B | sed -n 's/^git-svn-id: [^@]*@\([0-9]*\) .*/\1/p')"
SVN_DATE="$(git log -n1 --format=%ad --date=short)"
printf 'Revision: %s\nLast Changed Date: %s\n' "${SVN_REV:-0}" "$SVN_DATE" > SVNINFO
echo "== svn revision ${SVN_REV:-unknown} ($SVN_DATE), commit $R_SVN_COMMIT"

echo "== patches from $VARIANT_DIR"
shopt -s nullglob
PATCHES=("$VARIANT_DIR"/patches/*.patch)
for p in "${PATCHES[@]}"; do
  echo "   applying $(basename "$p")"
  git apply --whitespace=nowarn "$p" || { echo "!! $(basename "$p") does not apply to $R_SVN_COMMIT"; exit 1; }
done
[ ${#PATCHES[@]} -eq 0 ] && echo "   none (stock R-devel)"

EXTRA_CONFIGURE_ARGS=""
if [ -f "$VARIANT_DIR/variant.env" ]; then
  # shellcheck disable=SC1091
  . "$VARIANT_DIR/variant.env"
fi

echo "== configure"
rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
# shellcheck disable=SC2086
"$SRC_DIR/configure" --prefix="$PREFIX" --enable-R-shlib \
  --without-recommended-packages --disable-java --without-x \
  --with-blas --with-lapack $EXTRA_CONFIGURE_ARGS > configure.log 2>&1 \
  || { tail -50 configure.log; exit 1; }

echo "== make (-j$(nproc))"
make -j"$(nproc)" > make.log 2>&1 || { tail -80 make.log; exit 1; }

if [ "$MAKE_CHECK" = "true" ]; then
  echo "== make check"
  make check > check.log 2>&1 || { tail -80 check.log; tail -n 60 tests/*.fail 2>/dev/null || true; exit 1; }
fi

echo "== install to $PREFIX"
make install > install.log 2>&1 || { tail -50 install.log; exit 1; }

# A default CRAN mirror, so install.packages() works in the image.
echo 'options(repos = c(CRAN = "https://cloud.r-project.org"))' \
  >> "$PREFIX/lib/R/etc/Rprofile.site"

# Provenance: what this R is, in a file R users can read.
{
  echo "variant: $(basename "$VARIANT_DIR")"
  echo "r_svn_commit: $R_SVN_COMMIT"
  echo "svn_revision: ${SVN_REV:-unknown}"
  echo "svn_date: $SVN_DATE"
  echo "make_check: $MAKE_CHECK"
  echo "patches:"
  for p in "${PATCHES[@]}"; do
    echo "  - $(basename "$p") sha256:$(sha256sum "$p" | cut -d' ' -f1)"
  done
} > "$PREFIX/VARIANT.txt"
cat "$PREFIX/VARIANT.txt"

if [ "$KEEP_SOURCE" != "true" ]; then
  rm -rf "$SRC_DIR" "$BUILD_DIR"
fi
echo "== done: $PREFIX/bin/R"
