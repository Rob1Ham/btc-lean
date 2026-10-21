#!/usr/bin/env bash
# Alive2 leg: C excerpt vs L (twin IR handlers) for the six unary numeric
# opcodes, symbolic over the whole 4-byte CScriptNum operand domain.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL/../../.." && pwd)"
exec "$EQ/findings/wave16/07-numeric-ops/tools/run_alive2.sh" \
  "$CELL" numeric/C-L-unary-4byte \
  cell_1add cell_1sub cell_negate cell_abs cell_not cell_0notequal
