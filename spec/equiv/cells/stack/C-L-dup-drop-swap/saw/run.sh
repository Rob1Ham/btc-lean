#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/gate/run_saw_multi.sh" "$CELL_DIR" "stack/C-L-dup-drop-swap"
