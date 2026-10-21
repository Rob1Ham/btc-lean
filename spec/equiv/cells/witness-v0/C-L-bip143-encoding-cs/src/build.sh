#!/usr/bin/env bash
# Cell-local build: compile the two serializer slices and extract every
# function named in src/fns.txt.  Paths are made checkout-independent with
# -ffile-prefix-map and by compiling from the cell directory, so the committed
# IR carries "src/c_cell.cpp" / "build/c_leaf.bc" rather than an absolute
# worktree path (the wave64 F3 finding); certificates then replay in any
# checkout.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$(cd "$CELL_DIR/../_tools" && pwd)"
BUILD="$CELL_DIR/build"
IR="$CELL_DIR/ir"
mkdir -p "$BUILD" "$IR"
cd "$CELL_DIR"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -fno-discard-value-names -ffile-prefix-map="$CELL_DIR/="
     -I "$TOOLS" -I "$CELL_DIR/src" -c -emit-llvm)
"${CXX[@]}" src/c_cell.cpp -o build/c_leaf.bc
"${CXX[@]}" src/l_cell.cpp -o build/l_leaf.bc
/usr/lib/llvm-20/bin/llvm-dis build/c_leaf.bc -o build/c_leaf.ll
/usr/lib/llvm-20/bin/llvm-dis build/l_leaf.bc -o build/l_leaf.ll
: > "$BUILD/build.txt"
printf 'cell=%s\n' "$(basename "$CELL_DIR")" >> "$BUILD/build.txt"
printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)" >> "$BUILD/build.txt"
printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)" >> "$BUILD/build.txt"
while IFS= read -r fn; do
  [ -z "$fn" ] && continue
  case "$fn" in \#*) continue;; esac
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "build/${leg}_leaf.bc" -o "build/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "build/${leg}_${fn}.bc" -o "$IR/${leg}_${fn}.ll"
  done
  printf 'fn=%s\n' "$fn" >> "$BUILD/build.txt"
done < "$CELL_DIR/src/fns.txt"
