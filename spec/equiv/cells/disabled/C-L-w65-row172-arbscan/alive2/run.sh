#!/usr/bin/env bash
# Alive2 runner for disabled/C-L-w65-row172-arbscan (SCR-172).
#
# Two separate checks, deliberately in separate files:
#
#   result.txt     the bounded context pair `cell_flip`, compared in BOTH
#                  directions.  This is the green equivalence and the only
#                  file the cell gate parses.
#
#   divergence.txt the ordering function `cell_tail`, compared C -> L.  This is
#                  an EXPECTED counterexample: Core returns BAD_OPCODE (16) on a
#                  truncated tail before the stack/item-size checks, while Lean
#                  checks STACK_SIZE (8) / PUSH_SIZE (6) first.  Recording it
#                  as a counterexample is the point; it must never be counted
#                  as a green equivalence, so it is kept out of result.txt.
#
# Alive2's default SMT timeout (10 s) is too small for the eight-byte unroll;
# the explicit 300 s budget is what makes both flip directions prove.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CELL_ID="disabled/C-L-w65-row172-arbscan"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
ALIVE=/opt/equiv-tools/alive-tv-v20.0
SMT_TO=300000
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh"
RES="$OUT/result.txt"
DIV="$OUT/divergence.txt"
OK=1
{
  echo "# cell: $CELL_ID"
  echo "# alive-tv: $("$ALIVE" --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# smt-to: $SMT_TO ms"
  for pair in "c_cell_flip l_cell_flip C->L" "l_cell_flip c_cell_flip L->C"; do
    set -- $pair
    echo
    echo "# command: alive-tv --smt-to=$SMT_TO build/$1.ll build/$2.ll   ($3)"
    fnout="$("$ALIVE" --smt-to="$SMT_TO" "$BUILD/$1.ll" "$BUILD/$2.ll" 2>&1 || true)"
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

# Expected non-equivalence (NOT part of the green claim).
{
  echo "# cell: $CELL_ID"
  echo "# expected: 0 correct / 1 incorrect; source 16 (Core BAD_OPCODE),"
  echo "#           target 8 (Lean STACK_SIZE)"
  echo "# command: alive-tv --smt-to=$SMT_TO build/c_cell_tail.ll build/l_cell_tail.ll"
  echo "# witness: found=0 decode_fail=2 too_many=1"
  DIVOUT="$("$ALIVE" --smt-to="$SMT_TO" "$BUILD/c_cell_tail.ll" "$BUILD/l_cell_tail.ll" 2>&1 || true)"
  printf '%s\n' "$DIVOUT"
  if printf '%s' "$DIVOUT" | grep -q "1 incorrect transformations" \
     && printf '%s' "$DIVOUT" | grep -q "Source value: #x0000000000000010" \
     && printf '%s' "$DIVOUT" | grep -q "Target value: #x0000000000000008"; then
    echo "STATUS=expected-divergence-recorded"
  else
    echo "STATUS=divergence-shape-unexpected"
  fi
} > "$DIV" 2>&1

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/alive2/run.sh"
  "$CELL_DIR/src/build.sh" "$CELL_DIR/src/common.h"
  "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$CELL_DIR/src/cell.cry" "$CELL_DIR/src/cell.saw"
  "$EQ/contract/error_kind.h"
  "$EQ/../core/Bitcoin/Interpreter/Defs.lean"
  "$EQ/../core/Bitcoin/Script/Parser/Defs.lean"
  "$EQ/../core/Bitcoin/Script/Tapscript/Delta.lean"
  "$RES" "$DIV"
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
