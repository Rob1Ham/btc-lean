#!/usr/bin/env bash
# Build one exec-verify cell pair (C slice + L transliteration).
#
# Usage: build_cell.sh CELL_DIR FN [FN...]
#
# Each cell supplies src/c_cell.cpp, src/l_cell.cpp with an `extern "C"`
# entry per FN. Both legs are compiled with the pinned clang
# (/usr/bin/clang++-20) at -O1 (the repo's robustness lane; E0/E2 cells use
# the same flags) and each FN is extracted recursively so the compared
# modules carry no other cell code.
set -euo pipefail
CELL_DIR="$1"; shift
FNS=("$@")
W32="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$W32/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
BUILD="$CELL_DIR/build"
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fno-discard-value-names
     -I "$W32" -I "$EQ/contract" -c -emit-llvm)
"${CXX[@]}" "$CELL_DIR/src/c_cell.cpp" -o "$BUILD/c_leaf.bc"
"${CXX[@]}" "$CELL_DIR/src/l_cell.cpp" -o "$BUILD/l_leaf.bc"
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
  printf 'include=%s\n' "$W32"
  printf 'contract_error_kind_sha256=%s\n' "$(sha256sum "$EQ/contract/error_kind.h" | cut -d' ' -f1)"
  printf 'w32_common_sha256=%s\n' "$(sha256sum "$W32/w32_common.h" | cut -d' ' -f1)"
} > "$BUILD/build.txt"
