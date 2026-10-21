#!/usr/bin/env bash
# Alive2 attempt for C-L-taproot-gate.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CELL/../../../../.." && pwd)"
BUILD="$CELL/build"; OUT="$CELL/alive2"
mkdir -p "$OUT"
"$CELL/build.sh"
RES="$OUT/result.txt"
{
  echo "# cell: tapscript/C-L-taproot-gate"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# command: alive-tv --bidirectional build/c_cell_taproot_gate.ll build/l_cell_taproot_gate.ll"
  echo
  echo "===== cell_taproot_gate ====="
  echo "# c IR sha256: $(sha256sum "$BUILD/c_cell_taproot_gate.ll" | cut -d' ' -f1)"
  echo "# l IR sha256: $(sha256sum "$BUILD/l_cell_taproot_gate.ll" | cut -d' ' -f1)"
  /usr/local/bin/alive-tv --bidirectional "$BUILD/c_cell_taproot_gate.ll" \
    "$BUILD/l_cell_taproot_gate.ll" || true
} > "$RES" 2>&1
if grep -q 'Transformation seems to be correct!' "$RES" \
   && ! grep -q "Transformation doesn't verify" "$RES" \
   && ! grep -q 'ERROR:' "$RES"; then
  echo 'STATUS=alive2-green' >> "$RES"; STATUS=0
else
  echo 'STATUS=alive2-not-green' >> "$RES"; STATUS=1
fi
FILES=("$CELL/spec.md" "$CELL/notes.md" "$CELL/build.sh"
       "$CELL/cell_common.h" "$CELL/c_leg.cpp" "$CELL/l_leg.cpp"
       "$CELL/alive2/run.sh"
       "$BUILD/c_cell_taproot_gate.ll" "$BUILD/l_cell_taproot_gate.ll"
       "$RES")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do sha256sum "${f#"$ROOT"/}" 2>/dev/null || true; done
} > "$OUT/certificate.sha256"
exit "$STATUS"
