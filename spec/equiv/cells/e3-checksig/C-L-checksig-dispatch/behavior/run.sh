#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/e3/cellsig/run_behavior.sh" "$CELL_DIR" \
  "cell_checksig,cell_checksigverify,cell_checksig_underflow" "e3-checksig/C-L-checksig-dispatch" checksig
