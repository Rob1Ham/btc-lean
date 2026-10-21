#!/usr/bin/env bash
# SAW run for C-L-w64-p2sh-single-push.
set -euo pipefail
CELL_DIR="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
CELLS="$(cd "$(dirname "$0")/../../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh"
cp "$CELL_DIR/src/cell.cry" "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"
RES="$OUT/result.txt"
{
  echo "# cell: exec-verify/C-L-w64-p2sh-single-push"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# cryptol: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH cryptol --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry"
  echo "# script: build/cell.saw"
  echo "# expected: 6 'Proof succeeded!' (3 leaves x C/L) and no 'Proof failed'"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true
OK=0
if [ "$(grep -c '^Proof succeeded!' "$RES" || true)" -ge 6 ] \
   && ! grep -q '^Proof failed' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"; OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/saw/run.sh"
  "$CELL_DIR/src/build.sh" "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$CELL_DIR/src/cell.cry" "$CELL_DIR/src/cell.saw"
  "$EQ/contract/error_kind.h" "$BUILD/c_leaf.ll" "$BUILD/l_leaf.ll"
  "$BUILD/c_cell_canon_prefix.bc" "$BUILD/l_cell_canon_prefix.bc"
  "$BUILD/c_cell_sig_push.bc" "$BUILD/l_cell_sig_push.bc"
  "$BUILD/c_cell_p2sh_guard.bc" "$BUILD/l_cell_p2sh_guard.bc"
  "$BUILD/cell.cry" "$BUILD/cell.saw" "$BUILD/build.txt" "$RES"
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
