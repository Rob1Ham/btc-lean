#!/usr/bin/env bash
# Build a limits-family cell: compile the C and L legs with the pinned clang,
# extract each declared function, and record provenance.
#
#   build_limits.sh CELL_DIR
#
# CELL_DIR/src/functions.txt lists one cell_* function per line.
set -euo pipefail

CELL_DIR="$(cd "$1" && pwd)"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$TOOLS/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
LLVM_BIN=/usr/lib/llvm-20/bin
CXX=/usr/bin/clang++-20

mkdir -p "$BUILD"

CXXFLAGS=(
  -std=c++20 -O1 -fno-strict-aliasing -fno-exceptions -fno-rtti
  -fno-asynchronous-unwind-tables -fno-jump-tables -emit-llvm -c
  -I "$CELL_DIR/src" -I "$TOOLS"
)

"$CXX" "${CXXFLAGS[@]}" "$CELL_DIR/src/c_leg.cpp" -o "$BUILD/c_leg.bc"
"$CXX" "${CXXFLAGS[@]}" "$CELL_DIR/src/l_leg.cpp" -o "$BUILD/l_leg.bc"

while IFS= read -r fn; do
  [ -z "$fn" ] && continue
  case "$fn" in \#*) continue ;; esac
  for leg in c l; do
    "$LLVM_BIN/llvm-extract" --recursive "--func=$fn" \
      "$BUILD/${leg}_leg.bc" -o "$BUILD/${leg}_${fn}.bc"
    "$LLVM_BIN/llvm-dis" "$BUILD/${leg}_${fn}.bc" -o "$BUILD/${leg}_${fn}.ll"
  done
done < "$CELL_DIR/src/functions.txt"

{
  echo "# cell build"
  echo "clang: $("$CXX" --version | head -1)"
  echo "llvm: $("$LLVM_BIN/llvm-dis" --version | head -1)"
  echo "flags: ${CXXFLAGS[*]}"
  echo "tools: cells/_tools/limits/limits_common.h sha256 $(sha256sum "$TOOLS/limits_common.h" | cut -d' ' -f1)"
  echo "sources:"
  ( cd "$ROOT" && sha256sum "spec/equiv/cells/${CELL_DIR#"$CELLS"/}/src/c_leg.cpp" \
      "spec/equiv/cells/${CELL_DIR#"$CELLS"/}/src/l_leg.cpp" 2>/dev/null || \
      sha256sum "$CELL_DIR/src/c_leg.cpp" "$CELL_DIR/src/l_leg.cpp" )
  echo "artifacts:"
  for f in "$BUILD"/*.bc; do
    echo "  $(basename "$f") sha256 $(sha256sum "$f" | cut -d' ' -f1)"
  done
} > "$BUILD/build.txt"

echo "built $CELL_DIR/build" >&2
