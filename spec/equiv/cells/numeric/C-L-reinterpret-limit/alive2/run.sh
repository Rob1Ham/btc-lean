#!/usr/bin/env bash
# Alive2 leg: C excerpt vs L (twin IR OP_1ADD handler) for
#   1. a raw push of 0..8 bytes (no numeric reinterpretation),
#   2. the same element re-interpreted by OP_1ADD,
#   3. a 4-byte OP_1ADD result observed raw (can be 5 bytes),
#   4. a second OP_1ADD re-interpreting that result.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL/../../.." && pwd)"
exec "$EQ/findings/wave16/07-numeric-ops/tools/run_alive2.sh" \
  "$CELL" numeric/C-L-reinterpret-limit \
  cell_push_raw cell_reinterpret cell_add4_observe cell_add4_readd
