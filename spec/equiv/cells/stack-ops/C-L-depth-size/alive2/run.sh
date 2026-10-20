#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../_harness/run_alive2.sh" "$CELL_DIR" "stack-ops/C-L-depth-size" "OP_DEPTH,OP_SIZE" 4 520 30000 O1
