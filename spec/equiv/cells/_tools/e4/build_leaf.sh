#!/usr/bin/env bash
# Build the bounded E4 dispatch leaf pair.  No engine code is generated here:
# c_cell.cpp is a line-cited Core excerpt; l_cell.cpp is a reviewed
# transliteration of the Lean def (see the file headers).
set -euo pipefail
CELL_DIR="$1"
E4="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL_DIR/build"
FNS=(cell_v0_dispatch)
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fno-discard-value-names
     -I "$E4" -c -emit-llvm)
"${CXX[@]}" "$E4/c_cell.cpp" -o "$BUILD/c_leaf.bc"
"${CXX[@]}" "$E4/l_cell.cpp" -o "$BUILD/l_leaf.bc"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/c_leaf.bc" -o "$BUILD/c_leaf.ll"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/l_leaf.bc" -o "$BUILD/l_leaf.ll"
for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.bc" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done
{
  printf 'fn=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'source=C slice interpreter.cpp:1927,1933-1956; L reviewed Lean Defs.lean:1259-1279\n'
} > "$BUILD/build.txt"
