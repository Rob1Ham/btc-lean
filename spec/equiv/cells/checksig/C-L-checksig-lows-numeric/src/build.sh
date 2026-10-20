#!/usr/bin/env bash
# Build the two leaves, extract one closed function per leg, and emit the
# bitcode SAW loads.  Every input the tools consume is a tracked source file.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$CELL_DIR/build"
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -fno-jump-tables -fno-discard-value-names)
"${CXX[@]}" -S -emit-llvm "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" -S -emit-llvm "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf.ll"
"${CXX[@]}" -c -emit-llvm "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf_saw.bc"
"${CXX[@]}" -c -emit-llvm "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf_saw.bc"
/usr/lib/llvm-20/bin/llvm-extract --func=cell_lows_numeric --recursive \
  "$BUILD/c_leaf.ll" -o "$BUILD/c_cell_lows_numeric.bc"
/usr/lib/llvm-20/bin/llvm-extract --func=cell_lows_numeric --recursive \
  "$BUILD/l_leaf.ll" -o "$BUILD/l_cell_lows_numeric.bc"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/c_cell_lows_numeric.bc" \
  -o "$BUILD/c_cell_lows_numeric.ll"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/l_cell_lows_numeric.bc" \
  -o "$BUILD/l_cell_lows_numeric.ll"
# Alive2 v20 refuses attached TBAA/alias.scope metadata in this shape; these
# are optimizer hints with no semantic content.  Strip identically on both
# legs (tool-ingestion transform, not a semantics change).
for f in "$BUILD/c_cell_lows_numeric.ll" "$BUILD/l_cell_lows_numeric.ll"; do
  perl -0pi -e 's/,\s*!(tbaa|tbaa\.struct|alias\.scope|noalias|nonnull)(\s+![0-9]+)+//g' "$f"
done
{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'c_leaf_sha256=%s\n' "$(sha256sum "$CELL_DIR/src/c_leaf.cpp" | cut -d' ' -f1)"
  printf 'l_leaf_sha256=%s\n' "$(sha256sum "$CELL_DIR/src/l_leaf.cpp" | cut -d' ' -f1)"
} > "$BUILD/build.txt"
