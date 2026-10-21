#!/usr/bin/env bash
# SAW leg: both C and L modules verified against the shared numeric model
# (tools/num.cry) plus the cell-local raw-push observable (src/cell_extra.cry).
#
# Unlike the other wave-16 numeric cells this cell has a local model fragment,
# so the SAW runner assembles build/cell.cry itself instead of calling
# tools/run_saw.sh (which knows only tools/num.cry).
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL/../../.." && pwd)"
TOOLS="$(cd "$EQ/findings/wave16/07-numeric-ops/tools" && pwd)"
BUILD="$CELL/build"
OUT="$CELL/saw"
SAWDIR=/opt/equiv-tools/saw-1.6/bin
MIN_PROOFS=8
mkdir -p "$OUT"

"$CELL/src/build.sh" "$CELL"

# One self-contained Cryptol module: the shared model with the cell-local
# raw-push definitions appended.  No module search path is involved.
{
  echo "module CellSpec where"
  grep -v '^module Num where$' "$TOOLS/num.cry"
  cat "$CELL/src/cell_extra.cry"
} > "$BUILD/cell.cry"
cp "$CELL/src/cell.saw" "$BUILD/cell.saw"

RES="$OUT/result.txt"
{
  echo "# cell: numeric/C-L-reinterpret-limit"
  echo "# saw: $(PATH="$SAWDIR:$PATH" saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry (tools/num.cry + src/cell_extra.cry as module CellSpec)"
  echo "# script: build/cell.saw"
  echo "# expected: at least $MIN_PROOFS 'Proof succeeded!' and no 'Proof failed'"
  echo
  ( cd "$BUILD" && PATH="$SAWDIR:$PATH" saw cell.saw )
} > "$RES" 2>&1 || true

OK=0
if [ "$(grep -c '^Proof succeeded!' "$RES" || true)" -ge "$MIN_PROOFS" ] \
   && ! grep -q '^Proof failed' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi

# shellcheck disable=SC1091
source "$TOOLS/certify.sh"
cell_certify "$CELL" "$OUT/certificate.sha256" "$RES" "$BUILD" "$TOOLS" "$EQ"
[ "$OK" -eq 1 ]
