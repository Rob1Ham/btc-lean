#!/usr/bin/env bash
# Alive2 attempt for one CHECKMULTISIG cell.
#
#   run_alive2.sh <cell_dir> <fn1,fn2,...>
#
# Both legs must declare the same external checker; Alive2's uninterpreted
# call model then quantifies over the checker's behaviour (same-crypto
# premise).  One closed/symbolic witness function at a time, bidirectional.
set -euo pipefail

CELL_DIR="$1"; FNS="$2"
SH="$(cd "$(dirname "$0")" && pwd)"
EQ="$(cd "$SH/../../.." && pwd)"       # spec/equiv
ROOT="$(cd "$EQ/../.." && pwd)"         # repo root
BUILD="$CELL_DIR/build"; OUT="$CELL_DIR/alive2"
LLVM=/usr/lib/llvm-20/bin
ALIVE=/opt/equiv-tools/alive-tv-v20.0
[ -x "$ALIVE" ] || ALIVE=/usr/local/bin/alive-tv
mkdir -p "$OUT"

"$SH/build_ir.sh" "$CELL_DIR" alive2

RES="$OUT/result.txt"
{
  echo "# cell: $(basename "$CELL_DIR")"
  echo "# alive-tv: $("$ALIVE" --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# checker: external declaration @btc_equiv_check_sig (same symbol both legs)"
  echo "# checker return annotated noundef (C bool return; same-crypto premise)"
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
  # bool-returning function, so its return is defined, never poison.  Alive2's
  # uninterpreted-call model otherwise admits a poison return, which would make
  # a *branch* on the verdict UB while a branchless select would not.
  sed -i 's/declare zeroext i8 @btc_equiv_check_sig/declare noundef zeroext i8 @btc_equiv_check_sig/' \
    "$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll"
  TMP="$OUT/.${FN}.tmp"
  {
    echo "# command: $ALIVE --bidirectional build/c_${FN}.ll build/l_${FN}.ll"
    echo "# c IR sha256: $(sha256sum "$BUILD/c_${FN}.ll" | cut -d' ' -f1)"
    echo "# l IR sha256: $(sha256sum "$BUILD/l_${FN}.ll" | cut -d' ' -f1)"
    "$ALIVE" --bidirectional "$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll" || true
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
  "$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh" "$CELL_DIR/notes.md"
  "$SH/cms_obs.h" "$SH/cms_seam.h" "$SH/build_ir.sh" "$SH/run_alive2.sh"
  "$CELL_DIR"/src/*.cpp "$EQ/contract/error_kind.h" "$RES"
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
