#!/usr/bin/env bash
# Alive2 leg for numeric/C-L-scriptnum-sign (SCR-082).
#
#   alive2/run.sh
#
# Builds both bounded leaves from src/ (the wave-16 numeric build: same
# clang-20 / llvm-extract / opt pipeline applied identically to both legs),
# then runs Alive2 in BOTH refinement directions for every entry point:
#
#   alive-tv build/c_<fn>.ll build/l_<fn>.ll   (L refines C)
#   alive-tv build/l_<fn>.ll build/c_<fn>.ll   (C refines L)
#
# Each direction is required to report exactly one correct transformation and
# no error.  The raw output of both directions is recorded in result.txt.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
ALIVE="${ALIVE:-/opt/equiv-tools/alive-tv-v20.0}"
[ -x "$ALIVE" ] || ALIVE=/usr/local/bin/alive-tv
SMT_TO="${SMT_TO:-180000}"
FNS=(cell_decode cell_encode cell_encode_decode cell_roundtrip)
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh" "$CELL_DIR"

RES="$OUT/result.txt"
OK=1
{
  echo "# cell: numeric/C-L-scriptnum-sign"
  echo "# rows: SCR-082 (sign bit on top byte; negative zero exists)"
  echo "# alive-tv: $("$ALIVE" --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# twin_ops.h sha256 $(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  echo "# build: build/build.txt"
  echo "# alive-tv flags: --smt-to=$SMT_TO"
  echo "# directions: c->l (L refines C) and l->c (C refines L) for each entry"
  for fn in "${FNS[@]}"; do
    for pair in "c l" "l c"; do
      set -- $pair
      src="$1"; tgt="$2"
      echo
      echo "# command: alive-tv --smt-to=$SMT_TO build/${src}_${fn}.ll build/${tgt}_${fn}.ll"
      fnout="$("$ALIVE" --smt-to="$SMT_TO" "$BUILD/${src}_${fn}.ll" "$BUILD/${tgt}_${fn}.ll" 2>&1 || true)"
      printf '%s\n' "$fnout"
      if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
         || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
         || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
         || printf '%s' "$fnout" | grep -q "ERROR:"; then
        OK=0
        echo "# FAILED: $fn ($src -> $tgt)"
      fi
    done
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
source "$EQ/findings/wave16/07-numeric-ops/tools/certify.sh"
certify "$OUT/certificate.sha256" \
  "$CELL_DIR/spec.md" \
  "$CELL_DIR/notes.md" \
  "$CELL_DIR/src" \
  "$CELL_DIR/alive2/run.sh" \
  "$CELL_DIR/saw/run.sh" \
  "$EQ/findings/wave16/07-numeric-ops/tools/mk_num_leaf.py" \
  "$EQ/findings/wave16/07-numeric-ops/tools/num_common.h" \
  "$EQ/findings/wave16/07-numeric-ops/tools/num_core.h" \
  "$EQ/cells/_tools/mk_leaf.py" \
  "$EQ/twin/ops_ir.py" \
  "$EQ/twin/gen.py" \
  "$EQ/twin/runtime.inc" \
  "$EQ/contract/error_kind.h" \
  "$EQ/../core/Bitcoin/Numeric/ScriptNum.lean" \
  "$EQ/../core/Bitcoin/Numeric/Interface.lean" \
  "$RES"
exit "$STATUS"
