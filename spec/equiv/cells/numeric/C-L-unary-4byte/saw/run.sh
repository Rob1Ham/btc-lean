#!/usr/bin/env bash
# SAW leg: both C and L leaves against the independent Cryptol model.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL/../../.." && pwd)"
exec "$EQ/findings/wave16/07-numeric-ops/tools/run_saw.sh" \
  "$CELL" numeric/C-L-unary-4byte 12
