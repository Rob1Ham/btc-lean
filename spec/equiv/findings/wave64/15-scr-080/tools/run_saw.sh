#!/usr/bin/env bash
# SAW runner for the wave-64 SCR-080 cell.
#
#   run_saw.sh CELL_DIR CELL_ID MIN_PROOFS
#
# build/cell.cry wraps the cell's src/cell.cry as one self-contained Cryptol
# module (the .saw imports it by file name, so no module search path is
# involved).  Requires at least MIN_PROOFS "Proof succeeded!" lines and zero
# "Proof failed" lines.  Solver: z3.
set -euo pipefail
CELL_DIR="$(cd "$1" && pwd)"; shift
CELL_ID="$1"; shift
MIN_PROOFS="$1"; shift
TOOLS="$(cd "$(dirname "$0")" && pwd)"
EQ="$(cd "$TOOLS/../../../.." && pwd)"
REPO="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
SAWDIR=/opt/equiv-tools/saw-1.6/bin
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh" "$CELL_DIR"

cp "$CELL_DIR/src/cell.cry" "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"

RES="$OUT/result.txt"
{
  echo "# cell: $CELL_ID"
  echo "# saw: $(PATH="$SAWDIR:$PATH" saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry (src/cell.cry verbatim)"
  echo "# script: build/cell.saw"
  echo "# solver: z3"
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
{
  cd "$REPO"
  for p in "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/saw/run.sh" \
           "$CELL_DIR/src" "$TOOLS" "$EQ/contract/error_kind.h" \
           "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py" "$EQ/twin/runtime.inc" \
           "$EQ/cells/_tools/mk_leaf.py" "$EQ/findings/wave16/07-numeric-ops/tools/mk_num_leaf.py" \
           "$RES"; do
    rp="$(realpath --relative-to="$REPO" "$p")"
    if [ -d "$rp" ]; then
      find "$rp" -type f -print0 | sort -z | xargs -0 -r sha256sum
    else
      sha256sum "$rp"
    fi
  done
} > "$OUT/certificate.sha256"
[ "$OK" -eq 1 ]
