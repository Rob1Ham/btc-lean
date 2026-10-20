#!/usr/bin/env bash
# Build the two bounded leaves of this cell.
#   build.sh <cell_dir> <fn> [fn...]
# -O1 emits textual IR for llvm-extract (Alive2) and bitcode for SAW.
# There is no loop in either leaf: the eight EvalScript iterations are
# unrolled, so Alive2's loop restriction does not apply.
set -euo pipefail
CELL_DIR="$1"; shift
FNS=("$@")
SRC="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL_DIR/build"
CXX=/usr/bin/clang++-20
LLVM=/usr/lib/llvm-20/bin
mkdir -p "$BUILD"
CXXFLAGS=(-std=c++17 -O1 -fno-strict-aliasing -fno-exceptions -fno-rtti
          -I "$SRC" -S -emit-llvm -fno-discard-value-names)
"$CXX" "${CXXFLAGS[@]}" "$SRC/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"$CXX" "${CXXFLAGS[@]}" "$SRC/l_leaf.cpp" -o "$BUILD/l_leaf.ll"
for fn in "${FNS[@]}"; do
  for leg in c l; do
    "$LLVM/llvm-extract" --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${fn}.bc"
    "$LLVM/llvm-dis" "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done
{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'fn=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$("$CXX" --version | head -1)"
  printf 'llvm=%s\n' "$("$LLVM/llvm-extract" --version | head -1)"
  printf 'flags=%s\n' "${CXXFLAGS[*]}"
  printf 'c_leaf_sha256=%s\n' "$(sha256sum "$SRC/c_leaf.cpp" | cut -d' ' -f1)"
  printf 'l_leaf_sha256=%s\n' "$(sha256sum "$SRC/l_leaf.cpp" | cut -d' ' -f1)"
} > "$BUILD/build.txt"
