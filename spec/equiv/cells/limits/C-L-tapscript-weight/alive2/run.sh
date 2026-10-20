#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../_shared/run_alive2.sh" "$CELL_DIR" \
  "limits/C-L-tapscript-weight" cell_tapscript_budget cell_tapscript_checksig
