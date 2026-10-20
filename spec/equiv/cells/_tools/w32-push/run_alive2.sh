#!/usr/bin/env bash
# Alive2 runner for wave-32 cells.
# Usage: run_alive2.sh CELL_DIR CELL_ID
# Function list: CELL_DIR/src/fns.txt
set -euo pipefail
CELL_DIR="$1"; CELL_ID="$2"
W32="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
mkdir -p "$OUT"
"$W32/build.sh" "$CELL_DIR"
FNS="$(grep -v '^[[:space:]]*#' "$CELL_DIR/src/fns.txt" | sed '/^[[:space:]]*$/d')"
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: $CELL_ID"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# build: build/build.txt"
  for fn in $FNS; do
    echo "# command: alive-tv --bidirectional --smt-to=60000 build/c_${fn}.ll build/l_${fn}.ll"
    fnout="$(/usr/local/bin/alive-tv --bidirectional --smt-to=60000 "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
       || ! printf '%s' "$fnout" | grep -q "These functions seem to be equivalent" \
       || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
       || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
       || printf '%s' "$fnout" | grep -q "ERROR:"; then
      OK=0
    fi
  done
} > "$RES" 2>&1
if [ "$OK" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
else
  echo "STATUS=alive2-not-green" >> "$RES"
fi
"$W32/certify.sh" "$CELL_DIR" "$OUT/certificate.sha256" "$RES"
[ "$OK" -eq 1 ]
