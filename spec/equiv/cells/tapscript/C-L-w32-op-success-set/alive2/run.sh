#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/w32-tap27/run_alive2.sh" "$CELL_DIR" \
  tapscript/C-L-w32-op-success-set cell_is_op_success
