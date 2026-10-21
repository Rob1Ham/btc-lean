#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/w32-exec/run_alive2.sh" "$CELL_DIR" \
  "exec-verify/C-L-verify-sequential-boundary" \
  cell_push_boundary cell_split_verdict cell_split_diff cell_verify_tail
