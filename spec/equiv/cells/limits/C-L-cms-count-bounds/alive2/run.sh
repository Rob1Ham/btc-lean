#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../_shared/run_alive2.sh" "$CELL_DIR" \
  "limits/C-L-cms-count-bounds" cell_cms_count_bounds
