#!/usr/bin/env bash
# Alive2 runner for push-encoding/C-L-w66-minimaldata-arbitrary-num.
#
# Same contract as cells/_tools/w32-push/run_alive2.sh, with two differences:
#   * the per-query SMT timeout is 900 s (the shared runner uses 60 s);
#   * every function is compared with --bidirectional.
#
# The predicate functions carry a FULL 32-bit operand length and an
# independent canonical re-encoding (variable shifts over a length that the
# width guard bounds at 5), and cell_cms decodes two independent operands with
# a 16-bit opcode budget; those queries exceed the shared bound on a loaded
# host.  Only the resource bound changes, not the query.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
W32="$(cd "$CELL_DIR/../../_tools/w32-push" && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
mkdir -p "$OUT"
"$W32/build.sh" "$CELL_DIR"
FNS="$(grep -v '^[[:space:]]*#' "$CELL_DIR/src/fns.txt" | sed '/^[[:space:]]*$/d')"
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: push-encoding/C-L-w66-minimaldata-arbitrary-num"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# smt-timeout-ms: 900000 (shared runner uses 60000)"
  echo "# build: build/build.txt"
  for fn in $FNS; do
    echo "# command: alive-tv --bidirectional --smt-to=900000 build/c_${fn}.ll build/l_${fn}.ll"
    fnout="$(/usr/local/bin/alive-tv --bidirectional --smt-to=900000 "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
       || ! printf '%s' "$fnout" | grep -q "These functions seem to be equivalent" \
       || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
       || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
       || printf '%s' "$fnout" | grep -q "ERROR:"; then
      OK=0
    fi
  done
} > "$RES" 2>&1
if [ "$OK" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
else
  echo "STATUS=alive2-not-green" >> "$RES"
fi
"$W32/certify.sh" "$CELL_DIR" "$OUT/certificate.sha256" "$RES"
[ "$OK" -eq 1 ]
