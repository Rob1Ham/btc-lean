#!/usr/bin/env bash
# Build the C/L leaves named in a cell's manifest.txt for the wave-32
# exec-verify flag cells.  Deterministic: no timestamps, pinned clang/LLVM.
set -euo pipefail
CELL_DIR="$1"
GATE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$GATE/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
BUILD="$CELL_DIR/build"
MANIFEST="$CELL_DIR/manifest.txt"
[ -f "$MANIFEST" ] || { echo "missing $MANIFEST" >&2; exit 1; }

mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -I "$GATE" -S -emit-llvm -fno-discard-value-names)
"${CXX[@]}" "$GATE/c_flags.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" "$GATE/l_flags.cpp" -o "$BUILD/l_leaf.ll"

mapfile -t FNS < <(grep -v '^\s*#' "$MANIFEST" | grep -v '^\s*$' | awk '{print $1}')
[ "${#FNS[@]}" -gt 0 ] || { echo "empty manifest" >&2; exit 1; }

for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done

{
  printf 'fns=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'root=%s\n' "$EQ"
  printf 'manifest:\n'
  cat "$MANIFEST"
} > "$BUILD/build.txt"
