#!/usr/bin/env bash
# Build the C and L legs of this cell (shared limits-family builder).
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$CELL_DIR/../../_tools/limits/build_limits.sh" "$CELL_DIR"
