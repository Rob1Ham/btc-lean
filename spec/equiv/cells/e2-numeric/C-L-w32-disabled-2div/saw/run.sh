#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/w32-num/run_saw_w32.sh" "$CELL_DIR" \
  "e2-numeric/C-L-w32-disabled-2div" 6
