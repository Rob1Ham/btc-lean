#!/usr/bin/env bash
# SAW runner for push-encoding/C-L-w66-minimaldata-arbitrary-num.
# 6 functions x 2 legs = 12 llvm_verify obligations against one Cryptol model.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/w32-push/run_saw.sh" "$CELL_DIR" \
  "push-encoding/C-L-w66-minimaldata-arbitrary-num" 12
