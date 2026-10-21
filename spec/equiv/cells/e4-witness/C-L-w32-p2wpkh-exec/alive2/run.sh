#!/usr/bin/env bash
# Alive2 attempt for C-L-w32-p2wpkh-exec.  Runs in both directions
# (--bidirectional), so the recorded result is mutual equality of the C and L
# functions, not a one-way refinement.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
SRC="$CELL_DIR/src"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
CELL_ID="${CELL_DIR#"$EQ/cells"/}"
FNS=(cell_p2wpkh_exec)
mkdir -p "$OUT"

"$SRC/build.sh"
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: $CELL_ID"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# command: alive-tv --bidirectional build/c_<fn>.ll build/l_<fn>.ll"
  for fn in "${FNS[@]}"; do
    echo
    echo "===== $fn ====="
    fnout="$(/usr/local/bin/alive-tv --bidirectional --smt-to=120000 \
      "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if ! printf '%s' "$fnout" | grep -Eq "Transformation seems to be correct|These functions seem to be equivalent" \
       || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
       || ! printf '%s' "$fnout" | grep -q "0 incorrect transformations" \
       || ! printf '%s' "$fnout" | grep -q "0 failed-to-prove transformations" \
       || ! printf '%s' "$fnout" | grep -q "0 Alive2 errors" \
       || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
       || printf '%s' "$fnout" | grep -q "ERROR:"; then
      OK=0
    fi
  done
} > "$RES" 2>&1
if [ "$OK" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
  STATUS=0
else
  echo "STATUS=alive2-not-green" >> "$RES"
  STATUS=1
fi

FILES=("$CELL_DIR/spec.md" "$CELL_DIR/notes.md"
       "$CELL_DIR/evidence/matrix.txt" "$CELL_DIR/evidence/leaf-shape.txt" "$OUT/run.sh"
       "$SRC/c_leaf.cpp" "$SRC/l_leaf.cpp" "$SRC/build.sh"
       "$BUILD/build.txt" "$BUILD/leaf-shape.txt" "$RES")
for fn in "${FNS[@]}"; do
  FILES+=("$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll")
done
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    sha256sum "${f#"$ROOT"/}"
  done
} > "$OUT/certificate.sha256"
exit "$STATUS"
