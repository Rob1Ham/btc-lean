#!/usr/bin/env bash
# Build the SCR-142 historical-window MODEL leaf pair (finding-scoped).
#
# Deterministic: pinned clang/LLVM, no timestamps in tracked outputs.
set -euo pipefail
CELL="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL/build"
LLVM=/usr/lib/llvm-20/bin
FN=cell_model_taproot
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
  printf 'cell=C-L-w65-taproot-bip9-window-model (finding-scoped MODEL; not a ledger cell)\n'
  printf 'fn=%s\n' "$FN"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$("$LLVM/llvm-extract" --version | head -1)"
  printf 'model=TPR-075/076/078 (spec/core/Bitcoin/Activation/Taproot.lean); NOT cce32b168\n'
  printf 'source=historical BIP9 threshold model + interpreter.cpp:1957-1969\n'
} > "$BUILD/build.txt"
