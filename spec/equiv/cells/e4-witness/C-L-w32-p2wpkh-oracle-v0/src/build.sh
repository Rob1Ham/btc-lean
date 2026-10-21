#!/usr/bin/env bash
# Build the two bounded leaf legs of C-L-w32-p2wpkh-oracle-v0 and extract the
# two exported functions from each.  Self-contained: this cell owns its
# sources, so no shared _tools file is modified.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$CELL_DIR/src"
BUILD="$CELL_DIR/build"
EVID="$CELL_DIR/evidence"
FNS=(cell_p2wpkh_scr136 cell_p2wpkh_seam)
mkdir -p "$BUILD" "$EVID"

CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing
     -fno-discard-value-names -c -emit-llvm)

"${CXX[@]}" "$SRC/c_leaf.cpp" -o "$BUILD/c_leaf.bc"
"${CXX[@]}" "$SRC/l_leaf.cpp" -o "$BUILD/l_leaf.bc"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/c_leaf.bc" -o "$BUILD/c_leaf.ll"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/l_leaf.bc" -o "$BUILD/l_leaf.ll"

for fn in "${FNS[@]}"; do
  for leg in c l; do
    /usr/lib/llvm-20/bin/llvm-extract --func="$fn" --recursive \
      "$BUILD/${leg}_leaf.bc" -o "$BUILD/${leg}_${fn}.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/${leg}_${fn}.bc" \
      -o "$BUILD/${leg}_${fn}.ll"
  done
done

# Leaf shape: no loops, no calls, no allocas in either extracted function.
# (This is the same bounded-leaf requirement the sibling p2wpkh-exec cell uses.)
{
  for leg in c l; do
    for fn in "${FNS[@]}"; do
      /usr/lib/llvm-20/bin/opt -passes='print<loops>' \
        "$BUILD/${leg}_${fn}.ll" -disable-output 2>&1 \
        | sed "s/^/[${leg}:${fn}] /"
      ncall=$(grep -cE '^[[:space:]]*(call|invoke)[[:space:]]' \
        "$BUILD/${leg}_${fn}.ll" || true)
      nalloca=$(grep -cE '^[[:space:]]*%[^ ]* = alloca' \
        "$BUILD/${leg}_${fn}.ll" || true)
      nloop=$(grep -cE '^[[:space:]]*(br|switch)[[:space:]]' \
        "$BUILD/${leg}_${fn}.ll" || true)
      echo "[${leg}:${fn}] call/invoke=${ncall} alloca=${nalloca} branches=${nloop}"
      if [ "$ncall" -ne 0 ] || [ "$nalloca" -ne 0 ]; then
        echo "LEAF-SHAPE-FAIL ${leg}:${fn}" >&2
        exit 1
      fi
    done
  done
} > "$BUILD/leaf-shape.txt"

{
  printf 'fn=%s\n' "${FNS[*]}"
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$(/usr/lib/llvm-20/bin/llvm-extract --version | head -1)"
  printf 'source=C slice interpreter.cpp:1947-1953,1842-1879,446-490,803-812,896-925,1032-1059,1069-1088,331-355,46-59,script.cpp:313-363,script.h:408-431,470-488; L reviewed Defs.lean:1259-1280,1207-1236,1163-1185,1144-1152,817-860,940-1010,1030-1059,720-739,Parser/Defs.lean:206-231,Numeric/Interface.lean:64-65\n'
} > "$BUILD/build.txt"

cp "$BUILD/leaf-shape.txt" "$EVID/leaf-shape.txt"
