#!/usr/bin/env bash
# Alive2 leg: C excerpt vs L (twin IR handlers) for the thirteen binary numeric
# opcodes, symbolic over the whole 4-byte CScriptNum operand domain.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL/../../.." && pwd)"
# OP_ADD/OP_SUB need ~2.5 min of SMT each at v20; the other eleven
# binary opcodes finish in seconds.  Recorded in the result header.
export SMT_TO="${SMT_TO:-600000}"
exec "$EQ/findings/wave16/07-numeric-ops/tools/run_alive2.sh" \
  "$CELL" numeric/C-L-binary-4byte \
  cell_add cell_sub cell_booland cell_boolor cell_numequal cell_numequalverify \
  cell_numnotequal cell_lessthan cell_greaterthan cell_lessthanorequal \
  cell_greaterthanorequal cell_min cell_max
