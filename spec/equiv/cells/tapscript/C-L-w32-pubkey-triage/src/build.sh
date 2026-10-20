#!/usr/bin/env bash
# Build both legs of C-L-w32-pubkey-triage.
#
#   build.sh alive2
#   build.sh saw <checker_result>
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$CELL_DIR/src"
BUILD="$CELL_DIR/build"
MODE="${1:-alive2}"
CK="${2:-0}"
LLVM=/usr/lib/llvm-20/bin
CXX=/usr/bin/clang++-20
mkdir -p "$BUILD"

CXXFLAGS=(-std=c++17 -I "$SRC" -fno-discard-value-names -fno-strict-aliasing)

if [ "$MODE" = "alive2" ]; then
  "$CXX" "${CXXFLAGS[@]}" -O1 -S -emit-llvm "$SRC/c_tap.cpp" -o "$BUILD/c_leaf.ll"
  "$CXX" "${CXXFLAGS[@]}" -O1 -S -emit-llvm "$SRC/l_tap.cpp" -o "$BUILD/l_leaf.ll"
  {
    echo "mode=alive2"
    echo "clang=$("$CXX" --version | head -1)"
    echo "llvm=$("$LLVM/llvm-extract" --version | head -1)"
    echo "c_leaf_sha256=$(sha256sum "$BUILD/c_leaf.ll" | cut -d' ' -f1)"
    echo "l_leaf_sha256=$(sha256sum "$BUILD/l_leaf.ll" | cut -d' ' -f1)"
    echo "tap_common_sha256=$(sha256sum "$SRC/tap_common.h" | cut -d' ' -f1)"
  } > "$BUILD/build.txt"
elif [ "$MODE" = "saw" ]; then
  "$CXX" "${CXXFLAGS[@]}" -O0 -c -emit-llvm "$SRC/c_tap.cpp" -o "$BUILD/c_leaf.bc"
  "$CXX" "${CXXFLAGS[@]}" -O0 -c -emit-llvm "$SRC/l_tap.cpp" -o "$BUILD/l_leaf.bc"
  "$CXX" "${CXXFLAGS[@]}" -O0 -c -emit-llvm \
    -DBTC_EQUIV_CHECKER_RESULT="$CK" "$SRC/checker_stub.cpp" \
    -o "$BUILD/checker_stub_${CK}.bc"
  "$LLVM/llvm-link" "$BUILD/c_leaf.bc" "$BUILD/checker_stub_${CK}.bc" \
    -o "$BUILD/c_leaf_saw_${CK}.bc"
  "$LLVM/llvm-link" "$BUILD/l_leaf.bc" "$BUILD/checker_stub_${CK}.bc" \
    -o "$BUILD/l_leaf_saw_${CK}.bc"
  "$LLVM/llvm-dis" "$BUILD/c_leaf_saw_${CK}.bc" -o "$BUILD/c_leaf_saw_${CK}.ll"
  "$LLVM/llvm-dis" "$BUILD/l_leaf_saw_${CK}.bc" -o "$BUILD/l_leaf_saw_${CK}.ll"
  {
    echo "mode=saw checker_result=$CK"
    echo "clang=$("$CXX" --version | head -1)"
    echo "llvm=$("$LLVM/llvm-link" --version | head -1)"
    echo "c_bc_sha256=$(sha256sum "$BUILD/c_leaf_saw_${CK}.bc" | cut -d' ' -f1)"
    echo "l_bc_sha256=$(sha256sum "$BUILD/l_leaf_saw_${CK}.bc" | cut -d' ' -f1)"
    echo "stub_sha256=$(sha256sum "$BUILD/checker_stub_${CK}.bc" | cut -d' ' -f1)"
  } > "$BUILD/build_saw_${CK}.txt"
else
  echo "unknown mode: $MODE" >&2
  exit 2
fi
