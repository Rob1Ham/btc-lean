#!/usr/bin/env bash
# Build the bounded C/L leaves for control-flow/C-L-conditional-stack.
set -euo pipefail
CELL_DIR="$1"
HERE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$HERE/../../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
BUILD="$CELL_DIR/build"
OPS="OP_NOP"
FNS=(cell_cond)
mkdir -p "$BUILD"
python3 "$CELLS/_tools/mk_leaf.py" \
  --ops "$OPS" --max-depth 2 --max-elem 2 \
  --out "$BUILD/twin_ops.h" --meta "$BUILD/twin_ops.meta.json"
python3 "$CELLS/_tools/mk_leaf.py" \
  --ops "$OPS" --max-depth 2 --max-elem 2 --check "$BUILD/twin_ops.h"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -I "$HERE" -I "$BUILD" -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$HERE/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$HERE/l_leaf.cpp" -o "$BUILD/l_leaf.ll"
for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
    # SAW 1.6 leaves the poison flag of `or disjoint` unconstrained.  The
    # packed fields are bit-disjoint by construction, so dropping the flag is
    # value-preserving; both tools consume this same normalized artifact.
    sed -i 's/ or disjoint / or /g' "$BUILD/${leg}_${fn}.ll"
    /usr/lib/llvm-20/bin/llvm-as "$BUILD/${leg}_${fn}.ll" -o "$BUILD/${leg}_${fn}.bc"
  done
done
{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'fn=%s\n' "${FNS[*]}"
  printf 'mk_leaf ops=%s max_depth=2 max_elem=2 (twin ordinals used)\n' "$OPS"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'twin_ops_sha256=%s\n' "$(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  printf 'root=%s\n' "$EQ"
} > "$BUILD/build.txt"
