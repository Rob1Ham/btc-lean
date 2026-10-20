#!/usr/bin/env bash
# Build the bounded C/L leaves for the control-flow cell.
set -euo pipefail
CELL_DIR="$1"
GATE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$GATE/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
BUILD="$CELL_DIR/build"
OPS="OP_NOP,OP_RETURN,OP_NOP_UPGRADABLE"
FNS=(cell_op_return cell_plain_nop cell_nop1 cell_nop4_to_10)
mkdir -p "$BUILD"
python3 "$CELLS/_tools/mk_leaf.py" \
  --ops "$OPS" --max-depth 6 --max-elem 1 \
  --out "$BUILD/twin_ops.h" --meta "$BUILD/twin_ops.meta.json"
python3 "$CELLS/_tools/mk_leaf.py" \
  --ops "$OPS" --max-depth 6 --max-elem 1 --check "$BUILD/twin_ops.h"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -I "$GATE" -I "$BUILD" -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$GATE/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$GATE/l_leaf.cpp" -o "$BUILD/l_leaf.ll"
for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done
printf 'fn=%s\n' "${FNS[*]}" > "$BUILD/build.txt"
printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)" >> "$BUILD/build.txt"
printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)" >> "$BUILD/build.txt"
printf 'root=%s\n' "$EQ" >> "$BUILD/build.txt"
