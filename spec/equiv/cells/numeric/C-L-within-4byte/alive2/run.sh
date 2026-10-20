#!/usr/bin/env bash
# Alive2 leg: C excerpt vs L (twin IR handler) for OP_WITHIN, symbolic over the
# whole 4-byte CScriptNum domain of all three operands.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL/../../.." && pwd)"
exec "$EQ/findings/wave16/07-numeric-ops/tools/run_alive2.sh" \
  "$CELL" numeric/C-L-within-4byte cell_within
