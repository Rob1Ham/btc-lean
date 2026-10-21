#!/usr/bin/env bash
# Alive2 attempt for the E4 witness-v0 dispatch cell.  The function takes two
# symbolic i64 arguments, so this is a symbolic dispatch proof, not a closed
# witness.  alive-tv exits 0 even on a counterexample, so the report text is
# parsed.
set -euo pipefail
CELL_DIR="$1"
E4="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$E4/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
FNS=(cell_v0_dispatch)
mkdir -p "$OUT"
"$E4/build_leaf.sh" "$CELL_DIR"
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: e4-witness/C-L-witness-v0-dispatch"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# command: alive-tv build/c_cell_v0_dispatch.ll build/l_cell_v0_dispatch.ll"
  for fn in "${FNS[@]}"; do
    fnout="$(/usr/local/bin/alive-tv "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
       || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
       || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
       || printf '%s' "$fnout" | grep -q "ERROR:"; then
      OK=0
    fi
  done
} > "$RES" 2>&1
if [ "$OK" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
  STATUS=0
else
  echo "STATUS=alive2-not-green" >> "$RES"
  STATUS=1
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh"
  "$E4/e4_common.h" "$E4/c_cell.cpp" "$E4/l_cell.cpp"
  "$E4/build_leaf.sh" "$BUILD/c_leaf.ll" "$BUILD/l_leaf.ll"
  "$BUILD/c_cell_v0_dispatch.ll" "$BUILD/l_cell_v0_dispatch.ll" "$RES"
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
exit "$STATUS"
