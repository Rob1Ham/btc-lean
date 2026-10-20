#!/usr/bin/env bash
# Alive2 attempt for C-L-taproot-annex.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL/../../../../.." && pwd)"
BUILD="$CELL/build"; OUT="$CELL/alive2"
FNS=(cell_annex_detected cell_annex_remaining)
mkdir -p "$OUT"
"$CELL/build.sh"
RES="$OUT/result.txt"
{
  echo "# cell: tapscript/C-L-taproot-annex"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# command: alive-tv --bidirectional build/c_<fn>.ll build/l_<fn>.ll"
  echo
} > "$RES"
ALL_OK=1
for FN in "${FNS[@]}"; do
  TMP="$OUT/.${FN}.tmp"
  {
    echo "===== $FN ====="
    echo "# c IR sha256: $(sha256sum "$BUILD/c_${FN}.ll" | cut -d' ' -f1)"
    echo "# l IR sha256: $(sha256sum "$BUILD/l_${FN}.ll" | cut -d' ' -f1)"
    /usr/local/bin/alive-tv --bidirectional "$BUILD/c_${FN}.ll" \
      "$BUILD/l_${FN}.ll" || true
    echo
  } > "$TMP" 2>&1
  cat "$TMP" >> "$RES"
  if grep -q 'Transformation seems to be correct!' "$TMP" \
     && ! grep -q "Transformation doesn't verify" "$TMP" \
     && ! grep -q 'ERROR:' "$TMP"; then
    echo "STATUS_${FN}=alive2-green" >> "$RES"
  else
    echo "STATUS_${FN}=alive2-not-green" >> "$RES"; ALL_OK=0
  fi
  rm -f "$TMP"
done
if [ "$ALL_OK" -eq 1 ]; then
  echo 'STATUS=alive2-green' >> "$RES"; STATUS=0
else
  echo 'STATUS=alive2-not-green' >> "$RES"; STATUS=1
fi
FILES=("$CELL/spec.md" "$CELL/notes.md" "$CELL/build.sh"
       "$CELL/cell_common.h" "$CELL/c_leg.cpp" "$CELL/l_leg.cpp"
       "$CELL/alive2/run.sh" "$RES")
for FN in "${FNS[@]}"; do FILES+=("$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll"); done
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}" 2>/dev/null || true; done
} > "$OUT/certificate.sha256"
exit "$STATUS"
