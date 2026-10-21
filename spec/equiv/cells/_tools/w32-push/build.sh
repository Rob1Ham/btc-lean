#!/usr/bin/env bash
# Generic builder for the wave-32 push-encoding / altstack cells.
#
# Usage: build.sh CELL_DIR
#
# The cell supplies:
#   src/c_leaf.cpp, src/l_leaf.cpp, src/fns.txt
#   src/ops.txt          (optional) comma-separated mk_leaf handlers
#   src/max_depth.txt    (optional, with ops.txt) default 5
#   src/max_elem.txt     (optional, with ops.txt) default 1
#
# The builder always emits build/twin.cpp from twin/gen.py so an L leg may
# call the twin's structural helpers verbatim; only the functions reachable
# from the extracted cell entry points survive llvm-extract --recursive.
set -euo pipefail
CELL_DIR="$1"
W32="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$W32/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
BUILD="$CELL_DIR/build"
mkdir -p "$BUILD"

python3 "$EQ/twin/gen.py" --out "$BUILD/twin.cpp" >/dev/null

if [ -f "$CELL_DIR/src/ops.txt" ]; then
  OPS="$(tr -d '\n' < "$CELL_DIR/src/ops.txt")"
  DEPTH="$(cat "$CELL_DIR/src/max_depth.txt" 2>/dev/null || echo 5)"
  ELEM="$(cat "$CELL_DIR/src/max_elem.txt" 2>/dev/null || echo 1)"
  python3 "$CELLS/_tools/mk_leaf.py" \
    --ops "$OPS" --max-depth "$DEPTH" --max-elem "$ELEM" \
    --out "$BUILD/twin_ops.h" --meta "$BUILD/twin_ops.meta.json" >/dev/null
  python3 "$CELLS/_tools/mk_leaf.py" \
    --ops "$OPS" --max-depth "$DEPTH" --max-elem "$ELEM" \
    --check "$BUILD/twin_ops.h" >/dev/null
fi

CXX=(/usr/bin/clang++-20 -std=c++17 -O2 -fno-strict-aliasing -fno-jump-tables
     -mllvm -inline-threshold=3000
     -I "$W32" -I "$BUILD" -I "$EQ/contract"
     -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf.ll"

FNS="$(grep -v '^[[:space:]]*#' "$CELL_DIR/src/fns.txt" | sed '/^[[:space:]]*$/d')"
for fn in $FNS; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done

{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'fns=%s\n' "$(echo "$FNS" | tr '\n' ' ')"
  printf 'ops=%s\n' "$(cat "$CELL_DIR/src/ops.txt" 2>/dev/null || echo none)"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'twin_cpp_sha256=%s\n' "$(sha256sum "$BUILD/twin.cpp" | cut -d' ' -f1)"
  if [ -f "$BUILD/twin_ops.h" ]; then
    printf 'twin_ops_sha256=%s\n' "$(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  fi
  printf 'equiv_dir=%s\n' "$EQ"
} > "$BUILD/build.txt"
