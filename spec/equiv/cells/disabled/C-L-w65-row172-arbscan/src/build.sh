#!/usr/bin/env bash
# Build the bounded C/L leaves for disabled/C-L-w65-row172-arbscan.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$CELL_DIR/src"
BUILD="$CELL_DIR/build"
CFNS=(cell_flip cell_tail)
LFNS=(cell_flip cell_tail)
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -Wall -Wextra
     -Werror -S -emit-llvm -fno-discard-value-names -I"$SRC")
"${CXX[@]}" "$SRC/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$SRC/l_leaf.cpp" -o "$BUILD/l_leaf.ll"
for fn in "${CFNS[@]}"; do
  /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
    "$BUILD/c_leaf.ll" -o "$BUILD/c_${fn}.bc"
  /usr/lib/llvm-20/bin/llvm-dis "$BUILD/c_${fn}.bc" -o "$BUILD/c_${fn}.ll"
done
for fn in "${LFNS[@]}"; do
  /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
    "$BUILD/l_leaf.ll" -o "$BUILD/l_${fn}.bc"
  /usr/lib/llvm-20/bin/llvm-dis "$BUILD/l_${fn}.bc" -o "$BUILD/l_${fn}.ll"
done
{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'cfns=%s\n' "${CFNS[*]}"
  printf 'lfns=%s\n' "${LFNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
} > "$BUILD/build.txt"
