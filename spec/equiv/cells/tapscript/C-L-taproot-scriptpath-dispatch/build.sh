#!/usr/bin/env bash
# Build the bounded taproot script-path dispatch leaf pair.
set -euo pipefail
CELL="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL/build"
LLVM=/usr/lib/llvm-20/bin
FNS=(cell_control_size cell_leaf_version cell_tail)
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -fno-discard-value-names -I "$CELL")
"${CXX[@]}" -S -emit-llvm "$CELL/c_leg.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" -S -emit-llvm "$CELL/l_leg.cpp" -o "$BUILD/l_leaf.ll"
"${CXX[@]}" -c -emit-llvm "$CELL/c_leg.cpp" -o "$BUILD/c_leaf.bc"
"${CXX[@]}" -c -emit-llvm "$CELL/l_leg.cpp" -o "$BUILD/l_leaf.bc"
for fn in "${FNS[@]}"; do
  for leg in c l; do
    "$LLVM/llvm-extract" --func="$fn" --recursive "$BUILD/${leg}_leaf.ll" \
      -o "$BUILD/${leg}_${fn}.bc"
    "$LLVM/llvm-dis" "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done
{
  printf 'cell=C-L-taproot-scriptpath-dispatch\n'
  printf 'fns=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$("$LLVM/llvm-extract" --version | head -1)"
  printf 'source=Core interpreter.cpp:1980-2008, script.cpp:216-222; Lean Program.lean:490-499, LeafVersion.lean:36-70, Defs.lean:523-525,1319-1321\n'
} > "$BUILD/build.txt"
