#!/usr/bin/env bash
# Alive2 lane for C-L-w32-pubkey-triage (SCR-158, SCR-159, SCR-160).
#
# Both legs declare the SAME external Schnorr symbol, so Alive2 quantifies
# over one shared checker verdict for each call (same-crypto premise).
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$CELL_DIR/src"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
ROOT="$(cd "$CELL_DIR/../../../../.." && pwd)"
LLVM=/usr/lib/llvm-20/bin
FNS=(cell_triage cell_triage_continue)
mkdir -p "$OUT"
"$SRC/build.sh" alive2

RES="$OUT/result.txt"
{
  echo "# cell: tapscript/C-L-w32-pubkey-triage"
  echo "# rows: SCR-158 (pubkey size 0/32/other triage), SCR-159 (TAPSCRIPT_EMPTY_PUBKEY after the weight decrement), SCR-160 (empty sig + x-only key: false, no checker call, no weight charged)"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# checker: external declaration @btc_equiv_check_schnorr (same symbol both legs)"
  echo "# checker return annotated noundef (C bool return; same-crypto premise)"
  echo "# c_leaf sha256: $(sha256sum "$BUILD/c_leaf.ll" | cut -d' ' -f1)"
  echo "# l_leaf sha256: $(sha256sum "$BUILD/l_leaf.ll" | cut -d' ' -f1)"
  echo
} > "$RES"

ALL_OK=1
for FN in "${FNS[@]}"; do
  "$LLVM/llvm-extract" --func="$FN" --recursive "$BUILD/c_leaf.ll" -o "$BUILD/c_${FN}.bc"
  "$LLVM/llvm-extract" --func="$FN" --recursive "$BUILD/l_leaf.ll" -o "$BUILD/l_${FN}.bc"
  "$LLVM/llvm-dis" "$BUILD/c_${FN}.bc" -o "$BUILD/c_${FN}.ll"
  "$LLVM/llvm-dis" "$BUILD/l_${FN}.bc" -o "$BUILD/l_${FN}.ll"
  sed -i 's/declare zeroext i8 @btc_equiv_check_schnorr/declare noundef zeroext i8 @btc_equiv_check_schnorr/' \
    "$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll"
  TMP="$OUT/.${FN}.tmp"
  {
    echo "# command: alive-tv --bidirectional build/c_${FN}.ll build/l_${FN}.ll"
    echo "# c IR sha256: $(sha256sum "$BUILD/c_${FN}.ll" | cut -d' ' -f1)"
    echo "# l IR sha256: $(sha256sum "$BUILD/l_${FN}.ll" | cut -d' ' -f1)"
    /usr/local/bin/alive-tv --bidirectional "$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll" || true
  } > "$TMP" 2>&1
  { echo "===== $FN ====="; cat "$TMP"; echo; } >> "$RES"
  if grep -q "Transformation seems to be correct!" "$TMP" \
     && ! grep -q "doesn't verify" "$TMP"; then
    echo "STATUS_${FN}=alive2-green" >> "$RES"
  else
    echo "STATUS_${FN}=alive2-not-green" >> "$RES"
    ALL_OK=0
  fi
  rm -f "$TMP"
done

if [ "$ALL_OK" -eq 1 ]; then echo "STATUS=alive2-green" >> "$RES"
else echo "STATUS=alive2-not-green" >> "$RES"; fi

FILES=("$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh" "$SRC/build.sh"
       "$SRC/tap_common.h" "$SRC/c_tap.cpp" "$SRC/l_tap.cpp" "$RES")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}"; done
} > "$OUT/certificate.sha256"

[ "$ALL_OK" -eq 1 ]
