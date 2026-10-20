#!/usr/bin/env bash
# Alive2 runner for the `limits` family cells.
#
#   run_alive2.sh CELL_DIR CELL_ID
#
# Builds both legs, then compares the extracted C and L modules for every
# function named in src/functions.txt.  Each comparison must report exactly one
# correct transformation with no incorrect / failed-to-prove / Alive2-error
# entries, and the extracted IR must be memory-free and closed (no alloca, no
# external declarations, no jump-table globals) so a green result is not a
# vacuous one.
set -euo pipefail

CELL_DIR="$(cd "$1" && pwd)"
CELL_ID="$2"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$TOOLS/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
ALIVE_TV="${ALIVE_TV:-/usr/local/bin/alive-tv}"

mkdir -p "$OUT"
"$CELL_DIR/src/build.sh" "$CELL_DIR"

RES="$OUT/result.txt"
{
  echo "# cell: $CELL_ID"
  echo "# alive-tv: $("$ALIVE_TV" --version 2>&1 | head -1)"
  echo "# build: build/build.txt"
  echo "# expected: per function, 1 correct, 0 incorrect, 0 failed-to-prove, 0 Alive2 errors"
  echo
} > "$RES"

GREEN=1
while IFS= read -r fn; do
  [ -z "$fn" ] && continue
  case "$fn" in \#*) continue ;; esac
  C="$BUILD/c_${fn}.ll"
  L="$BUILD/l_${fn}.ll"
  LOG="$OUT/.${fn}.log"

  {
    echo "## function $fn"
    echo "## IR guard: no alloca, no '= external', no switch.table"
  } >> "$RES"

  if grep -qE '\balloca\b' "$C" "$L"; then
    echo "GUARD-FAIL alloca in extracted IR" >> "$RES"
    GREEN=0
    continue
  fi
  if grep -q '= external' "$C" "$L"; then
    echo "GUARD-FAIL external declaration in extracted IR" >> "$RES"
    GREEN=0
    continue
  fi
  if grep -q 'switch\.table' "$C" "$L"; then
    echo "GUARD-FAIL jump-table global in extracted IR" >> "$RES"
    GREEN=0
    continue
  fi
  if grep -q 'llvm\.loop' "$C" "$L"; then
    echo "GUARD-FAIL residual loop in extracted IR (Alive2 can report a vacuous green)" >> "$RES"
    GREEN=0
    continue
  fi

  if "$ALIVE_TV" --always-verify --smt-to=60000 "$C" "$L" > "$LOG" 2>&1 \
     && grep -q 'Transformation seems to be correct!' "$LOG" \
     && grep -q '^  1 correct transformations' "$LOG" \
     && ! grep -qE '^  [1-9][0-9]* incorrect transformations' "$LOG" \
     && ! grep -qE '^  [1-9][0-9]* failed-to-prove transformations' "$LOG" \
     && ! grep -qE '^  [1-9][0-9]* Alive2 errors' "$LOG"; then
    cat "$LOG" >> "$RES"
    echo "STATUS=alive2-green function=$fn" >> "$RES"
  else
    cat "$LOG" >> "$RES"
    echo "STATUS=alive2-not-green function=$fn" >> "$RES"
    GREEN=0
  fi
  rm -f "$LOG"
  echo >> "$RES"
done < "$CELL_DIR/src/functions.txt"

if [ "$GREEN" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
else
  echo "STATUS=alive2-not-green" >> "$RES"
fi

# Certificate over tracked files only (never build artifacts: build/ is
# gitignored, so a certificate that named them could not be checked from a
# clean checkout).
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh" "$CELL_DIR/src/build.sh"
  "$CELL_DIR/src/c_leg.cpp" "$CELL_DIR/src/l_leg.cpp"
  "$CELL_DIR/src/functions.txt" "$CELL_DIR/src/cell.cry" "$CELL_DIR/src/cell.saw"
  "$TOOLS/limits_common.h" "$TOOLS/build_limits.sh"
  "$TOOLS/run_alive2.sh" "$TOOLS/run_saw.sh" "$RES"
)
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    if [ -f "$f" ]; then
      sha256sum "${f#"$ROOT"/}"
    else
      echo "MISSING $f" >&2
      exit 1
    fi
  done
} > "$OUT/certificate.sha256"

[ "$GREEN" -eq 1 ]
