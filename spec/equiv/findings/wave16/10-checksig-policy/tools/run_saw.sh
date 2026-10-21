#!/usr/bin/env bash
# SAW lane for one wave-16 CHECKSIG cell.
#
#   run_saw.sh <cell_dir> <cell_id> <key>
#
# Each leg's module is verified independently against the same hand-written
# Cryptol predicate in <cell>/saw/*.cry.  The predicate is an independent
# restatement of the pinned rule, not extracted from either leg; C |- spec and
# L |- spec together give C == L over the cell domain.  The shared checker is a
# concrete stub in stubs.cpp for the cells that call it (same-crypto premise in
# docs/DECISION-lax-ecdsa.md); cells whose rule short-circuits before the
# checker never call it.
set -euo pipefail

CELL_DIR="$1"; ID="$2"; KEY="$3"
TOOLS="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$TOOLS" && while [ ! -f spec/equiv/contract/error_kind.h ]; do cd ..; done; pwd)"
BUILD="$CELL_DIR/build"; OUT="$CELL_DIR/saw"
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"
mkdir -p "$OUT"

"$TOOLS/build.sh" "$CELL_DIR" saw "$KEY"
for f in "$CELL_DIR"/saw/*.cry "$CELL_DIR"/saw/*.saw; do
  [ -e "$f" ] && cp "$f" "$BUILD/"
done

RES="$OUT/result.txt"
{
  echo "# cell: $ID"
  echo "# key: $KEY"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# cryptol spec: sha256 $(sha256sum "$CELL_DIR/saw/"*.cry | cut -d' ' -f1 | tr '\n' ' ')"
  echo "# command: (cd build && saw $(basename "$CELL_DIR"/saw/*.saw))"
  echo
} > "$RES"

OK=1
{
  ( cd "$BUILD" && PATH=$SAWPATH saw "$(basename "$CELL_DIR"/saw/*.saw)" ) 2>&1 \
    | tee -a "$RES" || OK=0
} 
if ! grep -q "Proof failed" "$RES" && grep -q "Proof succeeded!" "$RES"; then
  :
else
  OK=0
fi
if [ "$OK" -eq 1 ]; then
  echo "STATUS=saw-green" >> "$RES"
else
  echo "STATUS=saw-not-green" >> "$RES"
fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh"
  "$TOOLS/cell_common.h" "$TOOLS/c_${KEY}.cpp" "$TOOLS/l_${KEY}.cpp"
  "$TOOLS/stubs.cpp" "$TOOLS/build.sh" "$TOOLS/run_saw.sh"
  "$ROOT/spec/equiv/contract/error_kind.h" "$BUILD/build_saw.txt" "$RES"
)
for f in "$CELL_DIR"/saw/*.cry "$CELL_DIR"/saw/*.saw; do
  [ -e "$f" ] && FILES+=("$f")
done
FILES+=("$BUILD/c_leaf_saw.bc" "$BUILD/l_leaf_saw.bc" "$BUILD/stubs.bc")
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" 2>/dev/null || true ;;
      *) echo "# outside-root $f" ;;
    esac
  done
} > "$OUT/certificate.sha256"

[ "$OK" -eq 1 ]
