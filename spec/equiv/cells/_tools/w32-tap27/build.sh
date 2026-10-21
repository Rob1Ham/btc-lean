#!/usr/bin/env bash
# Build one wave-32 tapscript dispatch cell.
#
#   build.sh CELL_DIR FN [FN...]
#
# Compiles the cell's src/c_leaf.cpp (line-cited Core excerpt slice) and
# src/l_leaf.cpp (reviewed Lean transliteration) with the pinned clang and
# extracts one function per leg.  No engine code is generated here.
set -euo pipefail
CELL_DIR="$1"; shift
W32="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL_DIR/build"
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fno-discard-value-names
     -I "$W32" -c -emit-llvm)
"${CXX[@]}" "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf.bc"
"${CXX[@]}" "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf.bc"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/c_leaf.bc" -o "$BUILD/c_leaf.ll"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/l_leaf.bc" -o "$BUILD/l_leaf.ll"
for fn in "$@"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.bc" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
    # alive-tv 20.0 can silently skip large raw -O1 functions (see
    # findings/wave32/27-tapscript-149-155).  Verify the -O2 canonical form
    # instead; SAW still verifies the raw form.
    /usr/lib/llvm-20/bin/opt -O2 -S "$BUILD/${leg}_${fn}.ll" \
      -o "$BUILD/${leg}_${fn}.opt.ll"
    if /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o - \
         | grep -Eq '^[[:space:]]*br .*%.*[[:space:]]*$' ; then
      : # structural check only; loops are recorded by the cell, not banned here
    fi
  done
done
{
  printf 'fn=%s\n' "$*"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'sources=c_leaf.cpp (Core excerpt), l_leaf.cpp (Lean transliteration)\n'
} > "$BUILD/build.txt"
