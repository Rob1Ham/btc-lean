#!/usr/bin/env bash
# SAW runner for disabled/C-L-w65-row172-arbscan (SCR-172).
#
# Four `llvm_verify` obligations (cell_flip and the two deliberately different
# cell_tail orderings, one per leg) plus seven spec-level `prove_print`
# theorems.  Z3 is used because the eight-step symbolic-index unfold is not
# discharged by ABC inside a useful budget (the earlier ABC run was killed
# after 20 minutes; Z3 proves the C leg in about 70 s).
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CELL_ID="disabled/C-L-w65-row172-arbscan"
MIN_PROOFS=7
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh"
cp "$CELL_DIR/src/cell.cry" "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"
RES="$OUT/result.txt"
{
  echo "# cell: $CELL_ID"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry"
  echo "# script: build/cell.saw"
  echo "# prover: z3"
  echo "# expected: at least $MIN_PROOFS 'Proof succeeded!' lines, no 'Proof failed',"
  echo "#           final marker CELL_W65_ROW172_ARBSCAN_SAW_GREEN"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true
OK=0
if [ "$(grep -c '^Proof succeeded!' "$RES" || true)" -ge "$MIN_PROOFS" ] \
   && ! grep -q '^Proof failed' "$RES" \
   && grep -q '^CELL_W65_ROW172_ARBSCAN_SAW_GREEN$' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/saw/run.sh"
  "$CELL_DIR/src/build.sh" "$CELL_DIR/src/common.h"
  "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$CELL_DIR/src/cell.cry" "$CELL_DIR/src/cell.saw"
  "$EQ/contract/error_kind.h"
  "$EQ/../core/Bitcoin/Interpreter/Defs.lean"
  "$EQ/../core/Bitcoin/Script/Parser/Defs.lean"
  "$EQ/../core/Bitcoin/Script/Tapscript/Delta.lean"
  "$RES"
)
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" ;;
      *) echo "# outside-root $(sha256sum "$f")" ;;
    esac
  done
} > "$OUT/certificate.sha256"
[ "$OK" -eq 1 ]
