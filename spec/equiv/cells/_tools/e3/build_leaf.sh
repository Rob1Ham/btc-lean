#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$1"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL_DIR/build"
FNS=(cell_checksig_empty cell_checksigverify_empty)
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -I "$TOOLS" -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$TOOLS/c_cell.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$TOOLS/l_cell.cpp" -o "$BUILD/l_leaf.ll"
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
