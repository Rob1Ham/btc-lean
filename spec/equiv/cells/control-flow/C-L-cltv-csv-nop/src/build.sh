#!/usr/bin/env bash
# Build the bounded C/L leaves for control-flow/C-L-cltv-csv-nop.
# Self-contained: both legs are cell-local sources (a Core source slice and a
# reviewed Lean transliteration), so there is no cells/_tools dependency.
set -euo pipefail
CELL_DIR="$1"
HERE="$(cd "$(dirname "$0")" && pwd)"
EQ="$(cd "$HERE/../../../.." && pwd)"
BUILD="$CELL_DIR/build"
FNS=(cell_cltv_flagoff cell_csv_flagoff cell_cltv_flagon cell_csv_flagon)
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -S -emit-llvm -fno-discard-value-names)
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
  printf 'fns=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'c_leaf_sha256=%s\n' "$(sha256sum "$BUILD/c_leaf.ll" | cut -d' ' -f1)"
  printf 'l_leaf_sha256=%s\n' "$(sha256sum "$BUILD/l_leaf.ll" | cut -d' ' -f1)"
  printf 'root=%s\n' "$EQ"
} > "$BUILD/build.txt"
