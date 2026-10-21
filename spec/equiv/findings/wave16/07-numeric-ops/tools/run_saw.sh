#!/usr/bin/env bash
# SAW runner for the wave-16 numeric cells.
#
#   run_saw.sh CELL_DIR CELL_ID MIN_PROOFS
#
# The cell supplies src/cell.saw.  build/cell.cry is the shared model
# findings/.../tools/num.cry wrapped as one self-contained Cryptol module, so
# no Cryptol module search path is involved; the .saw script imports it by
# file name exactly like cells/e2-numeric/within-boundary does.
set -euo pipefail
CELL_DIR="$(cd "$1" && pwd)"; shift
CELL_ID="$1"; shift
MIN_PROOFS="$1"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
EQ="$(cd "$TOOLS/../../../.." && pwd)"
REPO="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
SAWDIR=/opt/equiv-tools/saw-1.6/bin
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh" "$CELL_DIR"

{
  echo "module CellSpec where"
  grep -v '^module Num where$' "$TOOLS/num.cry"
} > "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"

RES="$OUT/result.txt"
{
  echo "# cell: $CELL_ID"
  echo "# saw: $(PATH="$SAWDIR:$PATH" saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry (tools/num.cry as module CellSpec)"
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
cell_certify "$CELL_DIR" "$OUT/certificate.sha256" "$RES" "$BUILD" "$TOOLS" "$EQ"
[ "$OK" -eq 1 ]
