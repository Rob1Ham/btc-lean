#!/usr/bin/env bash
# Build the bounded TAPROOT flag-gate leaf pair.
set -euo pipefail
CELL="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL/build"
LLVM=/usr/lib/llvm-20/bin
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -fno-discard-value-names -I "$CELL")
"${CXX[@]}" -S -emit-llvm "$CELL/c_leg.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" -S -emit-llvm "$CELL/l_leg.cpp" -o "$BUILD/l_leaf.ll"
"${CXX[@]}" -c -emit-llvm "$CELL/c_leg.cpp" -o "$BUILD/c_leaf.bc"
"${CXX[@]}" -c -emit-llvm "$CELL/l_leg.cpp" -o "$BUILD/l_leaf.bc"
for leg in c l; do
  "$LLVM/llvm-extract" --func=cell_taproot_gate --recursive \
    "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_cell_taproot_gate.bc"
  "$LLVM/llvm-dis" "$BUILD/${leg}_cell_taproot_gate.bc" \
    -o "$BUILD/${leg}_cell_taproot_gate.ll"
done
{
  printf 'cell=C-L-taproot-gate\n'
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$("$LLVM/llvm-extract" --version | head -1)"
  printf 'source=Core interpreter.cpp:1957-1969; Lean Defs.lean:1280-1284\n'
} > "$BUILD/build.txt"
