#!/usr/bin/env bash
# Build the C/L leaves for the SCR-086 depth/count clamp-uses cell.
# Reuses the shared wave-32 numeric harness read-only (provenance gate included).
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/w32-num/build_w32.sh" "$CELL_DIR"
