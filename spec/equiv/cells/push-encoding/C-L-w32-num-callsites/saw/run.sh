#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/w32-push/run_saw.sh" "$CELL_DIR" "push-encoding/C-L-w32-num-callsites" 8
