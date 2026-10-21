#!/usr/bin/env bash
# Alive2 attempt for C-L-w32-p2wpkh-oracle-v0.  Runs in both directions
# (--bidirectional), so the recorded result is mutual equality of the C and L
# functions on BOTH exports: the total execution outcome and the oracle-
# interface transcript.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
SRC="$CELL_DIR/src"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
CELL_ID="${CELL_DIR#"$EQ/cells"/}"
FNS=(cell_p2wpkh_scr136 cell_p2wpkh_seam)
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
    if ! grep -Eq "Transformation seems to be correct|These functions seem to be equivalent" <<<"$fnout" \
       || ! grep -q "1 correct transformations" <<<"$fnout" \
       || ! grep -q "0 incorrect transformations" <<<"$fnout" \
       || ! grep -q "0 failed-to-prove transformations" <<<"$fnout" \
       || ! grep -q "0 Alive2 errors" <<<"$fnout" \
       || grep -q "Transformation doesn't verify" <<<"$fnout" \
       || grep -q "ERROR:" <<<"$fnout"; then
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

# Certificate: tracked cell inputs plus the raw result.  Build artifacts are
# deliberately excluded so the certificate replays from a fresh checkout.
FILES=("$CELL_DIR/spec.md" "$CELL_DIR/notes.md"
       "$CELL_DIR/evidence/matrix.txt" "$CELL_DIR/evidence/leaf-shape.txt"
       "$OUT/run.sh" "$RES"
       "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
       "$CELL_DIR/src/build.sh" "$CELL_DIR/src/matrix.sh")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    sha256sum "${f#"$ROOT"/}"
  done
} > "$OUT/certificate.sha256"
exit "$STATUS"
