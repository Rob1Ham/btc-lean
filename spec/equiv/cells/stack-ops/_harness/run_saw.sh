#!/usr/bin/env bash
# SAW attempt for one bounded stack-ops cell.
#   run_saw.sh CELL_DIR CELL_ID OPS MAX_DEPTH MAX_ELEM [OPT] [BUILD_NAME]
# The cell supplies src/cell.cry and src/cell.saw; they are copied into build/
# so the recorded artifacts are exactly what ran.  Green requires one
# "Proof succeeded!" per llvm_verify line (both legs) and no "Proof failed".
set -euo pipefail
CELL_DIR="$1"; CELL_ID="$2"; OPS="$3"; MAXD="$4"; MAXE="$5"; OPT="${6:-O1}"
BUILD_NAME="${7:-build}"
H="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$H/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/$BUILD_NAME"
OUT="$CELL_DIR/saw"
mkdir -p "$OUT"
"$H/build.sh" "$CELL_DIR" "$OPS" "$MAXD" "$MAXE" "$OPT" "$BUILD_NAME"
cp "$CELL_DIR/src/cell.cry" "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"
WANT=$(grep -c "llvm_verify" "$BUILD/cell.saw")
RES="$OUT/result.txt"
{
  echo "# cell: $CELL_ID"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry, script: build/cell.saw"
  echo "# expected: $WANT 'Proof succeeded!' and no 'Proof failed'"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true
OK=0
if [ "$(grep -c '^Proof succeeded!' "$RES" || true)" -ge "$WANT" ] \
   && [ "$WANT" -gt 0 ] \
   && ! grep -q '^Proof failed' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"; OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh" "$CELL_DIR/src/build.sh"
  "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp" "$CELL_DIR/src/fns.txt"
  "$CELL_DIR/src/cell.cry" "$CELL_DIR/src/cell.saw"
  "$H/build.sh" "$H/extract_extras.py" "$H/leaf_common.h"
  "$H/run_alive2.sh" "$H/run_saw.sh"
  "$CELLS/_tools/mk_leaf.py"
  "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py" "$EQ/twin/runtime.inc"
  "$EQ/contract/error_kind.h"
  "$BUILD/twin_ops.h" "$BUILD/twin_extras.h" "$BUILD/build.txt"
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
