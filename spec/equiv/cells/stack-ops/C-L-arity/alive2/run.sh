#!/usr/bin/env bash
# Alive2 for the SCR-074 arity table: one C-vs-L query per (opcode, depth) row.
# The row census is table.csv; check_table.py fails the run if the leaves or
# fns.txt drift from it.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPS="OP_2DROP,OP_2DUP,OP_3DUP,OP_2OVER,OP_2ROT,OP_2SWAP,OP_IFDUP,OP_DROP,OP_DUP,OP_NIP,OP_OVER,OP_PICK,OP_ROT,OP_SWAP,OP_TUCK"
python3 "$CELL_DIR/src/check_table.py"
python3 "$CELL_DIR/src/gen_saw.py" --check
exec "$CELL_DIR/src/run_alive2.sh" "$CELL_DIR" "stack-ops/C-L-arity" "$OPS" 6 1 30000 O1
