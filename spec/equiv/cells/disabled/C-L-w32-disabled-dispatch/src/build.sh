#!/usr/bin/env bash
# Build the bounded C/L leaves for C-L-w32-disabled-dispatch.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$CELL_DIR/src"
BUILD="$CELL_DIR/build"
FNS=(cell_guard cell_default)
mkdir -p "$BUILD"
python3 "$SRC/gen_wire_table.py" "$BUILD/wire_table.h"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -Wall -Wextra
     -Werror -I "$BUILD" -S -emit-llvm -fno-discard-value-names)
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
  printf 'fns=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'gen_wire_table_sha256=%s\n' "$(sha256sum "$SRC/gen_wire_table.py" | cut -d' ' -f1)"
  printf 'wire_table_sha256=%s\n' "$(sha256sum "$BUILD/wire_table.h" | cut -d' ' -f1)"
} > "$BUILD/build.txt"
