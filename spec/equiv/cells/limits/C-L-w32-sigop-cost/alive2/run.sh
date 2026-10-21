#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/limits/run_alive2.sh" "$CELL_DIR" \
  "limits/C-L-w32-sigop-cost"
