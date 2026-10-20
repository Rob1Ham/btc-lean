#!/usr/bin/env bash
# SAW runner for C-L-w32-opname-table (SCR-173).
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CELL_ID="disabled/C-L-w32-opname-table"
MIN_PROOFS=2
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"
RES="$OUT/result.txt"
{
  echo "# cell: $CELL_ID"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry (generated from core_names.txt)"
  echo "# script: build/cell.saw"
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
  "$CELL_DIR/src/gen_opname.py" "$CELL_DIR/src/check_names.py"
  "$CELL_DIR/src/core_names.txt" "$CELL_DIR/src/lean_names.txt"
  "$CELL_DIR/src/cell.saw"
  "$EQ/contract/error_kind.h"
  "$EQ/../proofs/BitcoinProofs/AF/PDW68/PDW68.lean"
  "$BUILD/opname_core.inc" "$BUILD/opname_lean.inc" "$BUILD/cell.cry"
  "$BUILD/cell.saw" "$BUILD/build.txt" "$RES"
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
