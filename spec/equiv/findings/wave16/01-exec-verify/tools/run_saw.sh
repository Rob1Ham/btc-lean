#!/usr/bin/env bash
# Generic SAW runner for the wave16/01-exec-verify bounded leaves.
#
#   saw/run.sh  ->  exec this script with the cell directory
#
# The cell commits `saw/cell.cry` (the declared postcondition) and
# `saw/cell.saw` (the verification script).  Both legs are verified against
# the SAME Cryptol function, so the row table is checked independently of the
# C/L code.  SAW runs with cwd = build/ so `llvm_load_module` names are local.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$HERE/lib.sh"

CELL_DIR="$(cd "${1:-$HERE/..}" && pwd)"
# shellcheck disable=SC1090
source "$CELL_DIR/cell.conf"
SAW="$(ev_saw)"
# abc/boolector/... live next to saw; make them discoverable for `abc` proofs.
PATH="$(dirname "$SAW"):$PATH"; export PATH

ev_build_pair "$CELL_DIR"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
RES="$OUT/result.txt"
NFN=$(printf '%s\n' $FNS | wc -l)
{
  echo "# cell: $CELL_ID"
  echo "# saw: $("$SAW" --version 2>&1 | head -1)"
  echo "# spec: saw/cell.cry + saw/cell.saw (both legs verified against it)"
  echo "# functions: $FNS"
  echo
  ( cd "$BUILD" && "$SAW" "$CELL_DIR/saw/cell.saw" )
} > "$RES" 2>&1 || true
OK=0
if [ "$(grep -c 'Proof succeeded!' "$RES" || true)" -ge "$((2 * NFN))" ] \
   && grep -q "CELL_${CELL_ID//-/_}_SAW_GREEN" "$RES" \
   && ! grep -q 'Proof failed' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi
FILES=(
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/spec.md"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/saw/run.sh"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/saw/cell.cry"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/saw/cell.saw"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/cell.conf"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/src/common.h"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/src/c_cell.cpp"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/src/l_cell.cpp"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/build/build.txt"
  "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/saw/result.txt"
  "spec/equiv/findings/wave16/01-exec-verify/tools/lib.sh"
  "spec/equiv/findings/wave16/01-exec-verify/tools/run_saw.sh"
)
for fn in $FNS; do
  FILES+=(
    "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/build/c_${fn}.bc"
    "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/build/l_${fn}.bc"
    "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/build/c_${fn}.ll"
    "spec/equiv/cells/$FAMILY_DIR/$CELL_NAME/build/l_${fn}.ll"
  )
done
ev_certificate "$CELL_DIR" "${FILES[@]}" > "$OUT/certificate.sha256"
[ "$OK" -eq 1 ]
