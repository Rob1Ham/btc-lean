#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../_shared/run_alive2.sh" "$CELL_DIR" \
  "limits/C-L-sigop-cost-arith" cell_tx_sigop_cost cell_block_sigop_gate cell_tx_sigop_policy
