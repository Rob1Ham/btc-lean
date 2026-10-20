#!/usr/bin/env bash
# SAW attempt for one witness-v0 cell.  The cell supplies src/cell.cry and
# src/cell.saw; the latter is executed from build/ and refers to the extracted
# bitcode by bare name.
set -euo pipefail
CELL_DIR="$(cd "$1" && pwd)"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
SRC="$CELL_DIR/src"
mkdir -p "$OUT"
"$TOOLS/build.sh" "$CELL_DIR"
cp "$SRC/cell.cry" "$BUILD/cell.cry"
cp "$SRC/cell.saw" "$BUILD/cell.saw"
RES="$OUT/result.txt"
{
  echo "# cell: $(basename "$CELL_DIR")"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  SOLVER="$(cat "$SRC/solver.txt" 2>/dev/null || echo abc)"
  echo "# solver: $SOLVER"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true
NPROOF="$(grep -c 'Proof succeeded!' "$RES" || true)"
if [ "$NPROOF" -ge 1 ] && ! grep -q 'Proof failed' "$RES" && ! grep -q 'saw: error' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
  OK=0
fi
{
  ROOT="$(cd "$CELL_DIR" && git rev-parse --show-toplevel)"
  cd "$ROOT"
  for f in "$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh" \
           "$TOOLS/wv_common.h" "$TOOLS/build.sh" \
           "$CELL_DIR/src/c_cell.cpp" "$CELL_DIR/src/l_cell.cpp" \
           "$CELL_DIR/src/fns.txt" "$CELL_DIR/src/cell.cry" \
           "$CELL_DIR/src/cell.saw" "$CELL_DIR/ir"/*.ll "$RES"; do
    case "$f" in
      "$PWD"/*) sha256sum "${f#"$PWD"/}" ;;
      *) echo "# outside-root $(sha256sum "$f")" ;;
    esac
  done
} > "$OUT/certificate.sha256"
[ "$OK" -eq 1 ]
