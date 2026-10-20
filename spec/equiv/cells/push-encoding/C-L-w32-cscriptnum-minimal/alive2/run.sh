#!/usr/bin/env bash
# Alive2 run for C-L-w32-cscriptnum-minimal.
set -euo pipefail
CELL_DIR="$(cd "$1" && pwd)"
CELLS="$(cd "$(dirname "$0")/../../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
FNS=(cell_cscriptnum)
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh"
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: push-encoding/C-L-w32-cscriptnum-minimal"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  for fn in "${FNS[@]}"; do
    echo "# command: alive-tv build/c_${fn}.ll build/l_${fn}.ll"
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
  echo "STATUS=alive2-green" >> "$RES"; STATUS=0
else
  echo "STATUS=alive2-not-green" >> "$RES"; STATUS=1
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh"
  "$CELL_DIR/src/build.sh" "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$EQ/contract/error_kind.h" "$BUILD/c_leaf.ll" "$BUILD/l_leaf.ll"
  "$BUILD/c_cell_cscriptnum.bc" "$BUILD/l_cell_cscriptnum.bc" "$BUILD/build.txt" "$RES"
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
