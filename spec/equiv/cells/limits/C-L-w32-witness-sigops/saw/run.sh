#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/limits/run_saw.sh" "$CELL_DIR" \
  "limits/C-L-w32-witness-sigops" 2
