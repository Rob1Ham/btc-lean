#!/usr/bin/env bash
# Alive2 leg: C excerpt of the disabled-opcode gate vs the twin's
# disabled_wire, for every 32-bit wire value (all 256 opcodes and all
# non-opcode words).
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL/../../.." && pwd)"
exec "$EQ/findings/wave16/07-numeric-ops/tools/run_alive2.sh" \
  "$CELL" numeric/C-L-2div-disabled cell_gate
