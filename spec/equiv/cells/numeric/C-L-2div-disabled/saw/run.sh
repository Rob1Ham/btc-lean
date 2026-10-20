#!/usr/bin/env bash
# SAW leg: C and L gate vs tools/num.cry pGate for every 32-bit wire value,
# plus the C-side tapscript OP_SUCCESSx pre-scan vs pTapScan.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL/../../.." && pwd)"
exec "$EQ/findings/wave16/07-numeric-ops/tools/run_saw.sh" \
  "$CELL" numeric/C-L-2div-disabled 3
