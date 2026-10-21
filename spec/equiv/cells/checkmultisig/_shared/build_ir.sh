#!/usr/bin/env bash
# Build both legs of one CHECKMULTISIG cell.
#
#   build_ir.sh <cell_dir> <alive2|saw> [stub case]
#
# Sources are found by convention in <cell_dir>/src/c_*.cpp and l_*.cpp.
# The C leg is a line-cited slice of Bitcoin Core interpreter.cpp at the pin;
# the L leg is a reviewed transliteration of the Lean equations.  Neither is
# generated from the other.
set -euo pipefail

CELL_DIR="$1"; MODE="$2"; CASE="${3:-0}"
SH="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL_DIR/build"; mkdir -p "$BUILD"
LLVM=/usr/lib/llvm-20/bin
CXX=(/usr/bin/clang++-20 -std=c++17 -I "$SH" -I "$CELL_DIR/src"
     -fno-discard-value-names -fno-strict-aliasing -O1)

C_SRC=$(ls "$CELL_DIR"/src/c_*.cpp)
L_SRC=$(ls "$CELL_DIR"/src/l_*.cpp)

# One macro set per SAW stub case.  Cases are shared by the whole family so a
# cell can pick the ones it needs:
#   0 checker false / encodings accept      1 checker true
#   2 checker diag (sig==pk)                3 checker shifted by +1
#   4 checker shifted by +2                 5 sig encoding rejects (SIG_DER)
#   6 diag checker + sig encoding rejects only the second sig (0x41)
#   7 pubkey encoding rejects
case "$CASE" in
  0) MACS=(-DBTC_EQUIV_CHECK_SIG_MODE=0 -DBTC_EQUIV_SIG_ENC_MODE=0 -DBTC_EQUIV_PK_ENC_MODE=0) ;;
  1) MACS=(-DBTC_EQUIV_CHECK_SIG_MODE=1 -DBTC_EQUIV_SIG_ENC_MODE=0 -DBTC_EQUIV_PK_ENC_MODE=0) ;;
  2) MACS=(-DBTC_EQUIV_CHECK_SIG_MODE=2 -DBTC_EQUIV_SIG_ENC_MODE=0 -DBTC_EQUIV_PK_ENC_MODE=0) ;;
  3) MACS=(-DBTC_EQUIV_CHECK_SIG_MODE=3 -DBTC_EQUIV_SIG_ENC_MODE=0 -DBTC_EQUIV_PK_ENC_MODE=0) ;;
  4) MACS=(-DBTC_EQUIV_CHECK_SIG_MODE=4 -DBTC_EQUIV_SIG_ENC_MODE=0 -DBTC_EQUIV_PK_ENC_MODE=0) ;;
  5) MACS=(-DBTC_EQUIV_CHECK_SIG_MODE=0 -DBTC_EQUIV_SIG_ENC_MODE=1 -DBTC_EQUIV_PK_ENC_MODE=0) ;;
  6) MACS=(-DBTC_EQUIV_CHECK_SIG_MODE=2 -DBTC_EQUIV_SIG_ENC_MODE=2 -DBTC_EQUIV_PK_ENC_MODE=0) ;;
  7) MACS=(-DBTC_EQUIV_CHECK_SIG_MODE=0 -DBTC_EQUIV_SIG_ENC_MODE=0 -DBTC_EQUIV_PK_ENC_MODE=1) ;;
  *) echo "unknown case $CASE" >&2; exit 2 ;;
esac

if [ "$MODE" = "alive2" ]; then
  "${CXX[@]}" -S -emit-llvm "$C_SRC" -o "$BUILD/c_leaf.ll"
  "${CXX[@]}" -S -emit-llvm "$L_SRC" -o "$BUILD/l_leaf.ll"
  {
    printf 'mode=alive2\n'
    printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
    printf 'llvm=%s\n' "$("$LLVM/llvm-extract" --version | head -1)"
    printf 'c_leaf_sha256=%s\n' "$(sha256sum "$BUILD/c_leaf.ll" | cut -d' ' -f1)"
    printf 'l_leaf_sha256=%s\n' "$(sha256sum "$BUILD/l_leaf.ll" | cut -d' ' -f1)"
  } > "$BUILD/build.txt"
else
  "${CXX[@]}" -c -emit-llvm "$C_SRC" -o "$BUILD/c_leaf.bc"
  "${CXX[@]}" -c -emit-llvm "$L_SRC" -o "$BUILD/l_leaf.bc"
  "${CXX[@]}" "${MACS[@]}" -c -emit-llvm "$SH/checker_stub.cpp" \
    -o "$BUILD/checker_stub_c${CASE}.bc"
  "$LLVM/llvm-link" "$BUILD/c_leaf.bc" "$BUILD/checker_stub_c${CASE}.bc" \
    -o "$BUILD/c_saw_c${CASE}.bc"
  "$LLVM/llvm-link" "$BUILD/l_leaf.bc" "$BUILD/checker_stub_c${CASE}.bc" \
    -o "$BUILD/l_saw_c${CASE}.bc"
  "$LLVM/llvm-dis" "$BUILD/c_saw_c${CASE}.bc" -o "$BUILD/c_saw_c${CASE}.ll"
  "$LLVM/llvm-dis" "$BUILD/l_saw_c${CASE}.bc" -o "$BUILD/l_saw_c${CASE}.ll"
  {
    printf 'mode=saw case=%s\n' "$CASE"
    printf 'clang=%s\n' "$(/usr/bin/clang++-20 --version | head -1)"
    printf 'llvm=%s\n' "$("$LLVM/llvm-link" --version | head -1)"
    printf 'c_bc_sha256=%s\n' "$(sha256sum "$BUILD/c_saw_c${CASE}.bc" | cut -d' ' -f1)"
    printf 'l_bc_sha256=%s\n' "$(sha256sum "$BUILD/l_saw_c${CASE}.bc" | cut -d' ' -f1)"
  } > "$BUILD/build_saw_c${CASE}.txt"
fi
