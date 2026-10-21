#!/usr/bin/env bash
# Supplementary cell-local Lean kernel check for the arbitrary-count identity.
#
# This does NOT build or modify spec/proofs.  It uses the zero-dependency core
# package (spec/core) and compiles a cell-local theorem file against it.  The
# file is not imported by any shared proof module.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
CORE="$ROOT/spec/core"
OUT="$CELL_DIR/lean"
mkdir -p "$OUT"
RES="$OUT/result.txt"
LEAN_FILE="$CELL_DIR/src/lean/BudgetComposition.lean"
OK=0
{
  echo "# cell: limits/C-L-scr-040-witness-budget"
  echo "# tool: $( cd "$CORE" && lake env lean --version 2>&1 | head -1 )"
  echo "# package: spec/core (zero-dependency Bitcoin model)"
  echo "# file: src/lean/BudgetComposition.lean"
  echo
  ( cd "$CORE" && lake build Bitcoin >/dev/null 2>&1 || true )
  ( cd "$CORE" && lake env lean "$LEAN_FILE" ) && OK=1
} > "$RES" 2>&1 || true
if [ "$OK" -eq 1 ]; then
  echo "STATUS=lean-green" >> "$RES"
  echo "PROVED validationWeightInit_eq_count_add_fold (arbitrary List ByteArray)"
  echo "PROVED validationWeightInit_eq_encoder_add_offset (arbitrary List ByteArray)"
  echo "PROVED count_add_fold_eq_encoder (arbitrary List ByteArray)"
else
  echo "STATUS=lean-not-green" >> "$RES"
fi

{
  cd "$ROOT"
  find "spec/equiv/cells/limits/C-L-scr-040-witness-budget" -type f \
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
