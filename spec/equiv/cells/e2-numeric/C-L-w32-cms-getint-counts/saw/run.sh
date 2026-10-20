#!/usr/bin/env bash
# SAW runner for SCR-086 clamp + CMS count cell (solver: z3).
# Four proofs: both legs of each of the two leaves.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL_DIR/../../../../.." && pwd)"
"$CELL_DIR/../../_tools/w32-num/run_saw_w32.sh" "$CELL_DIR" \
  "e2-numeric/C-L-w32-cms-getint-counts" 4
# Tracked model inputs for the L-leg transliteration (certificate provenance).
{
  cd "$ROOT"
  sha256sum \
    spec/core/Bitcoin/Numeric/ScriptNum.lean \
    spec/core/Bitcoin/Interpreter/Defs.lean \
    spec/proofs/BitcoinProofs/AF/PDW86/PDW86Clamp.lean
} >> "$CELL_DIR/saw/certificate.sha256"
