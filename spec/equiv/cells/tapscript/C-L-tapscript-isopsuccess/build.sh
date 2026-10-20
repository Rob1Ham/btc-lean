#!/usr/bin/env bash
# Build the bounded IsOpSuccess leaf pair.
set -euo pipefail
CELL="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL/build"
LLVM=/usr/lib/llvm-20/bin
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -fno-discard-value-names -I "$CELL")
"${CXX[@]}" -S -emit-llvm "$CELL/c_leg.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" -S -emit-llvm "$CELL/l_leg.cpp" -o "$BUILD/l_leaf.ll"
"${CXX[@]}" -c -emit-llvm "$CELL/c_leg.cpp" -o "$BUILD/c_leaf.bc"
"${CXX[@]}" -c -emit-llvm "$CELL/l_leg.cpp" -o "$BUILD/l_leaf.bc"
for leg in c l; do
  "$LLVM/llvm-extract" --func=cell_is_op_success --recursive \
    "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_cell_is_op_success.bc"
  "$LLVM/llvm-dis" "$BUILD/${leg}_cell_is_op_success.bc" \
    -o "$BUILD/${leg}_cell_is_op_success.ll"
done
{
  printf 'cell=C-L-tapscript-isopsuccess\n'
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$("$LLVM/llvm-extract" --version | head -1)"
  printf 'source=Core script.cpp:365-371; Lean Defs.lean:463-466\n'
} > "$BUILD/build.txt"
