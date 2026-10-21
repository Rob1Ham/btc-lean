#!/usr/bin/env bash
# SAW attempt for a wave-32 witness-v0 cell.  The cell's saw/spec.cry encodes
# the declared (result, error) postcondition independently of either leg;
# saw/spec.saw verifies BOTH modules against that same Cryptol function, so the
# two legs are proved equal through the shared contract.
#
# Usage: run_saw.sh <cell-dir> <expected-number-of-llvm_verify-calls>
set -euo pipefail
CELL_DIR="$1"
EXPECT="$2"
E4W32="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$E4W32/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
CELL_ID="${CELL_DIR#"$CELLS"/}"
mkdir -p "$OUT"
"$E4W32/build_leaf.sh" "$CELL_DIR"
cp "$OUT/spec.cry" "$BUILD/spec.cry"
cp "$OUT/spec.saw" "$BUILD/spec.saw"
RES="$OUT/result.txt"
{
  echo "# cell: $CELL_ID"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: saw/spec.cry (shared Cryptol postcondition), saw/spec.saw"
  echo "# expected: $EXPECT llvm_verify proofs (C leg and L leg against the same spec)"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw spec.saw )
} > "$RES" 2>&1 || true
OK=0
PROVES="$(grep -c 'Proof succeeded!' "$RES" || true)"
if [ "$PROVES" -ge "$EXPECT" ] \
   && ! grep -q 'Proof failed' "$RES" \
   && ! grep -q 'Stack trace' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi
FILES=("$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh" "$OUT/spec.cry"
       "$OUT/spec.saw" "$E4W32/w32_common.h" "$E4W32/c_cells.cpp"
       "$E4W32/l_cells.cpp" "$E4W32/build_leaf.sh" "$BUILD/build.txt"
       "$BUILD/spec.cry" "$BUILD/spec.saw")
for bc in "$BUILD"/c_cell_*.bc "$BUILD"/l_cell_*.bc; do
  [ -e "$bc" ] && FILES+=("$bc")
done
FILES+=("$RES")
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
