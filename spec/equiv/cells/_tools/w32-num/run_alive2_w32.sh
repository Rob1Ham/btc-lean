#!/usr/bin/env bash
# Alive2 runner for wave-32 numeric cells.  Runs the refinement check in BOTH
# directions (alive-tv --bidirectional), so L ⊑ C and C ⊑ L are each a real
# tool result.
# Usage: run_alive2_w32.sh CELL_DIR CELL_ID FN [FN...]
set -euo pipefail
CELL_DIR="$1"; shift
CELL_ID="$1"; shift
FNS=("$@")
W32="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$W32/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh" "$CELL_DIR"
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: $CELL_ID"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  if [ -f "$BUILD/twin_ops.h" ]; then
    echo "# twin_ops source: build/twin_ops.h sha256 $(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  fi
  echo "# build: build/build.txt"
  for fn in "${FNS[@]}"; do
    echo "# command: alive-tv --bidirectional build/c_${fn}.ll build/l_${fn}.ll"
    fnout="$(/usr/local/bin/alive-tv --bidirectional "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    # --bidirectional checks L ⊑ C and C ⊑ L.  When both hold, alive-tv
    # reports "Transformation seems to be correct!" plus either
    # "These functions seem to be equivalent!" (one summary line) or two
    # correct transformations; either way there is exactly one "correct
    # transformations" figure per verified direction set and no failure.
    if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
       || ! printf '%s' "$fnout" | grep -Eq "[12] correct transformations" \
       || ! printf '%s' "$fnout" | grep -q "0 incorrect transformations" \
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
  "$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh" "$CELL_DIR/src/build.sh"
  "$CELL_DIR/src/ops.txt" "$CELL_DIR/src/fns.txt"
  "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$W32/w32_common.h" "$W32/w32_twin.h" "$W32/build_w32.sh"
  "$W32/run_alive2_w32.sh"
  "$W32/run_saw_w32.sh"
  "$CELLS/_tools/mk_leaf.py"
  "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py" "$EQ/contract/error_kind.h"
  "$BUILD/build.txt" "$RES"
)
[ -f "$BUILD/twin_ops.h" ] && FILES+=("$BUILD/twin_ops.h")
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
