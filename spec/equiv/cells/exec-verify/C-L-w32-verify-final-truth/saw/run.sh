#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/w32-exec/run_saw.sh" "$CELL_DIR" \
  "exec-verify/C-L-w32-verify-final-truth" 2 cell_verify_final
