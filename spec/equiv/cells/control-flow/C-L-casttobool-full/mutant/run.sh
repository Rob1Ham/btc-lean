#!/usr/bin/env bash
# Non-vacuity probe for control-flow/C-L-casttobool-full.
#
# Mutates only the L IR so that the negative-zero branch is disabled (always
# true for a nonzero last byte).  Alive2 must report an incorrect
# transformation at n=1, b=0x80 (C=0, L=1), and SAW must fail the L proof.
#
# Run from the cell directory after src/build.sh has produced build/:
#   spec/equiv/cells/control-flow/C-L-casttobool-full/mutant/run.sh
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$CELL_DIR/build"
cd "$CELL_DIR"

sed 's/%or.cond.not.i = or i1 %cmp6.i, %cmp2.i/%or.cond.not.i = or i1 true, %cmp2.i/' \
  build/l_cell_cast_arb.ll > "$OUT/l_mutant_negzero_off.ll"
/usr/lib/llvm-20/bin/llvm-as "$OUT/l_mutant_negzero_off.ll" \
  -o "$OUT/l_mutant_negzero_off.bc"

alive-tv --smt-to=60000 build/c_cell_cast_arb.ll \
  "$OUT/l_mutant_negzero_off.ll" > "$OUT/alive2-negzero-off.txt" 2>&1 || true

M="$OUT/saw-negzero-off"
mkdir -p "$M"
cp build/c_cell_cast_arb.bc "$M/"
cp "$OUT/l_mutant_negzero_off.bc" "$M/l_cell_cast_arb.bc"
cp src/cell.cry src/cell.saw "$M/"
( cd "$M" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH \
    timeout 1200 saw cell.saw > saw-negzero-off.txt 2>&1 ) || true
