#!/usr/bin/env bash
# SAW for control-flow/C-L-casttobool-full.
#
# Each leg is verified against the same independent Cryptol scan/no-scan
# predicate.  The length is symbolic under n <= 520 and all 520 bytes are
# symbolic, so the proof covers every length in the consensus domain and every
# byte vector in one check per leg.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CELLS="$(cd "$CELL_DIR/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
FN=cell_cast_arb
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh" "$CELL_DIR"
cp "$CELL_DIR/src/cell.cry" "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"

RES="$OUT/result.txt"
{
  echo "# cell: control-flow/C-L-casttobool-full"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry (independent scan/no-scan predicate)"
  echo "# script: build/cell.saw"
  echo "# domain: symbolic n, n <= 520; fully symbolic 520-byte array"
  echo "# expected: 2 'Proof succeeded!' (C and L) and no 'Proof failed'"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH \
      timeout 2400 saw cell.saw )
} > "$RES" 2>&1 || true

OK=0
if [ "$(grep -c '^Proof succeeded!' "$RES" || true)" -ge 2 ] \
   && ! grep -q '^Proof failed' "$RES" \
   && ! grep -q 'Stack trace' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/saw/run.sh"
  "$CELL_DIR/src/build.sh" "$CELL_DIR/src/cell.h"
  "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$CELL_DIR/src/extract_twin.py" "$CELL_DIR/src/cell.cry"
  "$CELL_DIR/src/cell.saw"
  "$EQ/twin/runtime.inc" "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py"
  "$EQ/contract/error_kind.h"
  "$BUILD/twin_cast_to_bool.h" "$BUILD/build.txt"
  "$BUILD/c_${FN}.bc" "$BUILD/l_${FN}.bc"
  "$BUILD/cell.cry" "$BUILD/cell.saw" "$RES"
)
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" ;;
      *) echo "# outside-root $(sha256sum "$f")" ;;
    esac
  done
} > "$OUT/certificate.sha256"
[ "$OK" -eq 1 ]
