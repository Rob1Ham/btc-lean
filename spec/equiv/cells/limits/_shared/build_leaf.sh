#!/usr/bin/env bash
# Build one bounded `limits` leaf pair.  The cell supplies src/c_leaf.cpp and
# src/l_leaf.cpp; this script only compiles, extracts and records provenance.
# Usage: build_leaf.sh CELL_DIR FN [FN...]
set -euo pipefail
CELL_DIR="$1"; shift
FNS=("$@")
if [ "${#FNS[@]}" -eq 0 ]; then
  mapfile -t FNS < "$CELL_DIR/src/fns.txt"
fi
SHARED="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$SHARED/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
BUILD="$CELL_DIR/build"
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -fno-discard-value-names -I "$SHARED" -c -emit-llvm)
"${CXX[@]}" "$CELL_DIR/src/c_leaf.cpp" -o "$BUILD/c_leaf.bc"
"${CXX[@]}" "$CELL_DIR/src/l_leaf.cpp" -o "$BUILD/l_leaf.bc"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/c_leaf.bc" -o "$BUILD/c_leaf.ll"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/l_leaf.bc" -o "$BUILD/l_leaf.ll"
for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.bc" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done
{
  printf 'cell=%s\n' "$(basename "$CELL_DIR")"
  printf 'fn=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'clang_flags=-std=c++17 -O1 -fno-strict-aliasing -fno-discard-value-names\n'
  printf 'shared=%s\n' "$SHARED"
  printf 'limits_common_sha256=%s\n' "$(sha256sum "$SHARED/limits_common.h" | cut -d' ' -f1)"
  printf 'core_pin=cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66\n'
  printf 'contract=f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6\n'
} > "$BUILD/build.txt"
