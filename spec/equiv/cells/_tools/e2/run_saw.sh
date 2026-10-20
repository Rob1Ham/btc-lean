#!/usr/bin/env bash
# Generic SAW runner for E2 bounded op cells.
# Usage: run_saw.sh CELL_DIR CELL_ID MIN_PROOFS
# The cell supplies src/cell.cry and src/cell.saw; they are copied to build/
# so the result is reproducible from the recorded artifacts.
set -euo pipefail
CELL_DIR="$1"; shift
CELL_ID="$1"; shift
MIN_PROOFS="$1"
E2="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$E2/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh" "$CELL_DIR"
cp "$CELL_DIR/src/cell.cry" "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"
RES="$OUT/result.txt"
{
  echo "# cell: $CELL_ID"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry"
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
  "$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh" "$CELL_DIR/src/build.sh"
  "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$CELL_DIR/src/cell.cry" "$CELL_DIR/src/cell.saw"
  "$E2/e2_common.h" "$E2/build_numeric.sh" "$E2/build_hash.sh"
  "$E2/run_alive2.sh" "$E2/run_saw.sh"
  "$CELLS/_tools/mk_leaf.py"
  "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py" "$EQ/contract/error_kind.h"
  "$BUILD/twin_ops.h" "$BUILD/build.txt"
  "$BUILD/cell.cry" "$BUILD/cell.saw" "$RES"
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
