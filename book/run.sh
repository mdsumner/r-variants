#!/usr/bin/env bash
# Render the book. Run from anywhere inside the book image:
#
#   bash run.sh [live|offline] [chapter.qmd ...]
#
# live (default) runs every script; offline skips those that need the
# network and shows the last saved results for them.
set -euo pipefail
cd "$(dirname "$0")"
export BOOK_MODE="${1:-${BOOK_MODE:-live}}"
case "$BOOK_MODE" in
  live|offline) ;;
  *) echo "usage: run.sh [live|offline] [chapter.qmd ...]" >&2; exit 2 ;;
esac
shift || true
mkdir -p results
echo "== book: mode $BOOK_MODE, $(date -u +%FT%TZ), $(hostname)"
quarto render "$@"
echo "== done: $(pwd)/_book/index.html"
