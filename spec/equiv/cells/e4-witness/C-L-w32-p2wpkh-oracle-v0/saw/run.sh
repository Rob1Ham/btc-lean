#!/usr/bin/env bash
# SAW attempt for C-L-w32-p2wpkh-oracle-v0.  saw/spec.cry is the independent
# postcondition; saw/spec.saw verifies BOTH exports of BOTH modules against it
# (four llvm_verify obligations), so the two legs are proved equal through a
# shared contract.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
CELL_ID="${CELL_DIR#"$EQ/cells"/}"
EXPECT=4
mkdir -p "$OUT"

"$CELL_DIR/src/build.sh"
cp "$OUT/spec.cry" "$BUILD/spec.cry"
cp "$OUT/spec.saw" "$BUILD/spec.saw"
RES="$OUT/result.txt"
{
  echo "# cell: $CELL_ID"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: saw/spec.cry (shared Cryptol postcondition), saw/spec.saw, solver z3"
  echo "# expected: $EXPECT llvm_verify proofs (outcome C/L, oracle transcript C/L)"
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

# Certificate: tracked cell inputs plus the raw result.  Build artifacts are
# deliberately excluded so the certificate replays from a fresh checkout.
FILES=("$CELL_DIR/spec.md" "$CELL_DIR/notes.md"
       "$CELL_DIR/evidence/matrix.txt" "$CELL_DIR/evidence/leaf-shape.txt"
       "$OUT/run.sh" "$OUT/spec.cry" "$OUT/spec.saw" "$RES"
       "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
       "$CELL_DIR/src/build.sh" "$CELL_DIR/src/matrix.sh")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    sha256sum "${f#"$ROOT"/}"
  done
} > "$OUT/certificate.sha256"
[ "$OK" -eq 1 ]
