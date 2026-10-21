#!/usr/bin/env bash
# SAW attempt for witness-v0/C-L-bip143-encoding-cs.
#
# 18 proofs: 9 functions x C and L legs, all against the Cryptol encoders in
# src/cell.cry with z3 (src/solver.txt).
#
# Classification is stricter than the shared witness-v0 runner, per the wave64
# F4 finding: green requires the expected proof count, the final success
# marker, and no "Proof failed", "Error", "Stack trace" or "Could not find"
# line anywhere in the transcript.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$CELL_DIR"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
mkdir -p "$OUT" "$BUILD"
"$CELL_DIR/src/build.sh"
cp "$CELL_DIR/src/cell.cry" "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"
RES="$OUT/result.txt"
EXPECTED=18
{
  echo "# cell: C-L-bip143-encoding-cs"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# solver: $(cat "$CELL_DIR/src/solver.txt")"
  echo "# expected: $EXPECTED 'Proof succeeded!' and no failure/error lines"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true
NPROOF="$(grep -c '^Proof succeeded!' "$RES" || true)"
OK=0
if [ "$NPROOF" -eq "$EXPECTED" ] \
   && grep -q '^CELL_BIP143_ENCODING_CS_SAW_GREEN$' "$RES" \
   && ! grep -q '^Proof failed' "$RES" \
   && ! grep -q 'Stack trace' "$RES" \
   && ! grep -q 'Could not find' "$RES" \
   && ! grep -q '^saw: error' "$RES" \
   && ! grep -q '^Error' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"; OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi

ROOT="$(git -C "$CELL_DIR" rev-parse --show-toplevel)"
REL="${CELL_DIR#"$ROOT"/}"
cd "$ROOT"
{
  for f in "$REL/spec.md" "$REL/notes.md" "$REL/saw/run.sh" \
           "$REL/src/build.sh" "$REL/src/c_cell.cpp" "$REL/src/l_cell.cpp" \
           "$REL/src/fns.txt" "$REL/src/solver.txt" "$REL/src/cell.cry" \
           "$REL/src/cell.saw" "$REL/ir"/*.ll "$REL/saw/result.txt" \
           "spec/equiv/cells/witness-v0/_tools/build.sh" \
           "spec/equiv/cells/witness-v0/_tools/wv_common.h"; do
    [ -f "$f" ] && sha256sum "$f"
  done | sort -k2
} > "$OUT/certificate.sha256"

[ "$OK" -eq 1 ]
