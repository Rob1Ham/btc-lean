#!/usr/bin/env bash
# SAW runner for the `limits` family cells.
#
#   run_saw.sh CELL_DIR CELL_ID MIN_PROOFS
#
# The cell supplies src/cell.cry and src/cell.saw; they are copied into build/
# so the recorded invocation is reproducible from the artifacts.
set -euo pipefail

CELL_DIR="$(cd "$1" && pwd)"
CELL_ID="$2"
MIN_PROOFS="$3"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$TOOLS/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
SAW_BIN="${SAW_BIN:-/opt/equiv-tools/saw-1.6/bin/saw}"
# SAW shells out to its bundled solvers by name.
export PATH="$(dirname "$SAW_BIN"):$PATH"

mkdir -p "$OUT"
"$CELL_DIR/src/build.sh" "$CELL_DIR"
cp "$CELL_DIR/src/cell.cry" "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"

RES="$OUT/result.txt"
{
  echo "# cell: $CELL_ID"
  echo "# saw: $("$SAW_BIN" --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry"
  echo "# script: build/cell.saw"
  echo "# expected: at least $MIN_PROOFS 'Proof succeeded!' and no 'Proof failed'"
  echo
  ( cd "$BUILD" && "$SAW_BIN" cell.saw )
} > "$RES" 2>&1 || true

OK=0
if [ "$(grep -c '^Proof succeeded!' "$RES" || true)" -ge "$MIN_PROOFS" ] \
   && ! grep -q '^Proof failed' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh" "$CELL_DIR/src/build.sh"
  "$CELL_DIR/src/c_leg.cpp" "$CELL_DIR/src/l_leg.cpp"
  "$CELL_DIR/src/functions.txt" "$CELL_DIR/src/cell.cry" "$CELL_DIR/src/cell.saw"
  "$TOOLS/limits_common.h" "$TOOLS/build_limits.sh"
  "$TOOLS/run_alive2.sh" "$TOOLS/run_saw.sh" "$RES"
)
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    if [ -f "$f" ]; then
      sha256sum "${f#"$ROOT"/}"
    else
      echo "MISSING $f" >&2
      exit 1
    fi
  done
} > "$OUT/certificate.sha256"

[ "$OK" -eq 1 ]
