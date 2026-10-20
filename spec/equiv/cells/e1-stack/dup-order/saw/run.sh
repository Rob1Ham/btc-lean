#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/gate/run_saw.sh" "$CELL_DIR" "cell_dup_order" "e1-stack/dup-order" "0x0000000281202b01"
