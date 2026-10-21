#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/w32-exec/run_saw.sh" "$CELL_DIR" \
  "exec-verify/C-L-w32-p2sh-23byte" 4 cell_is_p2sh cell_p2sh_reeval
