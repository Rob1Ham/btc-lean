#!/usr/bin/env bash
# Build the bounded C/L leaves for hash-ops/C-L-hash-compose.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CELLS="$(cd "$CELL_DIR/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
mkdir -p "$BUILD"

OPS="OP_HASH160,OP_HASH256"
FNS=(cell_hash160_empty cell_hash160_a cell_hash256_empty cell_hash256_a
     cell_hash160_empty_chain cell_hash160_a_chain
     cell_hash256_empty_chain cell_hash256_a_chain)

python3 "$CELLS/_tools/mk_leaf.py" \
  --ops "$OPS" --max-depth 4 --max-elem 32 \
  --out "$BUILD/twin_ops.h" --meta "$BUILD/twin_ops.meta.json"
python3 "$CELLS/_tools/mk_leaf.py" \
  --ops "$OPS" --max-depth 4 --max-elem 32 --check "$BUILD/twin_ops.h"

CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -I "$CELL_DIR/src" -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf.ll"
for leg in c l; do
  /usr/lib/llvm-20/bin/llvm-as "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_leaf.bc"
done
for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done

{
  printf 'cell=C-L-hash-compose\n'
  printf 'fn=%s\n' "${FNS[*]}"
  printf 'mk_leaf ops=%s max_depth=4 max_elem=32 (provenance only)\n' "$OPS"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'twin_ops_sha256=%s\n' "$(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  printf 'hash_primitives=opaque shared symbols sha256/ripemd160; composition is in-cell\n'
  printf 'root=%s\n' "$ROOT"
} > "$BUILD/build.txt"
