#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$1"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$TOOLS/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"; OUT="$CELL_DIR/alive2"
FNS=(cell_checksig_empty cell_checksigverify_empty)
mkdir -p "$OUT"
"$TOOLS/build_leaf.sh" "$CELL_DIR"
RES="$OUT/result.txt"; OK=1
{
  echo "# cell: checksig/C-L-checksig-empty"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  for fn in "${FNS[@]}"; do
    echo "# command: alive-tv build/c_${fn}.ll build/l_${fn}.ll"
    fnout="$(/usr/local/bin/alive-tv "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if ! printf '%s' "$fnout" | grep -q 'Transformation seems to be correct' \
       || ! printf '%s' "$fnout" | grep -q '1 correct transformations' \
       || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
       || printf '%s' "$fnout" | grep -q 'ERROR:'; then OK=0; fi
  done
} > "$RES" 2>&1
if [ "$OK" -eq 1 ]; then echo 'STATUS=alive2-green' >> "$RES"; STATUS=0
else echo 'STATUS=alive2-not-green' >> "$RES"; STATUS=1; fi
FILES=("$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh" "$TOOLS/build_leaf.sh" "$TOOLS/gate_common.h" "$TOOLS/c_cell.cpp" "$TOOLS/l_cell.cpp" "$EQ/contract/error_kind.h" "$RES")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in "$ROOT"/*) sha256sum "${f#\"$ROOT\"/}";; *) echo "# outside-root $(sha256sum "$f")";; esac
  done
} > "$OUT/certificate.sha256"
exit "$STATUS"
