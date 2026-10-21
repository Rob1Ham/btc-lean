#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/w32-tap27/run_saw.sh" "$CELL_DIR" \
  tapscript/C-L-w32-op-success-prescan 4 cell_scan_finds_success cell_prescan_tail
