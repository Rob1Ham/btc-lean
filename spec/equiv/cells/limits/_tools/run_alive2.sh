#!/usr/bin/env bash
# Generic Alive2 runner for the bounded `limits` cells.
# Usage: run_alive2.sh CELL_DIR CELL_ID FN [FN...]
set -euo pipefail
CELL_DIR="$1"; shift
CELL_ID="$1"; shift
FNS=("$@")
HERE="$(cd "$(dirname "$0")" && pwd)"
EQ="$(cd "$HERE/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
mkdir -p "$OUT"
"$HERE/build_leaf.sh" "$CELL_DIR" "${FNS[@]}"
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: $CELL_ID"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# limits_common source: build/build.txt sha256 $(sha256sum "$BUILD/build.txt" | cut -d' ' -f1)"
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
  echo "STATUS=alive2-green" >> "$RES"
  STATUS=0
else
  echo "STATUS=alive2-not-green" >> "$RES"
  STATUS=1
fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh" "$CELL_DIR/src/c_leaf.cpp"
  "$CELL_DIR/src/l_leaf.cpp"
  "$HERE/limits_common.h" "$HERE/build_leaf.sh" "$HERE/run_alive2.sh"
  "$HERE/run_saw.sh"
  "$EQ/contract/error_kind.h"
)
for fn in "${FNS[@]}"; do
  FILES+=("$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" "$BUILD/c_${fn}.bc" "$BUILD/l_${fn}.bc")
done
FILES+=("$BUILD/build.txt" "$RES")
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
