#!/usr/bin/env bash
# SAW leg: both modules verified against the independent model for every
# 8-byte content word and every element length 0..8 (4 obligations:
# cell_scriptnum and cell_1add, C and L).
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL/../../.." && pwd)"
exec "$EQ/findings/wave16/07-numeric-ops/tools/run_saw.sh" \
  "$CELL" numeric/C-L-scriptnum-width 4
