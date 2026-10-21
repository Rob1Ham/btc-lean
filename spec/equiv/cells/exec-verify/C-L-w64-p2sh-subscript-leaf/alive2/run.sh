#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/w32-exec/run_alive2.sh" "$CELL_DIR" \
  "exec-verify/C-L-w64-p2sh-subscript-leaf" cell_p2sh_subscript_leaf
