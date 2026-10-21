#!/usr/bin/env bash
# Alive2 runner for the wave-16 numeric cells.
#
#   run_alive2.sh CELL_DIR CELL_ID FN [FN...]
#
# Builds both legs (src/build.sh), then for every entry point runs
# `alive-tv build/c_<fn>.ll build/l_<fn>.ll` and requires
#   "Transformation seems to be correct!" + "1 correct transformations"
# with no "Transformation doesn't verify" and no "ERROR:".
set -euo pipefail
CELL_DIR="$(cd "$1" && pwd)"; shift
CELL_ID="$1"; shift
FNS=("$@")
TOOLS="$(cd "$(dirname "$0")" && pwd)"
EQ="$(cd "$TOOLS/../../../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
ALIVE="${ALIVE:-/opt/equiv-tools/alive-tv-v20.0}"
[ -x "$ALIVE" ] || ALIVE=/usr/local/bin/alive-tv
# Alive2's default SMT timeout is 10 s; the packed 55-bit observable needs a
# little more on the arithmetic rows (OP_1ADD/OP_1SUB) while still proving in
# ~15 s wall clock.  Recorded in the result header.
SMT_TO="${SMT_TO:-120000}"
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh" "$CELL_DIR"

RES="$OUT/result.txt"
OK=1
{
  echo "# cell: $CELL_ID"
  echo "# alive-tv: $("$ALIVE" --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# twin_ops.h sha256 $(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  echo "# build: build/build.txt"
  echo "# alive-tv flags: --smt-to=$SMT_TO"
  for fn in "${FNS[@]}"; do
    echo
    echo "# command: alive-tv --smt-to=$SMT_TO build/c_${fn}.ll build/l_${fn}.ll"
    fnout="$("$ALIVE" --smt-to="$SMT_TO" "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
       || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
       || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
       || printf '%s' "$fnout" | grep -q "ERROR:"; then
      OK=0
      echo "# FAILED: $fn"
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
# shellcheck disable=SC1091
source "$TOOLS/certify.sh"
cell_certify "$CELL_DIR" "$OUT/certificate.sha256" "$RES" "$BUILD" "$TOOLS" "$EQ"
exit "$STATUS"
