#!/usr/bin/env bash
# SAW lane.  Both legs are verified against one independent Cryptol predicate
# (src/cell.cry); C |- spec and L |- spec give C == L on the cell domain.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL_DIR" && while [ ! -f spec/equiv/contract/error_kind.h ]; do cd ..; done; pwd)"
BUILD="$CELL_DIR/build"; OUT="$CELL_DIR/saw"
mkdir -p "$OUT"
bash "$CELL_DIR/src/build.sh"
cp "$CELL_DIR/src/cell.cry" "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"
RES="$OUT/result.txt"
{
  echo "# cell: checksig/C-L-checksig-lows-numeric"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry"
  echo "# script: build/cell.saw"
  echo "# expected: two 'Proof succeeded!' lines and zero 'Proof failed' lines"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true
OK=0
if [ "$(grep -c '^Proof succeeded!' "$RES" || true)" -ge 2 ] \
   && ! grep -q '^Proof failed' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"; OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/saw/run.sh"
  "$CELL_DIR/src/build.sh" "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$CELL_DIR/src/cell.cry" "$CELL_DIR/src/cell.saw"
  "$ROOT/spec/equiv/contract/error_kind.h"
  "$ROOT/spec/equiv/findings/wave64/24-scr-104-low-s/README.md"
  "$ROOT/spec/equiv/findings/wave64/24-scr-104-low-s/SEAM.md"
  "$ROOT/spec/equiv/findings/wave64/24-scr-104-low-s/probe_lows.c"
  "$ROOT/spec/equiv/findings/wave64/24-scr-104-low-s/gen_witnesses.py"
  "$ROOT/spec/equiv/findings/wave64/24-scr-104-low-s/probe_witnesses.txt"
  "$BUILD/build.txt" "$BUILD/c_leaf_saw.bc" "$BUILD/l_leaf_saw.bc"
  "$BUILD/cell.cry" "$BUILD/cell.saw" "$RES"
)
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}"; done
} > "$OUT/certificate.sha256"
exit $((1-OK))
