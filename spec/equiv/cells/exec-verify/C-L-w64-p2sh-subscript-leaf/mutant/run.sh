#!/usr/bin/env bash
# Negative controls (mutants) for exec-verify/C-L-w64-p2sh-subscript-leaf.
#
# Each mutant is a single semantic change to the C leg. Alive2 must report a
# counterexample against the real L leg for every mutant; otherwise the green
# cell would be vacuous. Run from anywhere; rewrites mutant/result.txt.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
W32="$(cd "$CELL_DIR/../../_tools/w32-exec" && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/mutant/build"
OUT="$CELL_DIR/mutant/result.txt"
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fno-discard-value-names
     -I "$W32" -I "$EQ/contract" -c -emit-llvm)

# Mutants are single-line substitutions of the committed C leg.
M1_FROM='BStack stack{ss_depth - 1, prev_top, prev_len};'
M1_TO='BStack stack{ss_depth, ss_top, ss_top_len};'
M2_FROM='w32_cast_bool_core(stack.top, stack.len)'
M2_TO='w32_cast_bool_core(ss_top, ss_top_len)'

grep -qF "$M1_FROM" "$CELL_DIR/src/c_cell.cpp"
grep -qF "$M2_FROM" "$CELL_DIR/src/c_cell.cpp"
sed "s|$M1_FROM|$M1_TO|" "$CELL_DIR/src/c_cell.cpp" > "$BUILD/m1_no_popstack.cpp"
sed "s|$M2_FROM|$M2_TO|" "$CELL_DIR/src/c_cell.cpp" > "$BUILD/m2_wrong_top.cpp"

"${CXX[@]}" "$CELL_DIR/src/l_cell.cpp" -o "$BUILD/l_leaf.bc"
/usr/lib/llvm-20/bin/llvm-extract --func=cell_p2sh_subscript_leaf --recursive \
  "$BUILD/l_leaf.bc" -o "$BUILD/l_cell_p2sh_subscript_leaf.bc"
/usr/lib/llvm-20/bin/llvm-dis "$BUILD/l_cell_p2sh_subscript_leaf.bc" \
  -o "$BUILD/l_cell_p2sh_subscript_leaf.ll"

STATUS=0
{
  echo "# cell: exec-verify/C-L-w64-p2sh-subscript-leaf (mutants)"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# each mutant must NOT verify against the real L leg"
  for m in m1_no_popstack m2_wrong_top; do
    "${CXX[@]}" "$BUILD/$m.cpp" -o "$BUILD/$m.bc"
    /usr/lib/llvm-20/bin/llvm-extract --func=cell_p2sh_subscript_leaf --recursive \
      "$BUILD/$m.bc" -o "$BUILD/$m.fn.bc"
    /usr/lib/llvm-20/bin/llvm-dis "$BUILD/$m.fn.bc" -o "$BUILD/$m.fn.ll"
    echo
    echo "## mutant: $m"
    echo "# command: alive-tv --always-verify mutant/build/$m.fn.ll build/l_cell_p2sh_subscript_leaf.ll"
    fnout="$(/usr/local/bin/alive-tv --always-verify "$BUILD/$m.fn.ll" \
      "$BUILD/l_cell_p2sh_subscript_leaf.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if printf '%s' "$fnout" | grep -q "Transformation doesn't verify"; then
      echo "MUTANT_CAUGHT=$m"
    else
      echo "MUTANT_NOT_CAUGHT=$m"
      STATUS=1
    fi
  done
  if [ "$STATUS" -eq 0 ]; then
    echo "STATUS=mutants-caught"
  else
    echo "STATUS=mutants-not-caught"
  fi
} > "$OUT" 2>&1
grep -q "STATUS=mutants-caught" "$OUT"
exit "$STATUS"
