#!/usr/bin/env bash
# Alive2 leg: C excerpt vs L (twin IR handler) for OP_EQUAL/OP_EQUALVERIFY,
# symbolic over all raw 8-byte element pairs (lengths 0..8).
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL/../../.." && pwd)"
exec "$EQ/findings/wave16/07-numeric-ops/tools/run_alive2.sh" \
  "$CELL" numeric/C-L-equal-rawbytes cell_equal cell_equalverify
