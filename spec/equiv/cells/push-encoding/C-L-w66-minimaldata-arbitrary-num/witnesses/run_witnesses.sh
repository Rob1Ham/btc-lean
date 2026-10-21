#!/usr/bin/env bash
# Concrete witness run for push-encoding/C-L-w66-minimaldata-arbitrary-num.
#
# Compiles witnesses/driver.cpp against the tracked C leaf (scratch output
# only) and checks the error-precedence table plus the policy/consensus lane
# split and the round-trip law over every 1- and 2-byte operand.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
W32="$(cd "$CELL_DIR/../../_tools/w32-push" && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
OUT="$CELL_DIR/witnesses"
TMP="$(mktemp -d /tmp/scr051w66-wit.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

/usr/bin/clang++-20 -std=c++17 -O2 -fno-strict-aliasing \
  -I "$CELL_DIR/src" -I "$EQ/contract" \
  "$CELL_DIR/witnesses/driver.cpp" -o "$TMP/witnesses"

RES="$OUT/result.txt"
{
  echo "# cell: push-encoding/C-L-w66-minimaldata-arbitrary-num (witnesses)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# c_leaf.cpp sha256 $(sha256sum "$CELL_DIR/src/c_leaf.cpp" | cut -d' ' -f1)"
  echo "# driver: witnesses/driver.cpp (linked against src/c_leaf.cpp)"
  echo
  "$TMP/witnesses"
} > "$RES" 2>&1 || true

if grep -q '^WITNESSES_GREEN$' "$RES"; then
  echo "STATUS=witnesses-green" >> "$RES"
  RC=0
else
  echo "STATUS=witnesses-red" >> "$RES"
  RC=1
fi
"$W32/certify.sh" "$CELL_DIR" "$OUT/certificate.sha256" "$RES" \
  "$OUT/driver.cpp" "$OUT/run_witnesses.sh"
exit "$RC"
