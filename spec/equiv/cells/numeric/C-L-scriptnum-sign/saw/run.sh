#!/usr/bin/env bash
# SAW leg for numeric/C-L-scriptnum-sign (SCR-082).
#
#   saw/run.sh
#
# Builds both leaves from src/, copies the independent model src/sign.cry to
# build/cell.cry and the script src/cell.saw to build/cell.saw, and requires
# eight proofs (four entry points x C and L) with no failure.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
SAWDIR=/opt/equiv-tools/saw-1.6/bin
MIN_PROOFS=8
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh" "$CELL_DIR"
cp "$CELL_DIR/src/sign.cry" "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"

RES="$OUT/result.txt"
{
  echo "# cell: numeric/C-L-scriptnum-sign"
  echo "# rows: SCR-082 (sign bit on top byte; negative zero exists)"
  echo "# saw: $(PATH="$SAWDIR:$PATH" saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry (src/sign.cry, independent model)"
  echo "# script: build/cell.saw"
  echo "# expected: at least $MIN_PROOFS 'Proof succeeded!' and no 'Proof failed'"
  echo
  ( cd "$BUILD" && PATH="$SAWDIR:$PATH" saw cell.saw )
} > "$RES" 2>&1 || true
OK=0
if [ "$(grep -c '^Proof succeeded!' "$RES" || true)" -ge "$MIN_PROOFS" ] \
   && ! grep -q '^Proof failed' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi
# shellcheck disable=SC1091
source "$EQ/findings/wave16/07-numeric-ops/tools/certify.sh"
certify "$OUT/certificate.sha256" \
  "$CELL_DIR/spec.md" \
  "$CELL_DIR/notes.md" \
  "$CELL_DIR/src" \
  "$CELL_DIR/alive2/run.sh" \
  "$CELL_DIR/saw/run.sh" \
  "$EQ/findings/wave16/07-numeric-ops/tools/mk_num_leaf.py" \
  "$EQ/findings/wave16/07-numeric-ops/tools/num_common.h" \
  "$EQ/findings/wave16/07-numeric-ops/tools/num_core.h" \
  "$EQ/cells/_tools/mk_leaf.py" \
  "$EQ/twin/ops_ir.py" \
  "$EQ/twin/gen.py" \
  "$EQ/twin/runtime.inc" \
  "$EQ/contract/error_kind.h" \
  "$EQ/../core/Bitcoin/Numeric/ScriptNum.lean" \
  "$EQ/../core/Bitcoin/Numeric/Interface.lean" \
  "$RES"
[ "$OK" -eq 1 ]
