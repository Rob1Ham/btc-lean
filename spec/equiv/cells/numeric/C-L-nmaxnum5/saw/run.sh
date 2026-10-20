#!/usr/bin/env bash
# SAW leg: both leaves against the independent Cryptol model src/cell.cry.
#
#   saw/run.sh [CELL_DIR]
#
# Requires six "Proof succeeded!" (three entry points x C/L) and no
# "Proof failed".  The raw output is saw/result.txt; saw/certificate.sha256
# chains it to the tracked inputs.
set -euo pipefail
CELL_DIR="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
REPO="$(cd "$CELL_DIR/../../../../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
MIN_PROOFS=6
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh" "$CELL_DIR"
cp "$CELL_DIR/src/cell.cry" "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"

RES="$OUT/result.txt"
{
  echo "# cell: numeric/C-L-nmaxnum5"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry"
  echo "# script: build/cell.saw"
  echo "# expected: at least $MIN_PROOFS 'Proof succeeded!' and no 'Proof failed'"
  echo "# solver: bitwuzla (see cell.saw)"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
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
  for f in \
    "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" \
    "$CELL_DIR/saw/run.sh" "$CELL_DIR/src/build.sh" \
    "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp" \
    "$CELL_DIR/src/cell.cry" "$CELL_DIR/src/cell.saw" \
    spec/equiv/contract/error_kind.h \
    spec/core/Bitcoin/Numeric/ScriptNum.lean \
    spec/core/Bitcoin/Numeric/Interface.lean \
    spec/core/Bitcoin/Interpreter/Defs.lean \
    spec/db/rules.yaml \
    "$RES"; do
    rel="$(realpath --relative-to="$REPO" "$f")"
    sha256sum "$rel"
  done
} > "$OUT/certificate.sha256"

[ "$OK" -eq 1 ]
