#!/usr/bin/env bash
# Build the bounded C/L leaves for one `limits` cell and extract each cell_*
# function into a standalone module.  Cell-local tooling: this is the
# `cells/limits/_tools` copy of the E2 build pattern, not shared engine code.
#
# Usage: build_leaf.sh CELL_DIR FN [FN...]
set -euo pipefail
CELL_DIR="$1"; shift
FNS=("$@")
HERE="$(cd "$(dirname "$0")" && pwd)"
EQ="$(cd "$HERE/../../.." && pwd)"
BUILD="$CELL_DIR/build"
mkdir -p "$BUILD"

CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -I "$HERE" -I "$EQ/contract" -S -emit-llvm -fno-discard-value-names)

"${CXX[@]}" "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf.ll"

for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" \
      -o "$BUILD/${leg}_${fn}.ll"
  done
done

{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'fn=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'common_sha256=%s\n' "$(sha256sum "$HERE/limits_common.h" | cut -d' ' -f1)"
  printf 'error_kind_sha256=%s\n' "$(sha256sum "$EQ/contract/error_kind.h" | cut -d' ' -f1)"
  printf 'eq_root=%s\n' "$EQ"
} > "$BUILD/build.txt"
