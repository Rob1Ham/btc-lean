#!/usr/bin/env bash
# SAW leg: both modules verified against tools/num.cry pWithin for every
# (content word, length) pair of x, min and max.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL/../../.." && pwd)"
exec "$EQ/findings/wave16/07-numeric-ops/tools/run_saw.sh" \
  "$CELL" numeric/C-L-within-4byte 2
