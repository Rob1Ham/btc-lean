#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../_tools/run_saw.sh" "$CELL_DIR" \
  "limits/C-L-witness-push-size" 2 cell_witness_push_size
