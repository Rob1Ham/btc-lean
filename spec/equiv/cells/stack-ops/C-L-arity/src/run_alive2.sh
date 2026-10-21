#!/usr/bin/env bash
# Alive2 runner for the SCR-074 arity table.
#
# Same shape as the stack-ops family harness (cells/stack-ops/_harness/
# run_alive2.sh) with one addition: --tgt-unroll.  OP_2ROT's twin body has a
# four-iteration shift loop, and alive-tv's default unroll factor is 0, which
# makes the 2rot boundary query fail with "doesn't reach a return instruction"
# rather than a verdict.  Every other row is loop-free; the flag is harmless.
#
#   run_alive2.sh CELL_DIR CELL_ID OPS MAXD MAXE [SMT_TIMEOUT_MS] [OPT]
set -euo pipefail
CELL_DIR="$1"; CELL_ID="$2"; OPS="$3"; MAXD="$4"; MAXE="$5"
SMT_TO="${6:-30000}"
OPT="${7:-O1}"
H="$CELL_DIR/../_harness"
CELLS="$(cd "$H/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
UNROLL=16
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh"
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: $CELL_ID"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# twin_ops.h sha256 $(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  echo "# twin_extras.h sha256 $(sha256sum "$BUILD/twin_extras.h" | cut -d' ' -f1)"
  echo "# twin/runtime.inc sha256 $(sha256sum "$EQ/twin/runtime.inc" | cut -d' ' -f1)"
  echo "# twin/ops_ir.py sha256 $(sha256sum "$EQ/twin/ops_ir.py" | cut -d' ' -f1)"
  echo "# flags: --smt-to=${SMT_TO} --src-unroll=${UNROLL} --tgt-unroll=${UNROLL}"
  while IFS= read -r fn; do
    [ -n "$fn" ] || continue
    echo "# command: alive-tv --smt-to=${SMT_TO} --src-unroll=${UNROLL} --tgt-unroll=${UNROLL} build/c_${fn}.ll build/l_${fn}.ll"
    fnout="$(/usr/local/bin/alive-tv --smt-to="$SMT_TO" --src-unroll="$UNROLL" \
             --tgt-unroll="$UNROLL" "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
       || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
       || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
       || printf '%s' "$fnout" | grep -q "ERROR:"; then
      OK=0
    fi
  done < "$CELL_DIR/src/fns.txt"
} > "$RES" 2>&1
if [ "$OK" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"; STATUS=0
else
  echo "STATUS=alive2-not-green" >> "$RES"; STATUS=1
fi
python3 "$CELL_DIR/src/normalize_cert.py" "$CELL_DIR" "$OUT/certificate.sha256"
exit "$STATUS"
