#!/usr/bin/env bash
# SAW for the SCR-074 arity table: one llvm_verify per (row, leg), 110 total.
# The family harness copies src/cell.cry and src/cell.saw into build/ and runs
# saw there, so the recorded artifacts are exactly what ran.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
H="$CELL_DIR/../_harness"
OPS="OP_2DROP,OP_2DUP,OP_3DUP,OP_2OVER,OP_2ROT,OP_2SWAP,OP_IFDUP,OP_DROP,OP_DUP,OP_NIP,OP_OVER,OP_PICK,OP_ROT,OP_SWAP,OP_TUCK"
python3 "$CELL_DIR/src/check_table.py"
python3 "$CELL_DIR/src/gen_saw.py" --check

set +e
"$H/run_saw.sh" "$CELL_DIR" "stack-ops/C-L-arity" "$OPS" 6 1 O1
RC=$?
set -e

# Tracked-input certificate (ignored build/ products excluded).
python3 "$CELL_DIR/src/normalize_cert.py" "$CELL_DIR" "$CELL_DIR/saw/certificate.sha256"
exit "$RC"
