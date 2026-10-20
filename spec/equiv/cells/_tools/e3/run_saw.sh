#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$1"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$TOOLS/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"; OUT="$CELL_DIR/saw"
mkdir -p "$OUT"
"$TOOLS/build_leaf.sh" "$CELL_DIR"
cat > "$BUILD/cell.cry" <<'EOF'
module Spec where
checksig_false : [64]
checksig_false = 0x0000000000000101
checksigverify_error : [64]
checksigverify_error = 0x0000000000000038
EOF
{
  echo 'import "cell.cry";'
  echo 'mC <- llvm_load_module "c_leaf.bc";'
  echo 'mL <- llvm_load_module "l_leaf.bc";'
  echo 'let s_checksig = do { llvm_execute_func []; llvm_return (llvm_term {{ checksig_false }}); };'
  echo 'let s_verify = do { llvm_execute_func []; llvm_return (llvm_term {{ checksigverify_error }}); };'
  echo 'llvm_verify mC "cell_checksig_empty" [] false s_checksig abc;'
  echo 'llvm_verify mL "cell_checksig_empty" [] false s_checksig abc;'
  echo 'llvm_verify mC "cell_checksigverify_empty" [] false s_verify abc;'
  echo 'llvm_verify mL "cell_checksigverify_empty" [] false s_verify abc;'
  echo 'print "CELL_e3_checksig_empty_SAW_GREEN";'
} > "$BUILD/cell.saw"
RES="$OUT/result.txt"
{
  echo "# cell: checksig/C-L-checksig-empty"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# expected: checksig_false=0x101, checksigverify_error=0x38"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true
OK=0
if [ "$(grep -c 'Proof succeeded!' "$RES" || true)" -ge 4 ] && ! grep -q 'Proof failed' "$RES"; then
  echo 'STATUS=saw-green' >> "$RES"; OK=1
else echo 'STATUS=saw-not-green' >> "$RES"; fi
FILES=("$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh" "$TOOLS/build_leaf.sh" "$TOOLS/gate_common.h" "$TOOLS/c_cell.cpp" "$TOOLS/l_cell.cpp" "$EQ/contract/error_kind.h" "$BUILD/cell.cry" "$BUILD/cell.saw" "$RES")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in "$ROOT"/*) sha256sum "${f#\"$ROOT\"/}";; *) echo "# outside-root $(sha256sum "$f")";; esac
  done
} > "$OUT/certificate.sha256"
[ "$OK" -eq 1 ]
