#!/usr/bin/env bash
# Build one cell's C and L sources.  Mode "alive2" emits -O1 textual IR for
# llvm-extract; mode "saw" emits -O0 bitcode so closed scenarios exercise the
# real control flow (no constant folding of the core function).
set -euo pipefail

CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$CELL_DIR/src"
BUILD="$CELL_DIR/build"
MODE="${1:-alive2}"
CXX="${CXX:-/usr/bin/clang++-20}"

mkdir -p "$BUILD"
shopt -s nullglob
srcs=("$SRC"/c_*.cpp "$SRC"/l_*.cpp)
if [ "${#srcs[@]}" -eq 0 ]; then
  echo "no c_*.cpp / l_*.cpp in $SRC" >&2
  exit 1
fi

for f in "${srcs[@]}"; do
  base="$(basename "$f" .cpp)"
  case "$MODE" in
    alive2)
      "$CXX" -std=c++17 -O1 -fno-strict-aliasing -S -emit-llvm \
        -I"$SRC" "$f" -o "$BUILD/$base.ll"
      ;;
    saw)
      "$CXX" -std=c++17 -O0 -fno-strict-aliasing -emit-llvm -c \
        -I"$SRC" "$f" -o "$BUILD/$base.bc"
      ;;
    *)
      echo "usage: $0 [alive2|saw]" >&2
      exit 2
      ;;
  esac
done

{
  echo "# build mode: $MODE"
  echo "# clang: $("$CXX" --version | head -1)"
  echo "# sources:"
  for f in "${srcs[@]}"; do
    echo "#   $(basename "$f") sha256=$(sha256sum "$f" | cut -d' ' -f1)"
  done
} > "$BUILD/build-$MODE.txt"

echo "built $MODE in $BUILD"
