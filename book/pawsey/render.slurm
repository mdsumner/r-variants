#!/bin/bash --login
#SBATCH --job-name=altarr-book
#SBATCH --partition=work
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH --output=altarr-book-%j.log
#
# Render the book on Setonix. Submit from the top of a clone of
# mdsumner/r-variants:
#
#   sbatch --account=$PAWSEY_PROJECT book/pawsey/render.slurm [live|offline] [chapter.qmd ...]
#
# Optional settings (sbatch --export=ALL,NAME=value): BOOK_MODE, BOOK_PULL,
# BOOK_MAX_CON, BOOK_LATENCY, BOOK_SIF, BOOK_IMAGE, BOOK_SINGULARITY_MODULE.
# See book/rebuild.qmd.
set -euo pipefail

REPO="${SLURM_SUBMIT_DIR:-$PWD}"
if [ ! -f "$REPO/book/run.sh" ]; then
  echo "submit from the top of the r-variants clone (no book/run.sh in $REPO)" >&2
  exit 1
fi

IMAGE="${BOOK_IMAGE:-docker://ghcr.io/mdsumner/r-variants:book}"
SIF="${BOOK_SIF:-$MYSCRATCH/altarr-book/book.sif}"
mkdir -p "$(dirname "$SIF")"

module load "${BOOK_SINGULARITY_MODULE:-singularity/4.1.0-slurm}"
export SINGULARITY_CACHEDIR="${SINGULARITY_CACHEDIR:-$MYSCRATCH/.singularity}"

if [ ! -f "$SIF" ] || [ "${BOOK_PULL:-}" = "1" ]; then
  echo "== pulling $IMAGE"
  singularity pull --force "$SIF" "$IMAGE"
fi

# Quarto and R write caches under HOME and TMPDIR; give them scratch.
WORK="$MYSCRATCH/altarr-book/work"
mkdir -p "$WORK/home" "$WORK/tmp"

export SINGULARITYENV_BOOK_MODE="${1:-${BOOK_MODE:-live}}"
export SINGULARITYENV_BOOK_MAX_CON="${BOOK_MAX_CON:-8}"
export SINGULARITYENV_BOOK_THREDDS_CON="${BOOK_THREDDS_CON:-4}"
export SINGULARITYENV_BOOK_LATENCY="${BOOK_LATENCY:-0.05}"
# any other BOOK_* setting goes through as it is
for v in $(compgen -e | grep '^BOOK_' || true); do
  case "$v" in BOOK_MODE|BOOK_SIF|BOOK_IMAGE|BOOK_PULL|BOOK_SINGULARITY_MODULE) continue ;; esac
  export "SINGULARITYENV_$v=${!v}"
done
export SINGULARITYENV_TMPDIR=/work-tmp
shift || true

srun singularity exec --cleanenv \
  --home "$WORK/home:/book-home" \
  --bind "$REPO:/work" --bind "$WORK/tmp:/work-tmp" \
  --pwd /work/book "$SIF" bash run.sh "$SINGULARITYENV_BOOK_MODE" "$@"

echo "== book: $REPO/book/_book/index.html"
echo "== rows: $REPO/book/results/"
