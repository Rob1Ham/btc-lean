#!/usr/bin/env bash
# Generic Alive2 runner for the wave16/01-exec-verify bounded leaves.
#
#   alive2/run.sh  ->  exec this script with the cell directory
#
# The cell's `cell.conf` lists the exported functions (FNS=...).  For each
# function we compare the C-leg leaf against the L-leg leaf.  alive-tv exits 0
# even on a counterexample, so the report text is parsed.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$HERE/lib.sh"

CELL_DIR="$(cd "${1:-$HERE/..}" && pwd)"
ROOT="$(ev_root "$CELL_DIR")"
# shellcheck disable=SC1090
source "$CELL_DIR/cell.conf"
ALIVE="$(ev_alive_tv)"
ALIVE_FLAGS="${ALIVE2_FLAGS:-}"

ev_build_pair "$CELL_DIR"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
RES="$OUT/result.txt"
mkdir -p "$OUT"
OK=1
{
  echo "# cell: $CELL_ID"
  echo "# alive-tv: $($ALIVE --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# functions: $FNS"
  for fn in $FNS; do
    echo "# command: alive-tv $ALIVE_FLAGS build/c_${fn}.ll build/l_${fn}.ll"
    fnout="$($ALIVE $ALIVE_FLAGS "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
       || ! printf '%s' "$fnout" | grep -q "0 incorrect transformations" \
       || ! printf '%s' "$fnout" | grep -q "0 Alive2 errors" \
       || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
       || printf '%s' "$fnout" | grep -q "ERROR:"; then
      OK=0
    fi
  done
} > "$RES" 2>&1
if [ "$OK" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
  STATUS=0
else
  echo "STATUS=alive2-not-green" >> "$RES"
  STATUS=1
fi
FILES=(
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/spec.md"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/alive2/run.sh"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/cell.conf"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/src/common.h"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/src/c_cell.cpp"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/src/l_cell.cpp"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/build/build.txt"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/alive2/result.txt"
  "spec/equiv/findings/wave16/01-exec-verify/tools/lib.sh"
  "spec/equiv/findings/wave16/01-exec-verify/tools/run_alive2.sh"
)
for fn in $FNS; do
  FILES+=(
    "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/build/c_${fn}.ll"
    "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/build/l_${fn}.ll"
    "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/build/c_${fn}.bc"
    "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/build/l_${fn}.bc"
  )
done
ev_certificate "$CELL_DIR" "${FILES[@]}" > "$OUT/certificate.sha256"
exit "$STATUS"
