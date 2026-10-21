#!/usr/bin/env bash
# Build the six fixed-context SCR-142 pin/model comparison leaves.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD="$DIR/build"
LLVM=/usr/lib/llvm-20/bin
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -fno-discard-value-names -I "$DIR")
for n in 1 2 3 4 5 6; do
  "${CXX[@]}" -DVARIANT=$n -S -emit-llvm "$DIR/variants.cpp" \
    -o "$BUILD/v${n}_leaf.ll"
  "$LLVM/llvm-extract" --func=cell_compare --recursive \
    "$BUILD/v${n}_leaf.ll" -o "$BUILD/v${n}.bc"
  "$LLVM/llvm-dis" "$BUILD/v${n}.bc" -o "$BUILD/v${n}.ll"
done
{
  printf 'probe=findings/wave65/18-scr-142/compare\n'
  printf 'fn=cell_compare\n'
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'variants=1 pin@709631; 2 pin@709632; 3 model@709631; 4 model@709632; 5 pin@exc692261; 6 model@exc692261\n'
} > "$BUILD/build.txt"
