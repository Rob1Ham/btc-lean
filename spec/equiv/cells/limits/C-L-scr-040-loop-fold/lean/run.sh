#!/usr/bin/env bash
# Supplementary cell-local Lean kernel check for the SCR-040 loop-to-fold
# bridge at arbitrary item count.
#
# This does NOT build or modify spec/proofs.  It compiles a cell-local theorem
# file against the zero-dependency core package (spec/core); the file is not
# imported by any shared proof module.  It also re-runs the pinned-text
# extraction check, so the string literals the kernel reasons about are
# re-derived from the Core tree at pin cce32b168.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CELL_ID="limits/C-L-scr-040-loop-fold"
EQ="$(cd "$CELL_DIR/../../.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
CORE="$ROOT/spec/core"
OUT="$CELL_DIR/lean"
mkdir -p "$OUT"
RES="$OUT/result.txt"
LEAN_FILE="$CELL_DIR/src/lean/LoopToFold.lean"
OK=0
{
  echo "# cell: $CELL_ID"
  echo "# tool: $( cd "$CORE" && lake env lean --version 2>&1 | head -1 )"
  echo "# package: spec/core (zero-dependency Bitcoin model)"
  echo "# file: src/lean/LoopToFold.lean"
  echo "# pin check: src/extract_pinned.py --check (Core pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66)"
  echo
  ( cd "$CORE" && lake build Bitcoin >/dev/null 2>&1 || true )
  ( cd "$CORE" && lake env lean "$LEAN_FILE" ) && OK=1
  echo
  echo "# pinned-text extraction check"
  if python3 "$CELL_DIR/src/extract_pinned.py" --check "$LEAN_FILE"; then
    echo "PIN_CHECK=ok"
  else
    echo "PIN_CHECK=failed"
    OK=0
  fi
} > "$RES" 2>&1 || true
if [ "$OK" -eq 1 ] \
   && ! grep -q 'sorryAx' "$RES" \
   && ! grep -q 'error:' "$RES"; then
  echo "STATUS=lean-green" >> "$RES"
  echo "PROVED runLoop_eq_fold (arbitrary List ByteArray; loop from index 0 = left fold)"
  echo "PROVED seed_eq_validationWeightInit (arbitrary List ByteArray)"
  echo "PROVED pinned_vector_ser, pinned_basic_byte, pinned_offset, pinned_seed_line, pinned_sizecomputer_{seek,write}, pinned_write_compact_size, pinned_get_serialize_size (kernel decide)"
else
  echo "STATUS=lean-not-green" >> "$RES"
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
