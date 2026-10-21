#!/usr/bin/env bash
# Build the bounded C/L leaves for numeric/C-L-scriptnum-signext-exception.
#
# Emits build/{c,l}_leaf.ll and one loop-free module per entry point for
# Alive2 and SAW.  The cell domain (|value| <= 255, payload <= 2 bytes) is
# closed in src/c_leaf.cpp and src/l_leaf.cpp, so no whole-function slicing
# or post-build normalisation is needed.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CELLS="$(cd "$CELL_DIR/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
BUILD="$CELL_DIR/build"
FNS=(cell_signext_roundtrip cell_signext_pred)
mkdir -p "$BUILD"

CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -fno-jump-tables -I "$EQ/contract"
     -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf.ll"
for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
    if grep -h "call.*@llvm\." "$BUILD/${leg}_${fn}.ll" | grep -v "@llvm\.lifetime" | grep -q .; then
      echo "unexpected intrinsic in ${leg}_${fn}.ll" >&2
      exit 1
    fi
  done
done
{
  printf 'cell=C-L-scriptnum-signext-exception\n'
  printf 'fns=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'c_leaf_sha256=%s\n' "$(sha256sum "$CELL_DIR/src/c_leaf.cpp" | cut -d' ' -f1)"
  printf 'l_leaf_sha256=%s\n' "$(sha256sum "$CELL_DIR/src/l_leaf.cpp" | cut -d' ' -f1)"
  printf 'cell_cry_sha256=%s\n' "$(sha256sum "$CELL_DIR/src/cell.cry" | cut -d' ' -f1)"
  printf 'runtime_inc_sha256=%s\n' "$(sha256sum "$EQ/twin/runtime.inc" | cut -d' ' -f1)"
  printf 'repo_head=%s\n' "$(cd "$EQ/../.." && git rev-parse HEAD)"
} > "$BUILD/build.txt"
