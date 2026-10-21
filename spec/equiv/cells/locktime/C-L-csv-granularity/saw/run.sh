#!/usr/bin/env bash
# SAW leg for locktime/C-L-csv-granularity: verify both modules against four
# independent Cryptol predicates, then require eight "Proof succeeded!" lines.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
MIN_PROOFS=8
FNS=(cell_csv_masked cell_csv_mask_probe cell_seq_granularity cell_seq_time_ok)
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh"
cp "$CELL_DIR/src/cell.cry" "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"
RES="$OUT/result.txt"
{
  echo "# cell: locktime/C-L-csv-granularity"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry"
  echo "# script: build/cell.saw"
  echo "# expected: at least $MIN_PROOFS 'Proof succeeded!' and no 'Proof failed'"
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
BC=()
for fn in "${FNS[@]}"; do
  BC+=("$BUILD/c_${fn}.bc" "$BUILD/l_${fn}.bc")
done
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh" "$CELL_DIR/src/build.sh"
  "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$CELL_DIR/src/lean_excerpt.md" "$CELL_DIR/src/cell.cry" "$CELL_DIR/src/cell.saw"
  "$EQ/contract/error_kind.h"
  "$BUILD/build.txt" "$BUILD/c_leaf.ll" "$BUILD/l_leaf.ll"
  "${BC[@]}"
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
