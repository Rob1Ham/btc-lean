#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../_shared/run_alive2.sh" "$CELL_DIR" \
  "limits/C-L-sigop-site-weights" cell_sigop_site_weight
