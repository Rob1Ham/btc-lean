#!/usr/bin/env bash
# Alive2 attempt for one E3 cell.  Both legs declare the same external checker
# symbol and are compared at -O1 with llvm-extract --recursive, one closed
# witness function at a time, bidirectionally.
set -euo pipefail

CELL_DIR="$1"; FNS="$2"; ID="$3"; KEY="$4"
# Serialize runs for one cell: a concurrent verifier re-running the cell while
# the author runs it must not interleave writes to result.txt/build/.
if [ -z "${E3_CELL_LOCKED:-}" ]; then
  export E3_CELL_LOCKED=1
  exec flock "$CELL_DIR/.e3.lock" "$0" "$@"
fi
E3="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$E3/../../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"; OUT="$CELL_DIR/alive2"
LLVM=/usr/lib/llvm-20/bin
mkdir -p "$OUT"

"$E3/build_cell.sh" "$CELL_DIR" alive2 "$KEY" "$ID"

RES="$OUT/result.txt"
{
  echo "# cell: $ID"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# checker: external declaration @btc_equiv_check_sig (same symbol both legs)"
  echo "# checker return annotated noundef (C bool return; same-crypto premise)"
  echo "# twin_ops sha256: $(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  echo "# c_leaf sha256: $(sha256sum "$BUILD/c_leaf.ll" | cut -d' ' -f1)"
  echo "# l_leaf sha256: $(sha256sum "$BUILD/l_leaf.ll" | cut -d' ' -f1)"
  echo
} > "$RES"

ALL_OK=1
IFS=',' read -r -a ARR <<< "$FNS"
for FN in "${ARR[@]}"; do
  "$LLVM/llvm-extract" --func="$FN" --recursive "$BUILD/c_leaf.ll" \
    -o "$BUILD/c_${FN}.bc"
  "$LLVM/llvm-extract" --func="$FN" --recursive "$BUILD/l_leaf.ll" \
    -o "$BUILD/l_${FN}.bc"
  "$LLVM/llvm-dis" "$BUILD/c_${FN}.bc" -o "$BUILD/c_${FN}.ll"
  "$LLVM/llvm-dis" "$BUILD/l_${FN}.bc" -o "$BUILD/l_${FN}.ll"
  # Harness ABI annotation (same-crypto premise): the abstract checker is a C
  # bool-returning function, so its return value is defined, never poison.
  # Alive2's uninterpreted-call model otherwise admits a poison return, which
  # would make any *branch* on the verdict UB while a branchless select (as
  # clang emits for the C leg) would not be.  This is a property of the seam,
  # not of either engine.
  sed -i 's/declare zeroext i8 @btc_equiv_check_sig/declare noundef zeroext i8 @btc_equiv_check_sig/' \
    "$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll"
  TMP="$OUT/.${FN}.tmp"
  {
    echo "# command: /usr/local/bin/alive-tv --bidirectional build/c_${FN}.ll build/l_${FN}.ll"
    echo "# c IR sha256: $(sha256sum "$BUILD/c_${FN}.ll" | cut -d' ' -f1)"
    echo "# l IR sha256: $(sha256sum "$BUILD/l_${FN}.ll" | cut -d' ' -f1)"
    /usr/local/bin/alive-tv --bidirectional "$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll" || true
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
  "$CELLS/_tools/mk_leaf.py" "$E3/build_cell.sh" "$E3/e3_common.h"
  "$E3/checker_abi.h" "$E3/c_checksig.cpp" "$E3/l_checksig.cpp"
  "$E3/c_cms.cpp" "$E3/l_cms.cpp" "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py"
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
