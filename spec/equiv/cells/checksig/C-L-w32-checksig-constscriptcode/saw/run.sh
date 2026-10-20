#!/usr/bin/env bash
# SAW lane: closed-scenario equivalence.  The oracle restates the row
# semantics independently and emits concrete argument tuples plus expected
# packed constants.  SAW executes the -O0 compiled C and L functions on those
# concrete inputs and proves both return the oracle constant.  This lane is
# complementary to Alive2, which carries the symbolic equivalence proof; the
# scenarios ensure every row branch has a concrete, independently derived
# witness on both legs.  No llvm_unsafe_assume_spec is used.
set -euo pipefail

CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$CELL_DIR/src"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
ROOT="$(cd "$CELL_DIR/../../../../.." && pwd)"
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"

"$SRC/build.sh" saw
mkdir -p "$OUT"
python3 "$SRC/oracle.py" --json "$BUILD/scenarios.json" --saw "$BUILD/cell.saw" > "$BUILD/oracle.txt"

RES="$OUT/result.txt"
{
  echo "# cell: C-L-w32-checksig-constscriptcode"
  echo "# lane: saw (closed scenarios; independent oracle constants)"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# build: -O0 -fno-strict-aliasing -emit-llvm -c (no constant folding of the core)"
  echo "# oracle: src/oracle.py (restates the row; not generated from C/L)"
  echo "# domain: same 6-byte domain as Alive2; 15 closed policy/branch-covering scenarios"
  echo "# cwd: $BUILD"
  echo "# command: saw cell.saw"
  echo
  echo "===== oracle ====="
  cat "$BUILD/oracle.txt"
  echo
  echo "===== saw ====="
} > "$RES"
( cd "$BUILD" && PATH=$SAWPATH saw cell.saw ) >> "$RES" 2>&1 || true

WANT=$(( $(python3 -c "import json;print(len(json.load(open('$BUILD/scenarios.json'))))") * 2 ))
GOT=$(grep -c '^Proof succeeded!' "$RES" || true)
{
  echo
  echo "# proofs expected: $WANT (scenarios x 2 legs)"
  echo "# proofs succeeded: $GOT"
} >> "$RES"
if [ "$GOT" -eq "$WANT" ] && ! grep -q 'Proof failed' "$RES" && ! grep -q 'ERROR' "$RES"; then
  echo "STATUS=saw-green ($GOT/$WANT proofs)" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green ($GOT/$WANT proofs)" >> "$RES"
  OK=0
fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/saw/run.sh"
  "$SRC/build.sh" "$SRC/oracle.py" "$OUT/result.txt"
  "$BUILD/scenarios.json" "$BUILD/cell.saw" "$BUILD/build-saw.txt"
)
for f in "$SRC"/*.cpp; do FILES+=("$f"); done
for f in "$BUILD"/*.bc; do FILES+=("$f"); done
{
  cd "$ROOT"
  for f in "${FILES[@]}"; do
    case "$f" in
      "$ROOT"/*) sha256sum "${f#"$ROOT"/}" 2>/dev/null || true ;;
      *) echo "# outside-root $(sha256sum "$f" 2>/dev/null || echo missing)" ;;
    esac
  done
} > "$OUT/certificate.sha256"

[ "$OK" -eq 1 ]
