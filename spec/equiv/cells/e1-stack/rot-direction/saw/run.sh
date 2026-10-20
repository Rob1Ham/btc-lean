#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/gate/run_saw.sh" "$CELL_DIR" "cell_rot_direction" "e1-stack/rot-direction" "0x0000000281a04b01"
