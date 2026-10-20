#!/usr/bin/env bash
# Concrete behavior witness for C-L-taproot-activation-gate.
# NOT proof evidence; see alive2/result.txt and saw/result.txt.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$CELL/build"
OUT="$CELL/behavior"
mkdir -p "$OUT" "$BUILD"
/usr/bin/clang++-20 -std=c++17 -O1 -I "$CELL" \
  "$CELL/behavior/driver.cpp" "$CELL/c_leg.cpp" \
  -o "$BUILD/behavior_driver"
RES="$OUT/result.txt"
{
  echo "# cell: tapscript/C-L-taproot-activation-gate"
  echo "# command: clang++-20 -O1 behavior/driver.cpp c_leg.cpp && ./build/behavior_driver"
  echo "# note: behavioral witness only; not proof evidence"
  echo
  "$BUILD/behavior_driver" || true
} > "$RES" 2>&1
if grep -q '^STATUS=behavior-match$' "$RES"; then
  exit 0
fi
exit 1
