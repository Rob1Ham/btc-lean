#!/usr/bin/env bash
# Alive2 runner for the SCR-086 depth/count clamp-uses cell.
# Five leaves, each compared in both directions (alive-tv --bidirectional).
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL_DIR/../../../../.." && pwd)"
"$CELL_DIR/../../_tools/w32-num/run_alive2_w32.sh" "$CELL_DIR" \
  "e2-numeric/C-L-w66-scr086-clamp-uses" \
  cell_clamp_int32 cell_depth_read cell_cms_key_count cell_cms_sig_prefix \
  cell_cms_sig_read
# Tracked model inputs for the L leg (certificate provenance).
{
  cd "$ROOT"
  sha256sum \
    spec/core/Bitcoin/Numeric/ScriptNum.lean \
    spec/core/Bitcoin/Interpreter/Defs.lean \
    spec/proofs/BitcoinProofs/AF/PDW86/PDW86Clamp.lean
} >> "$CELL_DIR/alive2/certificate.sha256"
