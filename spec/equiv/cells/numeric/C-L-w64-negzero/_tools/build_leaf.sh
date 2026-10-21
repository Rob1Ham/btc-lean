#!/usr/bin/env bash
# Build the bounded leaf pair for SCR-083.
#
#   c_cell.cpp  a line-cited source excerpt of Bitcoin Core at the pin
#   l_cell.cpp  a REVIEWED transliteration of the Lean model
#
# Both are compiled to LLVM IR with the pinned clang.  `build/` (gitignored)
# holds the bitcode and the SAW script copies; the textual IR that the
# certificates hash is written to the tracked `ir/` directory, one extracted
# module per root, so `sha256sum -c` works from a fresh checkout.
set -euo pipefail
CELL_DIR="$1"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL_DIR/build"
IRD="$CELL_DIR/ir"
# shellcheck disable=SC1091
source "$CELL_DIR/buildspec"
mkdir -p "$BUILD" "$IRD"

CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -fno-discard-value-names -I "$TOOLS" -c -emit-llvm)
"${CXX[@]}" "$CELL_DIR/c_cell.cpp" -o "$BUILD/c_leaf.bc"
"${CXX[@]}" "$CELL_DIR/l_cell.cpp" -o "$BUILD/l_leaf.bc"
for leg in c l; do
  /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_leaf.bc" -o "$IRD/${leg}_leaf.ll"
done
for fn in $CELL_FNS; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.bc" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$IRD/${leg}_${fn}.ll"
  done
done
{
  printf 'cell=%s\n' "$CELL_ID"
  printf 'fns=%s\n' "$CELL_FNS"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm-extract=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'source=%s\n' "${CELL_SOURCE_NOTE:-see c_cell.cpp / l_cell.cpp headers}"
} > "$IRD/build.txt"
