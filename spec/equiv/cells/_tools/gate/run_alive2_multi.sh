#!/usr/bin/env bash
# Alive2 attempt for a multi-function broader cell.
# The cell's alive2/manifest.txt has lines: <fn> <expected>
# Each function is extracted and compared independently; the cell is green
# only if every comparison is "1 correct transformation" with no failures.
set -euo pipefail

CELL_DIR="$1"
ID="$2"
GATE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$GATE/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
MAN="$OUT/manifest.txt"
mkdir -p "$OUT"

[ -f "$MAN" ] || { echo "missing $MAN" >&2; exit 2; }
RES="$OUT/result.txt"
: > "$RES"
{
  echo "# cell: $ID"
  echo "# command: per-function /usr/local/bin/alive-tv build/c_<fn>.ll build/l_<fn>.ll"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo
} >> "$RES"

N=0
while read -r fn exp; do
  [ -z "${fn:-}" ] && continue
  N=$((N + 1))
  "$GATE/build_leaf.sh" "$CELL_DIR" "$fn" >/dev/null
  {
    echo "### function: $fn"
    echo "# expected packed: $exp"
    /usr/local/bin/alive-tv "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll"
    echo
  } >> "$RES" 2>&1
done < "$MAN"

OK=$(grep -c "Transformation seems to be correct!" "$RES" || true)
if [ "$OK" -eq "$N" ] \
   && ! grep -q "Transformation doesn't verify!" "$RES" \
   && [ "$(grep -c "0 failed-to-prove transformations" "$RES" || true)" -eq "$N" ] \
   && [ "$(grep -c "0 incorrect transformations" "$RES" || true)" -eq "$N" ]; then
  echo "STATUS=alive2-green" >> "$RES"
  STATUS=0
else
  echo "STATUS=alive2-not-green (green=$OK/$N)" >> "$RES"
  STATUS=1
fi

FILES=(
  "$CELL_DIR/spec.md"
  "$CELL_DIR/alive2/run.sh"
  "$CELL_DIR/alive2/manifest.txt"
  "$GATE/run_alive2_multi.sh"
  "$CELLS/_tools/mk_leaf.py"
  "$GATE/build_leaf.sh"
  "$GATE/gate_common.h"
  "$GATE/c_leaf.cpp"
  "$GATE/l_leaf.cpp"
  "$EQ/twin/ops_ir.py"
  "$EQ/twin/gen.py"
  "$EQ/contract/error_kind.h"
  "$BUILD/twin_ops.h"
  "$RES"
)
while read -r fn exp; do
  [ -z "${fn:-}" ] && continue
  FILES+=("$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll")
done < "$MAN"

{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" ;;
      *) echo "# outside-root $(sha256sum "$f")" ;;
    esac
  done
} > "$OUT/certificate.sha256"

exit "$STATUS"
