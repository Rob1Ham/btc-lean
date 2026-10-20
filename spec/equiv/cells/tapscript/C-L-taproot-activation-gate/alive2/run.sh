#!/usr/bin/env bash
# Alive2 attempt for C-L-taproot-activation-gate.
#
# Symbolic over every 256-bit block hash, every uint32 block height and every
# (version, program_len, is_p2sh, witness_n) tuple.  No closed inputs.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL/../../../../.." && pwd)"
BUILD="$CELL/build"; OUT="$CELL/alive2"
FN=cell_taproot_activation
mkdir -p "$OUT"
"$CELL/build.sh"
RES="$OUT/result.txt"
{
  echo "# cell: tapscript/C-L-taproot-activation-gate"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# command: alive-tv --bidirectional build/c_${FN}.ll build/l_${FN}.ll"
  echo
  echo "===== $FN ====="
  echo "# c IR sha256: $(sha256sum "$BUILD/c_${FN}.ll" | cut -d' ' -f1)"
  echo "# l IR sha256: $(sha256sum "$BUILD/l_${FN}.ll" | cut -d' ' -f1)"
  /usr/local/bin/alive-tv --bidirectional "$BUILD/c_${FN}.ll" \
    "$BUILD/l_${FN}.ll" || true
} > "$RES" 2>&1
if grep -q 'Transformation seems to be correct!' "$RES" \
   && grep -q 'These functions seem to be equivalent!' "$RES" \
   && ! grep -q "Transformation doesn't verify" "$RES" \
   && ! grep -q 'ERROR:' "$RES"; then
  echo 'STATUS=alive2-green' >> "$RES"; STATUS=0
else
  echo 'STATUS=alive2-not-green' >> "$RES"; STATUS=1
fi
FILES=("$CELL/spec.md" "$CELL/notes.md" "$CELL/GAP-CONTEXT.md"
       "$CELL/build.sh" "$CELL/cell_common.h"
       "$CELL/c_leg.cpp" "$CELL/l_leg.cpp"
       "$CELL/alive2/run.sh" "$RES")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}" 2>/dev/null || true; done
} > "$OUT/certificate.sha256"
exit "$STATUS"
