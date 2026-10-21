#!/usr/bin/env bash
# SAW attempt for limits/C-L-scr-040-witness-budget.
#
# Copies the cell's Cryptol spec and SAW script into build/ (so the recorded
# transcript is replayable from the recorded artifacts), then requires
# 42 llvm_verify successes (3 scalar functions x 2 legs, plus the
# serializer loop and budget at every count 0..8: 9 x 2 x 2).  The prove_print lemmas
# abort the script on failure, so a green run implies every lemma held.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CELL_ID="limits/C-L-scr-040-witness-budget"
MIN_PROOFS=42
SHARED="$(cd "$CELL_DIR/../_shared" && pwd)"
CELLS="$(cd "$SHARED/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
BUILD="$CELL_DIR/build"
OUT="$CELL_DIR/saw"
mkdir -p "$OUT"
"$SHARED/build_leaf.sh" "$CELL_DIR"
cp "$CELL_DIR/src/cell.cry" "$BUILD/cell.cry"
cp "$CELL_DIR/src/cell.saw" "$BUILD/cell.saw"
RES="$OUT/result.txt"
OK=0
{
  echo "# cell: $CELL_ID"
  echo "# saw: $(PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw --version 2>&1 | head -1)"
  echo "# spec: build/cell.cry"
  echo "# script: build/cell.saw"
  echo "# expected: at least $MIN_PROOFS 'Proof succeeded!' and no 'Proof failed'"
  echo "# command: (cd build && saw cell.saw)"
  echo
  ( cd "$BUILD" && PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw cell.saw )
} > "$RES" 2>&1 || true
if [ "$(grep -c '^Proof succeeded!' "$RES" || true)" -ge "$MIN_PROOFS" ] \
   && [ "$(grep -c '^PROVED ' "$RES" || true)" -ge 6 ] \
   && ! grep -q '^Proof failed' "$RES" \
   && ! grep -qE 'ERROR|Stack trace|Symbolic execution failed|Error during|panic|Aborted|saw: error|Expected type|Inferred type' "$RES"; then
  echo "STATUS=saw-green" >> "$RES"
  OK=1
else
  echo "STATUS=saw-not-green" >> "$RES"
fi

{
  cd "$ROOT"
  find "spec/equiv/cells/$CELL_ID" -type f \
    ! -path '*/build/*' ! -name 'certificate.sha256' -print | sort | while IFS= read -r f; do
      sha256sum "$f"
    done
  if [ -f "$CELL_DIR/src/cert-inputs.txt" ]; then
    while IFS= read -r rel; do
      [ -z "$rel" ] && continue
      case "$rel" in \#*) continue ;; esac
      sha256sum "$rel"
    done < "$CELL_DIR/src/cert-inputs.txt"
  fi
} > "$OUT/certificate.sha256"
[ "$OK" -eq 1 ]
