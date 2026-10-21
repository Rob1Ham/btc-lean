#!/usr/bin/env bash
# SAW leg: both C and L leaves against the independent Cryptol model for every
# operand (content word, length 0..7): 7 entry points x 2 legs = 14 proofs.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL/../../.." && pwd)"
exec "$EQ/findings/wave64/15-scr-080/tools/run_saw.sh" \
  "$CELL" numeric/C-L-numeric-default-4byte 14
