#!/usr/bin/env bash
# Lean runner for disabled/C-L-w65-row172-arbscan (SCR-172).
#
# Compiles the cell-local induction file against the pinned core package and
# checks that none of the four exported theorems depends on `sorryAx` or any
# other unexpected axiom.  The expected footprints are exactly
# `[propext, Quot.sound]`; `Classical.choice` is rejected so a future weakening
# of the proofs cannot pass silently.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CELL_ID="disabled/C-L-w65-row172-arbscan"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
SPEC="$ROOT/spec/core"
PROOF="$CELL_DIR/src/Row172Induction.lean"
OUT="$CELL_DIR/lean"
mkdir -p "$OUT"
RES="$OUT/result.txt"
THMS=(
  opSuccessScan_of_reaches_success
  opSuccessScan_of_reaches_disabled
  executeWitnessScript_tapscript_of_reaches_disabled
  evalFrom_prefix_disabled
)
{
  echo "# cell: $CELL_ID"
  echo "# lean: $(cd "$SPEC" && lake env lean --version 2>&1 | head -1)"
  echo "# package: spec/core"
  echo "# file: src/Row172Induction.lean"
  echo "# expected: ${#THMS[@]} axiom lines, each [propext, Quot.sound]; no sorryAx"
  echo
  ( cd "$SPEC" && lake build Bitcoin.Script.Tapscript.Delta )
  echo
  ( cd "$SPEC" && lake env lean "$PROOF" )
} > "$RES" 2>&1 || true
OK=1
if grep -v '^#' "$RES" | grep -q "sorryAx"; then OK=0; fi
if grep -v '^#' "$RES" | grep -qE "^error:"; then OK=0; fi
for thm in "${THMS[@]}"; do
  if ! grep -q "'Wave65Row172\.${thm}' depends on axioms: \[propext, Quot\.sound\]" "$RES"; then
    OK=0
  fi
done
if [ "$OK" -eq 1 ]; then
  echo "STATUS=lean-green" >> "$RES"
  STATUS=0
else
  echo "STATUS=lean-not-green" >> "$RES"
  STATUS=1
fi
FILES=(
  "$CELL_DIR/spec.md" "$CELL_DIR/notes.md" "$CELL_DIR/lean/run.sh"
  "$PROOF"
  "$SPEC/Bitcoin/Interpreter/Defs.lean"
  "$SPEC/Bitcoin/Script/Parser/Defs.lean"
  "$SPEC/Bitcoin/Script/Tapscript/Delta.lean"
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
