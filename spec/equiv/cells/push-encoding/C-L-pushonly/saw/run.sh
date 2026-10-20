#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../_harness/run_saw.sh" "$CELL_DIR" "push-encoding/C-L-pushonly" "OP_NOP" 8 1
