#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/e4w32/run_alive2.sh" "$CELL_DIR" \
  cell_p2wpkh_w0 cell_p2wpkh_w1 cell_p2wpkh_w2 cell_p2wpkh_w3
