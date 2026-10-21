#!/usr/bin/env bash
# Alive2 leg: C excerpt vs L (twin decoder) for the seven default-4 CScriptNum
# decode sites, symbolic over the whole operand domain (length 0..7, content
# 2^32 per operand).  --bidirectional, so both L <= C and C <= L are checked.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL/../../.." && pwd)"
exec "$EQ/findings/wave64/15-scr-080/tools/run_alive2.sh" \
  "$CELL" numeric/C-L-numeric-default-4byte \
  cell_pick_roll cell_unary cell_binary cell_within cell_checksigadd \
  cell_cms_nkeys cell_cms_nsigs
