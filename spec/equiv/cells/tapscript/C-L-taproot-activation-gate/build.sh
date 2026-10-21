#!/usr/bin/env bash
# Build the bounded taproot activation/exception-gate leaf pair.
#
# Deterministic: pinned clang/LLVM, no timestamps in the tracked outputs.
set -euo pipefail
CELL="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL/build"
LLVM=/usr/lib/llvm-20/bin
FN=cell_taproot_activation
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -fno-discard-value-names -I "$CELL")
"${CXX[@]}" -S -emit-llvm "$CELL/c_leg.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" -S -emit-llvm "$CELL/l_leg.cpp" -o "$BUILD/l_leaf.ll"
"${CXX[@]}" -c -emit-llvm "$CELL/c_leg.cpp" -o "$BUILD/c_leaf.bc"
"${CXX[@]}" -c -emit-llvm "$CELL/l_leg.cpp" -o "$BUILD/l_leaf.bc"
for leg in c l; do
  "$LLVM/llvm-extract" --func="$FN" --recursive \
    "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${FN}.bc"
  "$LLVM/llvm-dis" "$BUILD/${leg}_${FN}.bc" \
    -o "$BUILD/${leg}_${FN}.ll"
done
{
  printf 'cell=C-L-taproot-activation-gate\n'
  printf 'fn=%s\n' "$FN"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$("$LLVM/llvm-extract" --version | head -1)"
  printf 'source=validation.cpp:2249-2288 + interpreter.cpp:1957-1969; Lean Flags.lean:69-76,127-128,145-157 + Defs.lean:1280-1285\n'
} > "$BUILD/build.txt"
