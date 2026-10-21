#!/usr/bin/env bash
# Alive2 attempt for one E1 gate cell.  Writes the raw output and a
# certificate over the commands, inputs, extracted IR, and output.
set -euo pipefail

CELL_DIR="$1"
FN="$2"
ID="$3"
GATE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$GATE/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/alive2"
mkdir -p "$OUT"

"$GATE/build_leaf.sh" "$CELL_DIR" "$FN"

RES="$OUT/result.txt"
{
  echo "# cell: $ID"
  echo "# command: /usr/local/bin/alive-tv build/c_${FN}.ll build/l_${FN}.ll"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# twin_ops source: build/twin_ops.h sha256 $(sha256sum "$BUILD/twin_ops.h" | cut -d' ' -f1)"
  echo "# c IR: build/c_${FN}.ll"
  echo "# l IR: build/l_${FN}.ll"
  echo
  /usr/local/bin/alive-tv "$BUILD/c_${FN}.ll" "$BUILD/l_${FN}.ll"
} > "$RES" 2>&1 || true

if grep -q "Transformation seems to be correct!" "$RES" \
   && ! grep -q "Transformation doesn't verify!" "$RES" \
   && grep -q "1 correct transformations" "$RES"; then
  echo "STATUS=alive2-green" >> "$RES"
  STATUS=0
else
  echo "STATUS=alive2-not-green" >> "$RES"
  STATUS=1
fi

FILES=(
  "$CELL_DIR/spec.md"
  "$CELL_DIR/alive2/run.sh"
  "$GATE/run_alive2.sh"
  "$CELLS/_tools/mk_leaf.py"
  "$GATE/build_leaf.sh"
  "$GATE/gate_common.h"
  "$GATE/c_leaf.cpp"
  "$GATE/l_leaf.cpp"
  "$EQ/twin/ops_ir.py"
  "$EQ/twin/gen.py"
  "$EQ/contract/error_kind.h"
  "$BUILD/twin_ops.h"
  "$BUILD/c_${FN}.ll"
  "$BUILD/l_${FN}.ll"
  "$RES"
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
