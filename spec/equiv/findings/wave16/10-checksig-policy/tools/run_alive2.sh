#!/usr/bin/env bash
# Alive2 lane for one wave-16 CHECKSIG cell.
#
#   run_alive2.sh <cell_dir> <fn1,fn2,...> <cell_id> <key>
#
# Both legs are compiled at -O1 from the same cell key, one closed function is
# extracted at a time with llvm-extract --recursive, and alive-tv compares C
# (source) with L (target) bidirectionally.  Cells that call the shared
# checker keep it as a bare declaration in BOTH modules: Alive2 then reasons
# over "same symbol, same arguments, arbitrary verdict" (the same-crypto
# premise of docs/DECISION-lax-ecdsa.md).  Its return is annotated noundef
# because a C `bool` return is never poison.
set -euo pipefail

CELL_DIR="$1"; FNS="$2"; ID="$3"; KEY="$4"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$TOOLS" && while [ ! -f spec/equiv/contract/error_kind.h ]; do cd ..; done; pwd)"
BUILD="$CELL_DIR/build"; OUT="$CELL_DIR/alive2"
LLVM=/usr/lib/llvm-20/bin
mkdir -p "$OUT"

"$TOOLS/build.sh" "$CELL_DIR" alive2 "$KEY"

RES="$OUT/result.txt"
{
  echo "# cell: $ID"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# c source sha256: $(sha256sum "$TOOLS/c_${KEY}.cpp" | cut -d' ' -f1)"
  echo "# l source sha256: $(sha256sum "$TOOLS/l_${KEY}.cpp" | cut -d' ' -f1)"
  echo "# cell harness sha256: $(sha256sum "$TOOLS/cell_common.h" | cut -d' ' -f1)"
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
  # Alive2 v20 refuses modules carrying attached TBAA/alias.scope metadata in
  # this shape ("ERROR: Unsupported metadata: N").  Those nodes are optimizer
  # hints with no semantic content, so the harness strips them from both legs
  # identically before comparison.  This is a tool-ingestion transform, not a
  # semantics change; it is recorded in each cell's notes.md.
  for f in "$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll"; do
    perl -0pi -e 's/,\s*!(tbaa|tbaa\.struct|alias\.scope|noalias|nonnull)(\s+![0-9]+)+//g' "$f"
  done
  if grep -q '@btc_equiv_' "$BUILD/c_${FN}.ll"; then
    sed -i -E 's/declare (zeroext )?i8 @btc_equiv_/declare noundef \1i8 @btc_equiv_/' \
      "$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll"
  fi
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
  "$TOOLS/cell_common.h" "$TOOLS/c_${KEY}.cpp" "$TOOLS/l_${KEY}.cpp"
  "$TOOLS/build.sh" "$TOOLS/run_alive2.sh"
  "$ROOT/spec/equiv/contract/error_kind.h" "$BUILD/build.txt" "$RES"
)
for FN in "${ARR[@]}"; do
  FILES+=("$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll")
done
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" 2>/dev/null || true ;;
      *) echo "# outside-root $f" ;;
    esac
  done
} > "$OUT/certificate.sha256"

[ "$ALL_OK" -eq 1 ]
