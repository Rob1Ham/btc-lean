#!/usr/bin/env bash
# Build the two bounded leaves for this cell.  The L leg consumes the
# twin's OP_CODESEPARATOR handler generated verbatim by mk_leaf.py.
#   build.sh <cell_dir> <fn> [fn...]
set -euo pipefail
CELL_DIR="$1"; shift
FNS=("$@")
SRC="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$SRC/../../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
BUILD="$CELL_DIR/build"
mkdir -p "$BUILD"
python3 "$CELLS/_tools/mk_leaf.py" \
  --ops OP_CODESEPARATOR --max-depth 2 --max-elem 1 \
  --out "$BUILD/twin_ops.h" --meta "$BUILD/twin_ops.meta.json"
python3 "$CELLS/_tools/mk_leaf.py" \
  --ops OP_CODESEPARATOR --max-depth 2 --max-elem 1 \
  --check "$BUILD/twin_ops.h"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fno-exceptions
     -fno-rtti -I "$SRC" -I "$BUILD" -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$SRC/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$SRC/l_leaf.cpp" -o "$BUILD/l_leaf.ll"
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
  printf 'mk_leaf ops=OP_CODESEPARATOR max_depth=2 max_elem=1\n'
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'twin_ops_sha256=%s\n' "$(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  printf 'root=%s\n' "$EQ"
} > "$BUILD/build.txt"
