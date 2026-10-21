#!/usr/bin/env bash
# Alive2 lane.  --bidirectional gives both L ⊑ C and C ⊑ L; the certificate
# hashes the tracked sources, the extracted IR actually compared, and the raw
# result.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL_DIR" && while [ ! -f spec/equiv/contract/error_kind.h ]; do cd ..; done; pwd)"
BUILD="$CELL_DIR/build"; OUT="$CELL_DIR/alive2"
mkdir -p "$OUT"
bash "$CELL_DIR/src/build.sh"
RES="$OUT/result.txt"
{
  echo "# cell: checksig/C-L-checksig-lows-numeric"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# build: build/build.txt"
  echo "# command: alive-tv --bidirectional build/c_cell_lows_numeric.ll build/l_cell_lows_numeric.ll"
  /usr/local/bin/alive-tv --bidirectional \
    "$BUILD/c_cell_lows_numeric.ll" "$BUILD/l_cell_lows_numeric.ll" || true
} > "$RES" 2>&1
OK=0
if grep -q "Transformation seems to be correct" "$RES" \
   && grep -Eq "[12] correct transformations" "$RES" \
   && grep -q "0 incorrect transformations" "$RES" \
   && ! grep -q "Transformation doesn't verify" "$RES" \
   && ! grep -q "ERROR:" "$RES"; then
  echo "STATUS=alive2-green" >> "$RES"; OK=1
else
  echo "STATUS=alive2-not-green" >> "$RES"
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/alive2/run.sh"
  "$CELL_DIR/src/build.sh" "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$ROOT/spec/equiv/contract/error_kind.h"
  "$ROOT/spec/equiv/findings/wave64/24-scr-104-low-s/README.md"
  "$ROOT/spec/equiv/findings/wave64/24-scr-104-low-s/SEAM.md"
  "$ROOT/spec/equiv/findings/wave64/24-scr-104-low-s/probe_lows.c"
  "$ROOT/spec/equiv/findings/wave64/24-scr-104-low-s/gen_witnesses.py"
  "$ROOT/spec/equiv/findings/wave64/24-scr-104-low-s/probe_witnesses.txt"
  "$BUILD/build.txt" "$BUILD/c_cell_lows_numeric.ll" "$BUILD/l_cell_lows_numeric.ll"
  "$RES"
)
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}"; done
} > "$OUT/certificate.sha256"
exit $((1-OK))
