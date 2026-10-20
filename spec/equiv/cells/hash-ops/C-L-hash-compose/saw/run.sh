#!/usr/bin/env bash
# SAW: both composition legs against a concrete two-stage chain.
# The sha256/ripemd160 overrides pin the first-stage output and the
# second-stage input/output, so the proof checks the composition order and the
# 32-byte intermediate, not just the final constant.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CELLS="$(cd "$CELL_DIR/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
mkdir -p "$OUT"
"$CELL_DIR/src/build.sh"
cp "$CELL_DIR/src/cell.cry" "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"

RES="$OUT/result.txt"
{
  echo "# cell: hash-ops/C-L-hash-compose"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry"
  echo "# script: build/cell.saw"
  echo "# expected: at least 16 'Proof succeeded!' and no 'Proof failed'"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true

OK=0
if [ "$(grep -c '^Proof succeeded!' "$RES" || true)" -ge 16 ] \
   && ! grep -q '^Proof failed' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh" "$CELL_DIR/src/build.sh"
  "$CELL_DIR/src/hash_common.h" "$CELL_DIR/src/c_leaf.cpp" "$CELL_DIR/src/l_leaf.cpp"
  "$CELL_DIR/src/cell.cry" "$CELL_DIR/src/cell.saw"
  "$CELLS/_tools/mk_leaf.py"
  "$EQ/twin/ops_ir.py" "$EQ/twin/gen.py" "$EQ/twin/runtime.inc" "$EQ/contract/error_kind.h"
  "$BUILD/twin_ops.h" "$BUILD/build.txt"
  "$BUILD/c_leaf.ll" "$BUILD/l_leaf.ll" "$BUILD/c_leaf.bc" "$BUILD/l_leaf.bc"
  "$BUILD/cell.cry" "$BUILD/cell.saw" "$RES"
)
FNS=(cell_hash160_empty cell_hash160_a cell_hash256_empty cell_hash256_a
     cell_hash160_empty_chain cell_hash160_a_chain
     cell_hash256_empty_chain cell_hash256_a_chain)
for fn in "${FNS[@]}"; do
  FILES+=("$BUILD/c_${fn}.ll" "$BUILD/l_${fn}.ll")
done
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" ;;
      *) echo "# outside-root $(sha256sum "$f")" ;;
    esac
  done
} > "$OUT/certificate.sha256"
[ "$OK" -eq 1 ]
