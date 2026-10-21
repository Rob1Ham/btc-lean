#!/usr/bin/env bash
# Alive2 attempt for C-L-taproot-keypath.  Both legs call the same external
# Schnorr checker symbol with the same arguments; Alive2 quantifies over its
# return value (same-crypto premise).  Bidirectional.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL/../../../../.." && pwd)"
BUILD="$CELL/build"; OUT="$CELL/alive2"
mkdir -p "$OUT"
"$CELL/build.sh"
RES="$OUT/result.txt"
{
  echo "# cell: tapscript/C-L-taproot-keypath"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# checker: external declaration @btc_equiv_check_schnorr (same symbol both legs)"
  echo "# checker return annotated noundef (C uint32_t return; same-crypto premise)"
  echo "# command: alive-tv --bidirectional build/c_cell_keypath.ll build/l_cell_keypath.ll"
  echo
} > "$RES"
TMP="$OUT/.cell_keypath.tmp"
{
  echo "===== cell_keypath ====="
  echo "# c IR sha256: $(sha256sum "$BUILD/c_cell_keypath.ll" | cut -d' ' -f1)"
  echo "# l IR sha256: $(sha256sum "$BUILD/l_cell_keypath.ll" | cut -d' ' -f1)"
  /usr/local/bin/alive-tv --bidirectional "$BUILD/c_cell_keypath.ll" \
    "$BUILD/l_cell_keypath.ll" || true
  echo
} > "$TMP" 2>&1
cat "$TMP" >> "$RES"
if grep -q 'Transformation seems to be correct!' "$TMP" \
   && ! grep -q "Transformation doesn't verify" "$TMP" \
   && ! grep -q 'ERROR:' "$TMP"; then
  echo 'STATUS_cell_keypath=alive2-green' >> "$RES"; STATUS=0
else
  echo 'STATUS_cell_keypath=alive2-not-green' >> "$RES"; STATUS=1
fi
echo "STATUS=$([ "$STATUS" -eq 0 ] && echo alive2-green || echo alive2-not-green)" >> "$RES"
rm -f "$TMP"

FILES=("$CELL/spec.md" "$CELL/notes.md" "$CELL/build.sh"
       "$CELL/cell_common.h" "$CELL/checker_abi.h" "$CELL/checker_stub.cpp"
       "$CELL/c_leg.cpp" "$CELL/l_leg.cpp" "$CELL/alive2/run.sh"
       "$BUILD/c_cell_keypath.ll" "$BUILD/l_cell_keypath.ll" "$RES")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}" 2>/dev/null || true; done
} > "$OUT/certificate.sha256"
exit "$STATUS"
