#!/usr/bin/env bash
# Build the bounded taproot key-path leaf pair.
#   alive2 lane: both legs declare the same external Schnorr checker.
#   saw lane:    one shared checker stub (success, then SCHNORR_SIG failure)
#                is linked into BOTH legs.
set -euo pipefail
CELL="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL/build"
LLVM=/usr/lib/llvm-20/bin
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -fno-strict-aliasing
     -fno-discard-value-names -I "$CELL")

# Alive2 lane (-O1 textual IR).
"${CXX[@]}" -O1 -S -emit-llvm "$CELL/c_leg.cpp" -o "$BUILD/c_leaf.ll"
"${CXX[@]}" -O1 -S -emit-llvm "$CELL/l_leg.cpp" -o "$BUILD/l_leaf.ll"
for leg in c l; do
  "$LLVM/llvm-extract" --func=cell_keypath --recursive \
    "$BUILD/${leg}_leaf.ll" -o "$BUILD/${leg}_cell_keypath.bc"
  "$LLVM/llvm-dis" "$BUILD/${leg}_cell_keypath.bc" \
    -o "$BUILD/${leg}_cell_keypath.ll"
  # Harness ABI annotation (same-crypto premise): the checker returns a C
  # uint32_t, which is never poison.  Alive2's uninterpreted-call model would
  # otherwise admit a poison return; both legs branch on the verdict.
  sed -i 's/declare i32 @btc_equiv_check_schnorr/declare noundef i32 @btc_equiv_check_schnorr/' \
    "$BUILD/${leg}_cell_keypath.ll"
done

# SAW lane (-O1 caller, -O0 stub; linked per checker result).
"${CXX[@]}" -O1 -c -emit-llvm "$CELL/c_leg.cpp" -o "$BUILD/c_leaf.bc"
"${CXX[@]}" -O1 -c -emit-llvm "$CELL/l_leg.cpp" -o "$BUILD/l_leaf.bc"
for CK in 1 94; do
  /usr/bin/clang++-20 -std=c++17 -O0 -c -emit-llvm \
    -DBTC_EQUIV_SCHNORR_RESULT=${CK}u "$CELL/checker_stub.cpp" \
    -o "$BUILD/checker_stub_${CK}.bc"
  "$LLVM/llvm-link" "$BUILD/c_leaf.bc" "$BUILD/checker_stub_${CK}.bc" \
    -o "$BUILD/c_leaf_saw_${CK}.bc"
  "$LLVM/llvm-link" "$BUILD/l_leaf.bc" "$BUILD/checker_stub_${CK}.bc" \
    -o "$BUILD/l_leaf_saw_${CK}.bc"
  "$LLVM/llvm-dis" "$BUILD/c_leaf_saw_${CK}.bc" -o "$BUILD/c_leaf_saw_${CK}.ll"
  "$LLVM/llvm-dis" "$BUILD/l_leaf_saw_${CK}.bc" -o "$BUILD/l_leaf_saw_${CK}.ll"
done
{
  printf 'cell=C-L-taproot-keypath\n'
  printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
  printf 'llvm=%s\n' "$("$LLVM/llvm-link" --version | head -1)"
  printf 'source=Core interpreter.cpp:1970-1975; Lean Defs.lean:1190-1193,1300\n'
} > "$BUILD/build.txt"
