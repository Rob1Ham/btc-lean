#!/usr/bin/env bash
# Build the bounded C/L leaves for C-L-w32-opname-table.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$CELL_DIR/src"
BUILD="$CELL_DIR/build"
mkdir -p "$BUILD"
python3 "$SRC/gen_opname.py" "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -Wall -Wextra
     -Werror -I "$BUILD" -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$SRC/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$SRC/l_leaf.cpp" -o "$BUILD/l_leaf.ll"
# No llvm-extract here: -O1 lowers the 256-way switch to an internal
# constant switch table, and llvm-extract would replace its initializer with
# an external declaration (unreadable by Alive2/SAW).  Each leaf module
# defines only cell_opname, so the whole module is the cell.
for leg in c l; do
  cp "$BUILD/${leg}_leaf.ll" "$BUILD/${leg}_cell_opname.ll"
  /usr/lib/llvm-20/bin/llvm-as "$BUILD/${leg}_cell_opname.ll" -o "$BUILD/${leg}_cell_opname.bc"
done
{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'fn=cell_opname\n'
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'gen_opname_sha256=%s\n' "$(sha256sum "$SRC/gen_opname.py" | cut -d' ' -f1)"
  printf 'core_names_sha256=%s\n' "$(sha256sum "$SRC/core_names.txt" | cut -d' ' -f1)"
  printf 'lean_names_sha256=%s\n' "$(sha256sum "$SRC/lean_names.txt" | cut -d' ' -f1)"
} > "$BUILD/build.txt"
