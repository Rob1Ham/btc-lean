#!/usr/bin/env bash
# Alive2 attempt for one bounded stack-ops cell.
#   run_alive2.sh CELL_DIR CELL_ID OPS MAX_DEPTH MAX_ELEM [SMT_TIMEOUT_MS] [OPT] [BUILD_NAME]
# Every function in $CELL_DIR/src/fns.txt is compared C-vs-L.  Green requires
# "Transformation seems to be correct! / 1 correct transformations" and no
# "doesn't verify" / "ERROR:" for every function.
set -euo pipefail
CELL_DIR="$1"; CELL_ID="$2"; OPS="$3"; MAXD="$4"; MAXE="$5"
# Optional per-query SMT timeout (ms).  Cells with wide packed observables need
# more than the alive-tv default of 10s per query.
SMT_TO="${6:-10000}"
OPT="${7:-O1}"
BUILD_NAME="${8:-build}"
H="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$H/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/$BUILD_NAME"
OUT="$CELL_DIR/alive2"
mkdir -p "$OUT"
"$H/build.sh" "$CELL_DIR" "$OPS" "$MAXD" "$MAXE" "$OPT" "$BUILD_NAME"
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
  while IFS= read -r fn; do
    [ -n "$fn" ] || continue
    echo "# command: alive-tv --smt-to=${SMT_TO} build/c_${fn}.ll build/l_${fn}.ll"
    fnout="$(/usr/local/bin/alive-tv --smt-to="$SMT_TO" "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
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
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh" "$CELL_DIR/src/build.sh"
  "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp" "$CELL_DIR/src/fns.txt"
  "$H/build.sh" "$H/extract_extras.py" "$H/leaf_common.h"
  "$H/run_alive2.sh" "$H/run_saw.sh"
  "$CELLS/_tools/mk_leaf.py"
  "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py" "$EQ/twin/runtime.inc"
  "$EQ/contract/error_kind.h"
  "$BUILD/twin_ops.h" "$BUILD/twin_extras.h" "$BUILD/build.txt" "$RES"
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
