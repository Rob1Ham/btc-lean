#!/usr/bin/env bash
# Build the wave-32 witness-v0 bounded leaf pair.  c_cells.cpp is a line-cited
# Core excerpt; l_cells.cpp is a reviewed transliteration of the Lean defs
# (see the file headers).  No engine code is generated here.
set -euo pipefail
CELL_DIR="$1"
E4W32="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL_DIR/build"
FNS=(
  cell_v0_error_total
  cell_hash_compare
  cell_p2wpkh_w0
  cell_p2wpkh_w1
  cell_p2wpkh_w2
  cell_p2wpkh_w3
)
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fno-discard-value-names
     -I "$E4W32" -c -emit-llvm)
"${CXX[@]}" "$E4W32/c_cells.cpp" -o "$BUILD/c_leaf.bc"
"${CXX[@]}" "$E4W32/l_cells.cpp" -o "$BUILD/l_leaf.bc"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/c_leaf.bc" -o "$BUILD/c_leaf.ll"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/l_leaf.bc" -o "$BUILD/l_leaf.ll"
for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.bc" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done
{
  printf 'fn=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'source=C slice interpreter.cpp:1933-1956, script.h:408-431,470-488; L reviewed Defs.lean:1259-1280,1272-1274\n'
} > "$BUILD/build.txt"
