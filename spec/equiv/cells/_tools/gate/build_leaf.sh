#!/usr/bin/env bash
# Build the bounded C and L leaf modules for one E1 gate cell.
#
# The L handlers are not hand-written: mk_leaf.py copies them verbatim from
# twin/ops_ir.py (the same string table twin/gen.py emits) into twin_ops.h.
# Compilation is -O1 -fno-strict-aliasing so the bounded leaf is small enough
# for Alive2/SAW; the -O0 attempt is recorded in notes.md.
set -euo pipefail

CELL_DIR="$1"
FN="$2"
GATE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$GATE/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OPS="OP_SWAP,OP_DUP,OP_ROT,OP_DEPTH,OP_PICK,OP_TOALTSTACK,OP_FROMALTSTACK,OP_EQUAL,OP_VERIFY,OP_DROP"

mkdir -p "$BUILD"
python3 "$CELLS/_tools/mk_leaf.py" \
  --ops "$OPS" --max-depth 6 --max-elem 1 \
  --out "$BUILD/twin_ops.h" --meta "$BUILD/twin_ops.meta.json"
python3 "$CELLS/_tools/mk_leaf.py" \
  --ops "$OPS" --max-depth 6 --max-elem 1 \
  --check "$BUILD/twin_ops.h"

CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -I "$GATE" -I "$BUILD" -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$GATE/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$GATE/l_leaf.cpp" -o "$BUILD/l_leaf.ll"

for leg in c l; do
  /usr/lib/llvm-20/bin/llvm-extract \
    --func="$FN" --recursive "$BUILD/${leg}_leaf.ll" \
    -o "$BUILD/${leg}_${FN}.bc"
  /usr/lib/llvm-20/bin/llvm-dis \
    "$BUILD/${leg}_${FN}.bc" -o "$BUILD/${leg}_${FN}.ll"
done

printf 'fn=%s\n' "$FN" > "$BUILD/build.txt"
printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)" >> "$BUILD/build.txt"
printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)" >> "$BUILD/build.txt"
printf 'root=%s\n' "$ROOT" >> "$BUILD/build.txt"
