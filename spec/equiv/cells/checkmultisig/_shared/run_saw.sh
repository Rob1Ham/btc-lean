#!/usr/bin/env bash
# SAW attempt for one CHECKMULTISIG cell.
#
#   run_saw.sh <cell_dir> <case1,case2,...>
#
# The cell owns saw/spec.saw.in (a SAWScript template with @CASE@) and
# saw/model.cry (an independent Cryptol oracle written from the rule, not from
# either leg).  For every stub case the SAME stub instance is linked into both
# legs, the template is specialised, and each witness function is verified
# against a fully symbolic spec.  The checker/policy stub is not a crypto
# proof; see the cell's trust_note.
set -euo pipefail

CELL_DIR="$1"; CASES="$2"
SH="$(cd "$(dirname "$0")" && pwd)"
EQ="$(cd "$SH/../../.." && pwd)"       # spec/equiv
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"; OUT="$CELL_DIR/saw"
SAWPATH="/opt/equiv-tools/saw-1.6/bin:$PATH"
mkdir -p "$OUT"

RES="$OUT/result.txt"
{
  echo "# cell: $(basename "$CELL_DIR")"
  echo "# command: (cd build && saw spec_c<case>.saw), cases $CASES"
  echo "# saw: $(PATH=$SAWPATH saw --version 2>&1 | head -1)"
  echo "# expected: saw/model.cry (independent Cryptol oracle)"
  echo
} > "$RES"

OK=1
IFS=',' read -r -a ARR <<< "$CASES"
for CK in "${ARR[@]}"; do
  "$SH/build_ir.sh" "$CELL_DIR" saw "$CK" >/dev/null
  cp "$CELL_DIR/saw/model.cry" "$BUILD/model.cry"
  sed "s/@CASE@/$CK/g" "$CELL_DIR/saw/spec.saw.in" > "$BUILD/spec_c${CK}.saw"
  {
    echo "===== case $CK ====="
    ( cd "$BUILD" && PATH=$SAWPATH saw "spec_c${CK}.saw" ) || true
    echo
  } >> "$RES"
  if ! grep -q "CASE_${CK}_OK" "$RES"; then OK=0; fi
done

if grep -q "Proof failed" "$RES"; then OK=0; fi
GOT=$(grep -c "Proof succeeded" "$RES" || true)
if [ "$OK" -eq 1 ]; then
  echo "STATUS=saw-green ($GOT proofs, ${#ARR[@]} cases)" >> "$RES"
else
  echo "STATUS=saw-not-green ($GOT proofs, ${#ARR[@]} cases)" >> "$RES"
fi

FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/saw/run.sh" "$CELL_DIR/notes.md"
  "$CELL_DIR/saw/spec.saw.in" "$CELL_DIR/saw/model.cry"
  "$SH/cms_obs.h" "$SH/cms_seam.h" "$SH/checker_stub.cpp" "$SH/build_ir.sh"
  "$CELL_DIR"/src/*.cpp "$EQ/contract/error_kind.h" "$RES"
)
for CK in "${ARR[@]}"; do
  FILES+=("$BUILD/c_saw_c${CK}.bc" "$BUILD/l_saw_c${CK}.bc"
          "$BUILD/spec_c${CK}.saw")
done
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
