#!/usr/bin/env bash
# SAW leg for locktime/C-L-locktime-input-index-general: verify both legs
# against an independent Cryptol predicate (src/cell.cry) over 16 symbolic vin
# slots, a symbolic 4-bit index and a symbolic length, including the getD
# fallback, then require eight "Proof succeeded!" lines (2 checkers x 2 legs
# for the general entry points, plus 2 checkers x 2 legs for the
# two-array non-interference product).
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
MIN_PROOFS=8
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh"
cp "$CELL_DIR/src/cell.cry" "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"
RES="$OUT/result.txt"
{
  echo "# cell: locktime/C-L-locktime-input-index-general"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry sha256 $(sha256sum "$BUILD/cell.cry" | cut -d' ' -f1)"
  echo "# script: build/cell.saw sha256 $(sha256sum "$BUILD/cell.saw" | cut -d' ' -f1)"
  echo "# bound: 16 symbolic vin slots; index [4], length [64] (disclosed; the"
  echo "#        arbitrary-length dimension is the Lean induction + Alive2)."
  echo "# expected: at least $MIN_PROOFS 'Proof succeeded!' and no 'Proof failed'"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true
OK=0
if [ "$(grep -c '^Proof succeeded!' "$RES" || true)" -ge "$MIN_PROOFS" ] \
   && ! grep -q '^Proof failed' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/saw/run.sh"
  "$CELL_DIR/src/build.sh" "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$CELL_DIR/src/cell.cry" "$CELL_DIR/src/cell.saw"
  "$CELL_DIR/src/GeneralIndex.lean" "$CELL_DIR/src/lean_excerpt.md"
  "$EQ/contract/error_kind.h"
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
