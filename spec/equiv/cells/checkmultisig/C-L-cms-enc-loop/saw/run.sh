#!/usr/bin/env bash
# SAW lane for cells/checkmultisig/C-L-cms-enc-loop.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../_shared/run_saw.sh" "$CELL_DIR" "0,1,2,5,6,7"
