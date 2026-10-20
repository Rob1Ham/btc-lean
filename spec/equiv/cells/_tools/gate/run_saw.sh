#!/usr/bin/env bash
# SAW attempt for one E1 gate cell.  The cell is a closed function: the leaf
# computes the packed observable of the exact witness script.  Both the C and
# L extracted modules are verified against the same Cryptol constant.
set -euo pipefail

CELL_DIR="$1"
FN="$2"
ID="$3"
EXPECTED="$4"
GATE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$GATE/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
mkdir -p "$OUT"

"$GATE/build_leaf.sh" "$CELL_DIR" "$FN"

cat > "$BUILD/cell.cry" <<EOF
module Spec where
expected : [64]
expected = $EXPECTED
EOF
cat > "$BUILD/cell.saw" <<EOF
import "cell.cry";
mC <- llvm_load_module "c_${FN}.bc";
mL <- llvm_load_module "l_${FN}.bc";
let spec = do {
  llvm_execute_func [];
  llvm_return (llvm_term {{ expected }});
};
llvm_verify mC "$FN" [] false spec abc;
llvm_verify mL "$FN" [] false spec abc;
print "CELL_${ID}_SAW_GREEN";
EOF

RES="$OUT/result.txt"
{
  echo "# cell: $ID"
  echo "# command: (cd build && saw cell.saw)"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry"
  echo "# expected: $EXPECTED"
  echo "# c module: build/c_${FN}.bc"
  echo "# l module: build/l_${FN}.bc"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true

OK=0
if [ "$(grep -c "Proof succeeded! $FN" "$RES" || true)" -ge 2 ] \
   && ! grep -q "Proof failed" "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi

FILES=(
  "$CELL_DIR/spec.md"
  "$CELL_DIR/saw/run.sh"
  "$GATE/run_saw.sh"
  "$CELLS/_tools/mk_leaf.py"
  "$GATE/build_leaf.sh"
  "$GATE/gate_common.h"
  "$GATE/c_leaf.cpp"
  "$GATE/l_leaf.cpp"
  "$EQ/twin/ops_ir.py"
  "$EQ/twin/gen.py"
  "$EQ/contract/error_kind.h"
  "$BUILD/twin_ops.h"
  "$BUILD/c_${FN}.bc"
  "$BUILD/l_${FN}.bc"
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

[ "$OK" -eq 1 ]
