#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/gate/run_alive2.sh" "$CELL_DIR" "cell_dup_order" "e1-stack/dup-order"
