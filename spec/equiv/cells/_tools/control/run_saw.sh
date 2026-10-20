#!/usr/bin/env bash
# SAW attempt for the control-flow cell.  Each closed witness is verified
# against its declared packed constant, for both the C and L modules.
set -euo pipefail
CELL_DIR="$1"
GATE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$GATE/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
FNS=(cell_op_return cell_plain_nop cell_nop1 cell_nop4_to_10)
mkdir -p "$OUT"
"$GATE/build_leaf.sh" "$CELL_DIR"
cat > "$BUILD/cell.cry" <<'EOF'
module Spec where
op_return   : [64]
op_return   = 0x000000000000000c
nop_success : [64]
nop_success = 0x0000000000002901
EOF
cat > "$BUILD/cell.saw" <<'EOF'
import "cell.cry";
mC0 <- llvm_load_module "c_cell_op_return.bc";
mL0 <- llvm_load_module "l_cell_op_return.bc";
mC1 <- llvm_load_module "c_cell_plain_nop.bc";
mL1 <- llvm_load_module "l_cell_plain_nop.bc";
mC2 <- llvm_load_module "c_cell_nop1.bc";
mL2 <- llvm_load_module "l_cell_nop1.bc";
mC3 <- llvm_load_module "c_cell_nop4_to_10.bc";
mL3 <- llvm_load_module "l_cell_nop4_to_10.bc";
let s0 = do { llvm_execute_func []; llvm_return (llvm_term {{ op_return }}); };
let s1 = do { llvm_execute_func []; llvm_return (llvm_term {{ nop_success }}); };
llvm_verify mC0 "cell_op_return" [] false s0 abc;
llvm_verify mL0 "cell_op_return" [] false s0 abc;
llvm_verify mC1 "cell_plain_nop" [] false s1 abc;
llvm_verify mL1 "cell_plain_nop" [] false s1 abc;
llvm_verify mC2 "cell_nop1" [] false s1 abc;
llvm_verify mL2 "cell_nop1" [] false s1 abc;
llvm_verify mC3 "cell_nop4_to_10" [] false s1 abc;
llvm_verify mL3 "cell_nop4_to_10" [] false s1 abc;
print "CELL_control_SAW_GREEN";
EOF
RES="$OUT/result.txt"
{
  echo "# cell: control/C-L-nop-return"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry"
  echo "# expected: op_return=0x0c; nop_success=0x2901"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true
OK=0
if [ "$(grep -c 'Proof succeeded!' "$RES" || true)" -ge 8 ] \
   && ! grep -q 'Proof failed' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh"
  "$CELLS/_tools/mk_leaf.py" "$GATE/build_leaf.sh" "$GATE/gate_common.h"
  "$GATE/c_leaf.cpp" "$GATE/l_leaf.cpp"
  "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py" "$EQ/contract/error_kind.h"
  "$BUILD/twin_ops.h" "$BUILD/cell.cry" "$BUILD/cell.saw" "$RES"
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
