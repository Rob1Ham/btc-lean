#!/usr/bin/env bash
# Alive2 attempt for a wave-32 witness-v0 cell.  Runs in both directions
# (tgt refines src, src refines tgt) so the recorded result is the mutual
# equality of the C and L functions, not a one-way refinement.
#
# Usage: run_alive2.sh <cell-dir> <function> [<function>...]
set -euo pipefail
CELL_DIR="$1"; shift
FNS=("$@")
E4W32="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$E4W32/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
CELL_ID="${CELL_DIR#"$CELLS"/}"
mkdir -p "$OUT"
"$E4W32/build_leaf.sh" "$CELL_DIR"
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: $CELL_ID"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# command: alive-tv --bidirectional build/c_<fn>.ll build/l_<fn>.ll"
  for fn in "${FNS[@]}"; do
    echo
    echo "===== $fn ====="
    fnout="$(/usr/local/bin/alive-tv --bidirectional --smt-to=120000 \
      "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    # --bidirectional prints "These functions seem to be equivalent!" and one
    # combined summary when both refinement directions hold.
    if ! printf '%s' "$fnout" | grep -Eq "Transformation seems to be correct|These functions seem to be equivalent" \
       || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
       || ! printf '%s' "$fnout" | grep -q "0 incorrect transformations" \
       || ! printf '%s' "$fnout" | grep -q "0 failed-to-prove transformations" \
       || ! printf '%s' "$fnout" | grep -q "0 Alive2 errors" \
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
FILES=("$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh"
       "$E4W32/w32_common.h" "$E4W32/c_cells.cpp" "$E4W32/l_cells.cpp"
       "$E4W32/build_leaf.sh" "$BUILD/build.txt" "$BUILD/c_leaf.ll"
       "$BUILD/l_leaf.ll")
for fn in "${FNS[@]}"; do
  FILES+=("$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll")
done
FILES+=("$RES")
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
