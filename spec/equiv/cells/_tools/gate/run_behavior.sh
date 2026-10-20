#!/usr/bin/env bash
# Whole-entry behavioral witness (NOT a proof) for one E1 gate cell.
set -euo pipefail

CELL_DIR="$1"
ID="$2"
SPK="$3"
GATE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$GATE/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
OUT="$CELL_DIR/behavior"
C_LIB="${CELLS_CORE_LIB:-/tmp/opencode/cbuild/libequiv-core.so}"
L_LIB="${CELLS_TWIN_LIB:-$EQ/twin/build/libtwin.so}"
mkdir -p "$OUT"

RES="$OUT/result.txt"
{
  echo "# cell: $ID"
  echo "# command: python3 _tools/gate/witness.py --cell ... --spk $SPK"
  echo "# note: behavioral witness only; not proof evidence"
  echo
  python3 "$GATE/witness.py" --cell "$ID" --spk "$SPK" \
    --c-lib "$C_LIB" --twin-lib "$L_LIB" --expect 1,0
} > "$RES" 2>&1 || true

if grep -q "witness_status=behavior-match" "$RES"; then
  echo "STATUS=behavior-match" >> "$RES"
  STATUS=0
else
  echo "STATUS=behavior-mismatch" >> "$RES"
  STATUS=1
fi

{
  cd "$ROOT"
  REL_CELL="${CELL_DIR#"$ROOT"/}"
  sha256sum "$REL_CELL/behavior/result.txt" 2>/dev/null || true
  sha256sum "$REL_CELL/behavior/run.sh" 2>/dev/null || true
  sha256sum "spec/equiv/cells/_tools/gate/run_behavior.sh"
  echo "# c_lib $(sha256sum "$C_LIB")"
  echo "# l_lib $(sha256sum "$L_LIB")"
  sha256sum "spec/equiv/cells/_tools/gate/witness.py"
} > "$OUT/certificate.sha256" 2>/dev/null || true

exit "$STATUS"
