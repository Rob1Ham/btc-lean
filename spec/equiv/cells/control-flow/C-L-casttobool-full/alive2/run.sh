#!/usr/bin/env bash
# Alive2 for control-flow/C-L-casttobool-full.
#
# Compares the verbatim Core loop (C) with the verbatim twin loop (L) at a
# symbolic 32-bit length constrained to n <= 520.  Alive2 reasons about the
# loop directly (no per-length specialisation and no unrolling factor).
# alive-tv exits 0 even on a counterexample, so the raw report is parsed.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CELLS="$(cd "$CELL_DIR/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
FN=cell_cast_arb
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh" "$CELL_DIR"

if ! grep -q '^loop_present_c=1$' "$BUILD/build.txt" \
   || ! grep -q '^loop_present_l=1$' "$BUILD/build.txt"; then
  echo "# FATAL: a loop was optimised away; symbolic-length claim invalid" >&2
  exit 1
fi

RES="$OUT/result.txt"
{
  echo "# cell: control-flow/C-L-casttobool-full"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# domain: symbolic n, n <= 520 (MAX_SCRIPT_ELEMENT_SIZE)"
  echo "# build: build/build.txt"
  echo "# command: alive-tv --bidirectional --smt-to=60000 build/c_${FN}.ll build/l_${FN}.ll"
  /usr/local/bin/alive-tv --bidirectional --smt-to=60000 \
    "$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll" 2>&1 || true
} > "$RES" 2>&1

OK=1
if ! grep -q "Transformation seems to be correct" "$RES"; then OK=0; fi
if ! grep -q "These functions seem to be equivalent" "$RES"; then OK=0; fi
if ! grep -q "1 correct transformations" "$RES"; then OK=0; fi
if grep -q "Transformation doesn't verify" "$RES"; then OK=0; fi
if grep -q "ERROR:" "$RES"; then OK=0; fi
if [ "$OK" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
  STATUS=0
else
  echo "STATUS=alive2-not-green" >> "$RES"
  STATUS=1
fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/alive2/run.sh"
  "$CELL_DIR/src/build.sh" "$CELL_DIR/src/cell.h"
  "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$CELL_DIR/src/extract_twin.py"
  "$EQ/twin/runtime.inc" "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py"
  "$EQ/contract/error_kind.h"
  "$BUILD/twin_cast_to_bool.h" "$BUILD/build.txt"
  "$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll"
  "$BUILD/c_${FN}.bc" "$BUILD/l_${FN}.bc"
  "$RES"
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
