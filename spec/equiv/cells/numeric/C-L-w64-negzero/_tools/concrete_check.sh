#!/usr/bin/env bash
# Behavioural spot check for SCR-083: compile the same driver against each
# leg, run both, and require byte-identical output.  This is evidence in
# addition to the Alive2/SAW proofs, not a replacement for them.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL_DIR/build"
mkdir -p "$BUILD"
CXX=(/usr/bin/clang++-20 -std=c++17 -O1 -I "$TOOLS")
"${CXX[@]}" "$TOOLS/concrete_check.cpp" "$CELL_DIR/c_cell.cpp" -o "$BUILD/check_c"
"${CXX[@]}" "$TOOLS/concrete_check.cpp" "$CELL_DIR/l_cell.cpp" -o "$BUILD/check_l"
"$BUILD/check_c" > "$BUILD/check_c.out"
"$BUILD/check_l" > "$BUILD/check_l.out"
diff -u "$BUILD/check_c.out" "$BUILD/check_l.out" > "$BUILD/check.diff" || {
  echo "C and L disagree on concrete vectors" >&2
  cat "$BUILD/check.diff" >&2
  exit 1
}
cat "$BUILD/check_c.out"
