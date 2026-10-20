#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../_harness/build.sh" "$CELL_DIR" "OP_DEPTH,OP_SIZE" 4 520
