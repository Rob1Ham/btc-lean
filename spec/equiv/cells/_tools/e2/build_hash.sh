#!/usr/bin/env bash
# Build the bounded C/L leaves for the E2 hash cell (OP_HASH160).
#
# The L leg is a reviewed transliteration of the twin OP_HASH160 body: the
# twin/ops_ir.py body calls st_push(st.stack, out, 20), but mk_leaf's bounded
# copy is hard-wired to 2 bytes, so a 20-byte digest cannot be represented by
# the generated leaf.  We still emit the mk_leaf table for provenance and
# record its hash; src/l_leaf.cpp carries the body verbatim with a 32-byte
# element stack and an unrolled 20-byte copy (the only re-binding).
set -euo pipefail
CELL_DIR="$1"
E2="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$E2/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
BUILD="$CELL_DIR/build"
OPS="OP_HASH160"
FNS=(cell_hash160)
mkdir -p "$BUILD"
python3 "$CELLS/_tools/mk_leaf.py" \
  --ops "$OPS" --max-depth 4 --max-elem 32 \
  --out "$BUILD/twin_ops.h" --meta "$BUILD/twin_ops.meta.json"
python3 "$CELLS/_tools/mk_leaf.py" \
  --ops "$OPS" --max-depth 4 --max-elem 32 --check "$BUILD/twin_ops.h"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -I "$E2" -I "$BUILD" -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf.ll"
for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done
{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'fn=%s\n' "${FNS[*]}"
  printf 'mk_leaf ops=%s max_depth=4 max_elem=32 (provenance only; see src/l_leaf.cpp)\n' "$OPS"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'twin_ops_sha256=%s\n' "$(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  printf 'hash160_external=opaque (shared symbol in C and L)\n'
  printf 'root=%s\n' "$EQ"
} > "$BUILD/build.txt"
