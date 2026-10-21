#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../_harness/run_alive2.sh" "$CELL_DIR" "push-encoding/C-L-pushonly" "OP_NOP" 8 1
