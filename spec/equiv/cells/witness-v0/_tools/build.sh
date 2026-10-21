#!/usr/bin/env bash
# Build one witness-v0 cell: compile the two source-excerpt slices, extract
# every function named in src/fns.txt, and record the compared IR under ir/
# so the certificate can bind committed inputs.
set -euo pipefail
CELL_DIR="$(cd "$1" && pwd)"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL_DIR/build"
IR="$CELL_DIR/ir"
SRC="$CELL_DIR/src"
mkdir -p "$BUILD" "$IR"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fno-discard-value-names
     -I "$TOOLS" -I "$SRC" -c -emit-llvm)
"${CXX[@]}" "$SRC/c_cell.cpp" -o "$BUILD/c_leaf.bc"
"${CXX[@]}" "$SRC/l_cell.cpp" -o "$BUILD/l_leaf.bc"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/c_leaf.bc" -o "$BUILD/c_leaf.ll"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/l_leaf.bc" -o "$BUILD/l_leaf.ll"
: > "$BUILD/build.txt"
printf 'cell=%s\n' "$(basename "$CELL_DIR")" >> "$BUILD/build.txt"
printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)" >> "$BUILD/build.txt"
printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)" >> "$BUILD/build.txt"
while IFS= read -r fn; do
  [ -z "$fn" ] && continue
  case "$fn" in \#*) continue;; esac
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.bc" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$IR/${leg}_${fn}.ll"
  done
  printf 'fn=%s\n' "$fn" >> "$BUILD/build.txt"
done < "$SRC/fns.txt"
