#!/usr/bin/env bash
# Build the two bounded leaves for this cell and extract one module per
# observable function (the cell pattern used by cells/_tools/e2).
#   build.sh <cell_dir> <fn> [fn...]
set -euo pipefail
CELL_DIR="$1"; shift
FNS=("$@")
SRC="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$SRC/../../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
BUILD="$CELL_DIR/build"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fno-exceptions
     -fno-rtti -I "$SRC" -S -emit-llvm -fno-discard-value-names)
mkdir -p "$BUILD"
"${CXX[@]}" "$SRC/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$SRC/l_leaf.cpp" -o "$BUILD/l_leaf.ll"
for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done
{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'fn=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'root=%s\n' "$EQ"
} > "$BUILD/build.txt"
