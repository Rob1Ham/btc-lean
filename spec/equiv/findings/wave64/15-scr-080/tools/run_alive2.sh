#!/usr/bin/env bash
# Alive2 runner for the wave-64 SCR-080 cell.
#
#   run_alive2.sh CELL_DIR CELL_ID FN [FN...]
#
# Builds both legs (src/build.sh), then for every entry point runs
#   alive-tv --bidirectional build/c_<fn>.ll build/l_<fn>.ll
# and requires, for each direction, "Transformation seems to be correct" and
# "1 correct transformations", with no "Transformation doesn't verify" and no
# "ERROR:".  --bidirectional is what makes the cell a two-direction result
# (L <= C and C <= L); a one-direction run is recorded as not-green here.
set -euo pipefail
CELL_DIR="$(cd "$1" && pwd)"; shift
CELL_ID="$1"; shift
FNS=("$@")
TOOLS="$(cd "$(dirname "$0")" && pwd)"
EQ="$(cd "$TOOLS/../../../.." && pwd)"
REPO="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
ALIVE="${ALIVE:-/opt/equiv-tools/alive-tv-v20.0}"
[ -x "$ALIVE" ] || ALIVE=/usr/local/bin/alive-tv
SMT_TO="${SMT_TO:-120000}"
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh" "$CELL_DIR"

RES="$OUT/result.txt"
OK=1
{
  echo "# cell: $CELL_ID"
  echo "# alive-tv: $("$ALIVE" --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# mode: --bidirectional (C -> L and L -> C)"
  echo "# twin_ops.h sha256 $(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  echo "# build: build/build.txt"
  echo "# alive-tv flags: --bidirectional --smt-to=$SMT_TO"
  for fn in "${FNS[@]}"; do
    echo
    echo "# command: alive-tv --bidirectional --smt-to=$SMT_TO build/c_${fn}.ll build/l_${fn}.ll"
    echo "# c_${fn}.ll sha256 $(sha256sum "$BUILD/c_${fn}.ll" | cut -d' ' -f1)"
    echo "# l_${fn}.ll sha256 $(sha256sum "$BUILD/l_${fn}.ll" | cut -d' ' -f1)"
    fnout="$("$ALIVE" --bidirectional --smt-to="$SMT_TO" \
             "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if ! printf '%s' "$fnout" | grep -q "These functions seem to be equivalent" \
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
{
  cd "$REPO"
  for p in "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/alive2/run.sh" \
           "$CELL_DIR/src" "$TOOLS" "$EQ/contract/error_kind.h" \
           "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py" "$EQ/twin/runtime.inc" \
           "$EQ/cells/_tools/mk_leaf.py" "$EQ/findings/wave16/07-numeric-ops/tools/mk_num_leaf.py" \
           "$RES"; do
    rp="$(realpath --relative-to="$REPO" "$p")"
    if [ -d "$rp" ]; then
      find "$rp" -type f -print0 | sort -z | xargs -0 -r sha256sum
    else
      sha256sum "$rp"
    fi
  done
} > "$OUT/certificate.sha256"
exit "$STATUS"
