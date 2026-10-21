#!/usr/bin/env bash
# Build the bounded C/L leaves for the SCR-074 arity table.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPS="OP_2DROP,OP_2DUP,OP_3DUP,OP_2OVER,OP_2ROT,OP_2SWAP,OP_IFDUP,OP_DROP,OP_DUP,OP_NIP,OP_OVER,OP_PICK,OP_ROT,OP_SWAP,OP_TUCK"
exec "$CELL_DIR/../_harness/build.sh" "$CELL_DIR" "$OPS" 6 1
