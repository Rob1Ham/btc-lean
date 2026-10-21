#!/usr/bin/env bash
# SAW leg: both modules verified against tools/num.cry pEqual for every raw
# 8-byte word pair and length 0..8.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL/../../.." && pwd)"
exec "$EQ/findings/wave16/07-numeric-ops/tools/run_saw.sh" \
  "$CELL" numeric/C-L-equal-rawbytes 4
