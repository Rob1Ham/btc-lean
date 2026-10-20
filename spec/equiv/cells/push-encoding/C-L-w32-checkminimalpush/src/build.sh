#!/usr/bin/env bash
# Build the bounded C/L leaves for C-L-w32-checkminimalpush.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$CELL_DIR/build"
FNS=(cell_minpush)
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf.ll"
for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done
{
  printf 'cell=C-L-w32-checkminimalpush\n'
  printf 'fn=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'c_leaf_sha256=%s\n' "$(sha256sum "$CELL_DIR/src/c_leaf.cpp" | cut -d' ' -f1)"
  printf 'l_leaf_sha256=%s\n' "$(sha256sum "$CELL_DIR/src/l_leaf.cpp" | cut -d' ' -f1)"
} > "$BUILD/build.txt"
