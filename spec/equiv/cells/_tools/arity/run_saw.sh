#!/usr/bin/env bash
# SAW attempt for the SCR-074 arity cell: each of the sixteen closed functions
# is verified against (0, INVALID_STACK_OPERATION=18, n=0) for both C and L.
set -euo pipefail
CELL_DIR="$1"
GATE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$GATE/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
FNS=(cell_2drop cell_2dup cell_3dup cell_2over cell_2rot cell_2swap cell_ifdup cell_drop cell_dup cell_nip cell_over cell_pick cell_roll cell_rot cell_swap cell_tuck)
mkdir -p "$OUT"
"$GATE/build_leaf.sh" "$CELL_DIR"
cat > "$BUILD/cell.cry" <<'EOF'
module Spec where
underflow : [64]
underflow = 0x0000000000000048
EOF
{
  echo 'import "cell.cry";'
  echo 'mC <- llvm_load_module "c_leaf.bc";'
  echo 'mL <- llvm_load_module "l_leaf.bc";'
  echo 'let spec = do { llvm_execute_func []; llvm_return (llvm_term {{ underflow }}); };'
  for fn in "${FNS[@]}"; do
    echo "llvm_verify mC \"$fn\" [] false spec abc;"
    echo "llvm_verify mL \"$fn\" [] false spec abc;"
  done
  echo 'print "CELL_arity_SAW_GREEN";'
} > "$BUILD/cell.saw"
RES="$OUT/result.txt"
{
  echo "# cell: stack-ops/C-L-arity"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry"
  echo "# expected: underflow=0x48"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true
OK=0
if [ "$(grep -c 'Proof succeeded!' "$RES" || true)" -ge 32 ] \
   && ! grep -q 'Proof failed' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"; OK=1
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
      "$ROOT"/*) sha256sum "${f#\"$ROOT\"/}" ;;
      *) echo "# outside-root $(sha256sum "$f")" ;;
    esac
  done
} > "$OUT/certificate.sha256"
[ "$OK" -eq 1 ]
