#!/usr/bin/env bash
# Build the bounded C/L arity leaves for ESC-074.
set -euo pipefail
CELL_DIR="$1"
GATE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$GATE/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
BUILD="$CELL_DIR/build"
OPS="OP_2DROP,OP_2DUP,OP_3DUP,OP_2OVER,OP_2ROT,OP_2SWAP,OP_IFDUP,OP_DROP,OP_DUP,OP_NIP,OP_OVER,OP_PICK,OP_ROT,OP_SWAP,OP_TUCK"
FNS=(cell_2drop cell_2dup cell_3dup cell_2over cell_2rot cell_2swap cell_ifdup cell_drop cell_dup cell_nip cell_over cell_pick cell_roll cell_rot cell_swap cell_tuck)
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
/usr/lib/llvm-20/bin/llvm-as "$BUILD/c_leaf.ll" -o "$BUILD/c_leaf.bc"
/usr/lib/llvm-20/bin/llvm-as "$BUILD/l_leaf.ll" -o "$BUILD/l_leaf.bc"
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
