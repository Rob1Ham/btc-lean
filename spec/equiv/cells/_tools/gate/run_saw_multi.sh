#!/usr/bin/env bash
# SAW attempt for a multi-function broader cell.
# The cell's saw/manifest.txt has lines: <fn> <expected-constant>.
# Every extracted C and L module is verified against its declared constant.
set -euo pipefail

CELL_DIR="$1"
ID="$2"
GATE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$GATE/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
MAN="$OUT/manifest.txt"
mkdir -p "$OUT"

[ -f "$MAN" ] || { echo "missing $MAN" >&2; exit 2; }

N=0
: > "$BUILD/cell.cry"
: > "$BUILD/cell.saw"
echo 'module Spec where' >> "$BUILD/cell.cry"
echo 'import "cell.cry";' >> "$BUILD/cell.saw"
echo 'mC <- llvm_load_module "c_leaf_multi.bc";' >> "$BUILD/cell.saw"
echo 'mL <- llvm_load_module "l_leaf_multi.bc";' >> "$BUILD/cell.saw"

while read -r fn exp; do
  [ -z "${fn:-}" ] && continue
  N=$((N + 1))
  "$GATE/build_leaf.sh" "$CELL_DIR" "$fn" >/dev/null
  echo "exp_${fn} : [64]" >> "$BUILD/cell.cry"
  echo "exp_${fn} = ${exp}" >> "$BUILD/cell.cry"
  echo "let s_${fn} = do { llvm_execute_func []; llvm_return (llvm_term {{ exp_${fn} }}); };" >> "$BUILD/cell.saw"
done < "$MAN"

while read -r fn exp; do
  [ -z "${fn:-}" ] && continue
  echo "llvm_verify mC \"$fn\" [] false s_${fn} abc;" >> "$BUILD/cell.saw"
  echo "llvm_verify mL \"$fn\" [] false s_${fn} abc;" >> "$BUILD/cell.saw"
done < "$MAN"
echo "print \"CELL_${ID}_SAW_GREEN\";" >> "$BUILD/cell.saw"

# Build one module containing all functions for SAW.  Alive2's extraction has
# already produced the same per-function IR; this combined module is only a
# SAW loading convenience and is hashed in the certificate.
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -I "$GATE" -I "$BUILD" -c -emit-llvm)
"${CXX[@]}" "$GATE/c_leaf.cpp" -o "$BUILD/c_leaf_multi.bc"
"${CXX[@]}" "$GATE/l_leaf.cpp" -o "$BUILD/l_leaf_multi.bc"

RES="$OUT/result.txt"
{
  echo "# cell: $ID"
  echo "# command: (cd build && saw cell.saw)"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# functions: $N"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true

WANT=$((2 * N))
GOT=$(grep -c "Proof succeeded!" "$RES" || true)
if [ "$GOT" -eq "$WANT" ] && ! grep -q "Proof failed" "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  STATUS=0
else
  echo "STATUS=saw-not-green (proofs=$GOT/$WANT)" >> "$RES"
  STATUS=1
fi

FILES=(
  "$CELL_DIR/spec.md"
  "$CELL_DIR/saw/run.sh"
  "$CELL_DIR/saw/manifest.txt"
  "$GATE/run_saw_multi.sh"
  "$CELLS/_tools/mk_leaf.py"
  "$GATE/build_leaf.sh"
  "$GATE/gate_common.h"
  "$GATE/c_leaf.cpp"
  "$GATE/l_leaf.cpp"
  "$EQ/twin/ops_ir.py"
  "$EQ/twin/gen.py"
  "$EQ/contract/error_kind.h"
  "$BUILD/twin_ops.h"
  "$BUILD/c_leaf_multi.bc"
  "$BUILD/l_leaf_multi.bc"
  "$BUILD/cell.cry"
  "$BUILD/cell.saw"
  "$RES"
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

exit "$STATUS"
