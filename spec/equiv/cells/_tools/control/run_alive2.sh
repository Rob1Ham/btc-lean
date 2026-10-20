#!/usr/bin/env bash
# Alive2 attempt for the control-flow cell.  Every function is closed, so the
# pair is compared directly; the runner parses the report text because
# alive-tv exits 0 even on a counterexample.
set -euo pipefail
CELL_DIR="$1"
GATE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$GATE/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
FNS=(cell_op_return cell_plain_nop cell_nop1 cell_nop4_to_10)
mkdir -p "$OUT"
"$GATE/build_leaf.sh" "$CELL_DIR"
RES="$OUT/result.txt"
OK=1
{
  echo "# cell: control/C-L-nop-return"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# twin_ops source: build/twin_ops.h sha256 $(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  for fn in "${FNS[@]}"; do
    echo "# command: alive-tv build/c_${fn}.ll build/l_${fn}.ll"
    fnout="$(/usr/local/bin/alive-tv "$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll" 2>&1 || true)"
    printf '%s\n' "$fnout"
    if ! printf '%s' "$fnout" | grep -q "Transformation seems to be correct" \
       || ! printf '%s' "$fnout" | grep -q "1 correct transformations" \
       || printf '%s' "$fnout" | grep -q "Transformation doesn't verify" \
       || printf '%s' "$fnout" | grep -q "ERROR:"; then
      OK=0
    fi
  done
} > "$RES" 2>&1
if [ "$OK" -eq 1 ]; then
  echo "STATUS=alive2-green" >> "$RES"
  STATUS=0
else
  echo "STATUS=alive2-not-green" >> "$RES"
  STATUS=1
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/alive2/run.sh"
  "$CELLS/_tools/mk_leaf.py" "$GATE/build_leaf.sh" "$GATE/gate_common.h"
  "$GATE/c_leaf.cpp" "$GATE/l_leaf.cpp"
  "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py" "$EQ/contract/error_kind.h"
  "$BUILD/twin_ops.h" "$RES"
)
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" ;;
      *) echo "# outside-root $(sha256sum "$f")" ;;
    esac
  done
} > "$OUT/certificate.sha256"
exit "$STATUS"
