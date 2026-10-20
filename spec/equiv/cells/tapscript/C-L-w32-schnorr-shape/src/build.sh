#!/usr/bin/env bash
# Build both legs of C-L-w32-schnorr-shape.
#
#   build.sh alive2
#   build.sh saw <tail_result>
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$CELL_DIR/src"
BUILD="$CELL_DIR/build"
MODE="${1:-alive2}"
TAIL="${2:-0}"
LLVM=/usr/lib/llvm-20/bin
CXX=/usr/bin/clang++-20
mkdir -p "$BUILD"

CXXFLAGS=(-std=c++17 -I "$SRC" -fno-discard-value-names -fno-strict-aliasing)

if [ "$MODE" = "alive2" ]; then
  "$CXX" "${CXXFLAGS[@]}" -O1 -S -emit-llvm "$SRC/c_tap.cpp" -o "$BUILD/c_shape.ll"
  "$CXX" "${CXXFLAGS[@]}" -O1 -S -emit-llvm "$SRC/l_tap.cpp" -o "$BUILD/l_shape.ll"
  {
    echo "mode=alive2"
    echo "clang=$("$CXX" --version | head -1)"
    echo "llvm=$("$LLVM/llvm-extract" --version | head -1)"
    echo "c_shape_sha256=$(sha256sum "$BUILD/c_shape.ll" | cut -d' ' -f1)"
    echo "l_shape_sha256=$(sha256sum "$BUILD/l_shape.ll" | cut -d' ' -f1)"
    echo "tap_common_sha256=$(sha256sum "$SRC/tap_common.h" | cut -d' ' -f1)"
  } > "$BUILD/build.txt"
elif [ "$MODE" = "saw" ]; then
  "$CXX" "${CXXFLAGS[@]}" -O0 -c -emit-llvm "$SRC/c_tap.cpp" -o "$BUILD/c_shape.bc"
  "$CXX" "${CXXFLAGS[@]}" -O0 -c -emit-llvm "$SRC/l_tap.cpp" -o "$BUILD/l_shape.bc"
  "$CXX" "${CXXFLAGS[@]}" -O0 -c -emit-llvm \
    -DBTC_EQUIV_TAIL_RESULT="$TAIL" "$SRC/tail_stub.cpp" \
    -o "$BUILD/tail_stub_${TAIL}.bc"
  "$LLVM/llvm-link" "$BUILD/c_shape.bc" "$BUILD/tail_stub_${TAIL}.bc" \
    -o "$BUILD/c_shape_saw_${TAIL}.bc"
  "$LLVM/llvm-link" "$BUILD/l_shape.bc" "$BUILD/tail_stub_${TAIL}.bc" \
    -o "$BUILD/l_shape_saw_${TAIL}.bc"
  "$LLVM/llvm-dis" "$BUILD/c_shape_saw_${TAIL}.bc" -o "$BUILD/c_shape_saw_${TAIL}.ll"
  "$LLVM/llvm-dis" "$BUILD/l_shape_saw_${TAIL}.bc" -o "$BUILD/l_shape_saw_${TAIL}.ll"
  {
    echo "mode=saw tail_result=$TAIL"
    echo "clang=$("$CXX" --version | head -1)"
    echo "llvm=$("$LLVM/llvm-link" --version | head -1)"
    echo "c_bc_sha256=$(sha256sum "$BUILD/c_shape_saw_${TAIL}.bc" | cut -d' ' -f1)"
    echo "l_bc_sha256=$(sha256sum "$BUILD/l_shape_saw_${TAIL}.bc" | cut -d' ' -f1)"
    echo "stub_sha256=$(sha256sum "$BUILD/tail_stub_${TAIL}.bc" | cut -d' ' -f1)"
  } > "$BUILD/build_saw_${TAIL}.txt"
else
  echo "unknown mode: $MODE" >&2
  exit 2
fi
