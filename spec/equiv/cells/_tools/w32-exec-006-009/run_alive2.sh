#!/usr/bin/env bash
# Alive2 attempt for a wave-32 exec-verify cell.  Both legs are total
# functions over the manifest's uint64 arguments, so this is a symbolic
# equality check, not a closed witness.  alive-tv exits 0 even on a
# counterexample, so the report text is parsed.
#
# usage: run_alive2.sh <cell-dir> [manifest] [expected: green|red]
set -euo pipefail
CELL_DIR="$1"
MANIFEST="${2:-$CELL_DIR/manifest.txt}"
EXPECT="${3:-green}"
T="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$T/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="${X_BUILD:-$CELL_DIR/build}"
OUT="${X_OUT:-$CELL_DIR/alive2}"
RUNSH="${X_RUNSH:-$OUT/run.sh}"
mkdir -p "$OUT"
"$T/build_leaf.sh" "$CELL_DIR" "$MANIFEST"
mapfile -t FNS < <(awk 'NF && $1 !~ /^#/ {print $1}' "$MANIFEST")
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: ${CELL_DIR#"$CELLS"/}"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# expected: $EXPECT"
  for fn in "${FNS[@]}"; do
    echo "# command: alive-tv build/c_${fn}.ll build/l_${fn}.ll"
    fnout="$(/usr/local/bin/alive-tv "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if [ "$EXPECT" = green ]; then
      if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
         || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
         || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
         || printf '%s' "$fnout" | grep -q "ERROR:"; then
        OK=0
      fi
    else
      # red run: a counterexample is the expected observation
      if ! printf '%s' "$fnout" | grep -q "Transformation doesn't verify"; then
        OK=0
      fi
    fi
  done
} > "$RES" 2>&1
if [ "$OK" -eq 1 ]; then
  if [ "$EXPECT" = green ]; then
    echo "STATUS=alive2-green" >> "$RES"
  else
    echo "STATUS=alive2-counterexample-as-expected" >> "$RES"
  fi
  STATUS=0
else
  echo "STATUS=alive2-unexpected" >> "$RES"
  STATUS=1
fi
FILES=(
  "$CELL_DIR/spec.md" "$RUNSH" "$MANIFEST"
  "$T/x_common.h" "$T/c_cell.cpp" "$T/l_cell.cpp" "$T/build_leaf.sh"
  "$BUILD/c_leaf.ll" "$BUILD/l_leaf.ll" "$RES"
)
for fn in "${FNS[@]}"; do
  FILES+=("$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll")
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
exit "$STATUS"
