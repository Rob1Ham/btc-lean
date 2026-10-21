#!/usr/bin/env bash
# SAW runner for the SCR-086 depth/count clamp-uses cell (solver: z3).
# Ten proofs: both legs of each of the five leaves against the independent
# Cryptol oracle.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL_DIR/../../../../.." && pwd)"
"$CELL_DIR/../../_tools/w32-num/run_saw_w32.sh" "$CELL_DIR" \
  "e2-numeric/C-L-w66-scr086-clamp-uses" 10
# Tracked model inputs for the L leg (certificate provenance).
{
  cd "$ROOT"
  sha256sum \
    spec/core/Bitcoin/Numeric/ScriptNum.lean \
    spec/core/Bitcoin/Interpreter/Defs.lean \
    spec/proofs/BitcoinProofs/AF/PDW86/PDW86Clamp.lean
} >> "$CELL_DIR/saw/certificate.sha256"
