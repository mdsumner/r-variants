#!/usr/bin/env bash
# Run the xyt point-extraction example inside an r-variants image, from the
# root of a checkout of this repository:
#
#   docker run --rm -v "$PWD:/work" -w /work/examples/xyt-points \
#     ghcr.io/mdsumner/r-variants:baseline bash run.sh          # offline only
#   ... bash run.sh live [VAR] [N]                              # + CMEMS
#   ... bash run.sh mizu [VAR] [N] [WORKERS]                    # + mizu decode
set -euo pipefail
mode="${1:-offline}"
if [ "$mode" = "mizu" ]; then export XYT_MIZU=1; fi
Rscript install.R
Rscript cost.R
Rscript offline.R
case "$mode" in
  live) Rscript cmems.R "${2:-VHM0}" "${3:-300}" ;;
  mizu) Rscript cmems_mizu.R "${2:-VHM0}" "${3:-300}" "${4:-4}" ;;
esac
