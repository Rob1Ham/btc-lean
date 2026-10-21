#!/usr/bin/env bash
# Alive2 attempt for one wave-32 CHECKMULTISIG cell.
#
#   run_alive2.sh <cell_dir> <fns_csv> <cell_id> <c_src> <l_src> [checker]
#
# Both legs are compiled at -O2 (see build_cell.sh), then
# llvm-extract --recursive --keep-const-init isolates one cell function per
# lane and alive-tv compares them bidirectionally.  There
# is no unsafe-assume and no hand-written success marker: the STATUS line is
# derived from alive-tv's own verdict string only.
set -euo pipefail

CELL_DIR="$1"; FNS="$2"; ID="$3"; C_SRC="$4"; L_SRC="$5"; CHECKER="${6:-}"
if [ -z "${E32_CELL_LOCKED:-}" ]; then
  export E32_CELL_LOCKED=1
  exec flock "$CELL_DIR/.w32.lock" "$0" "$@"
fi
E3="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$E3/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"; OUT="$CELL_DIR/alive2"
LLVM=/usr/lib/llvm-20/bin
ALIVE_ARGS="${E32_ALIVE2_ARGS:---smt-to=600000}"
mkdir -p "$OUT"

"$E3/build_cell.sh" "$CELL_DIR" alive2 "$C_SRC" "$L_SRC" "$ID" "$CHECKER"

RES="$OUT/result.txt"
{
  echo "# cell: $ID"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# c_src: $C_SRC sha256 $(sha256sum "$E3/$C_SRC" | cut -d' ' -f1)"
  echo "# l_src: $L_SRC sha256 $(sha256sum "$E3/$L_SRC" | cut -d' ' -f1)"
  echo "# twin_ops sha256: $(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  echo "# c_leaf sha256: $(sha256sum "$BUILD/c_leaf.ll" | cut -d' ' -f1)"
  echo "# l_leaf sha256: $(sha256sum "$BUILD/l_leaf.ll" | cut -d' ' -f1)"
  echo
} > "$RES"

ALL_OK=1
IFS=',' read -r -a ARR <<< "$FNS"
for FN in "${ARR[@]}"; do
  # --keep-const-init is required: llvm-extract otherwise demotes the
  # function-local `static const` half-order table used by the low-S check to
  # an external declaration.  Alive2 then treats every load from it as
  # unconstrained/poison and reports a spurious counterexample.  Measured on
  # wave-32: without this flag the loop cell reports "doesn't verify" for
  # LOW_S inputs; with it the same pair is green.
  "$LLVM/llvm-extract" --func="$FN" --recursive --keep-const-init \
    "$BUILD/c_leaf.ll" -o "$BUILD/c_${FN}.bc"
  "$LLVM/llvm-extract" --func="$FN" --recursive --keep-const-init \
    "$BUILD/l_leaf.ll" -o "$BUILD/l_${FN}.bc"
  "$LLVM/llvm-dis" "$BUILD/c_${FN}.bc" -o "$BUILD/c_${FN}.ll"
  "$LLVM/llvm-dis" "$BUILD/l_${FN}.bc" -o "$BUILD/l_${FN}.ll"
  TMP="$OUT/.${FN}.tmp"
  {
    echo "# command: /usr/local/bin/alive-tv --bidirectional $ALIVE_ARGS build/c_${FN}.ll build/l_${FN}.ll"
    echo "# c IR sha256: $(sha256sum "$BUILD/c_${FN}.ll" | cut -d' ' -f1)"
    echo "# l IR sha256: $(sha256sum "$BUILD/l_${FN}.ll" | cut -d' ' -f1)"
    # shellcheck disable=SC2086
    /usr/local/bin/alive-tv --bidirectional $ALIVE_ARGS "$BUILD/c_${FN}.ll" \
      "$BUILD/l_${FN}.ll" || true
  } > "$TMP" 2>&1
  {
    echo "===== $FN ====="
    cat "$TMP"
    echo
  } >> "$RES"
  if grep -q "Transformation seems to be correct!" "$TMP" \
     && ! grep -q "doesn't verify" "$TMP"; then
    echo "STATUS_${FN}=alive2-green" >> "$RES"
  else
    echo "STATUS_${FN}=alive2-not-green" >> "$RES"
    ALL_OK=0
  fi
  rm -f "$TMP"
done

if [ "$ALL_OK" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
else
  echo "STATUS=alive2-not-green" >> "$RES"
fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh"
  "$CELLS/_tools/mk_leaf.py" "$E3/build_cell.sh" "$E3/e32_common.h"
  "$E3/$C_SRC" "$E3/$L_SRC" "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py"
  "$EQ/contract/error_kind.h" "$BUILD/twin_ops.h" "$RES"
)
for FN in "${ARR[@]}"; do
  FILES+=("$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll")
done
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" 2>/dev/null || true ;;
      *) echo "# outside-root $(sha256sum "$f" 2>/dev/null || echo missing)" ;;
    esac
  done
} > "$OUT/certificate.sha256"

[ "$ALL_OK" -eq 1 ]
