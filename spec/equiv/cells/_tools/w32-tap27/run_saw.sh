#!/usr/bin/env bash
# SAW attempt for a wave-32 tapscript dispatch cell.
#
#   run_saw.sh CELL_DIR CELL_ID MIN_PROOFS FN [FN...]
#
# The cell's src/cell.cry is the independent specification; both the C excerpt
# and the Lean transliteration are verified against it in the same script.
set -euo pipefail
CELL_DIR="$1"; CELL_ID="$2"; MIN_PROOFS="$3"; shift 3
W32="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$W32/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
mkdir -p "$OUT"
"$W32/build.sh" "$CELL_DIR" "$@"
cp "$CELL_DIR/src/cell.cry" "$CELL_DIR/src/cell.saw" "$BUILD/"
RES="$OUT/result.txt"
{
  echo "# cell: $CELL_ID"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66"
  echo "# spec: build/cell.cry (independent Cryptol statement of the row)"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true
OK=0
if [ "$(grep -c 'Proof succeeded!' "$RES" || true)" -ge "$MIN_PROOFS" ] \
   && ! grep -q 'Proof failed' "$RES" \
   && ! grep -q 'error:' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh"
  "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$CELL_DIR/src/cell.cry" "$CELL_DIR/src/cell.saw"
  "$W32/w32_common.h" "$W32/build.sh"
  "$EQ/contract/error_kind.h" "$BUILD/build.txt" "$RES"
)
for fn in "$@"; do
  FILES+=("$BUILD/c_${fn}.bc" "$BUILD/l_${fn}.bc")
done
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
