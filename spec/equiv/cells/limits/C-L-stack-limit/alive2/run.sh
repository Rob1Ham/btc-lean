#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../_tools/run_alive2.sh" "$CELL_DIR" \
  "limits/C-L-stack-limit" cell_stack_limit
