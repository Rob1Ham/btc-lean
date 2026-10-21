#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/gate/run_behavior.sh" "$CELL_DIR" "e1-stack/swap-order" "51527c5187"
