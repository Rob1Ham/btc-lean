#!/usr/bin/env bash
# Alive2 runner for SCR-086 clamp + CMS count cell.
# Both directions are checked by the shared wave-32 numeric runner.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL_DIR/../../../../.." && pwd)"
"$CELL_DIR/../../_tools/w32-num/run_alive2_w32.sh" "$CELL_DIR" \
  "e2-numeric/C-L-w32-cms-getint-counts" \
  cell_clamp_int32 cell_cms_counts4
# Tracked model inputs for the L-leg transliteration (certificate provenance).
{
  cd "$ROOT"
  sha256sum \
    spec/core/Bitcoin/Numeric/ScriptNum.lean \
    spec/core/Bitcoin/Interpreter/Defs.lean \
    spec/proofs/BitcoinProofs/AF/PDW86/PDW86Clamp.lean
} >> "$CELL_DIR/alive2/certificate.sha256"
