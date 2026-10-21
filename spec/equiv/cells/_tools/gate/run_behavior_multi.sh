#!/usr/bin/env bash
# Whole-entry behavioral witnesses for a multi-function broader cell.
# The cell's behavior/manifest.txt has lines: <spk-hex> <expected-rc,err> <label>
# This is never proof evidence.
set -euo pipefail

CELL_DIR="$1"
ID="$2"
GATE="$(cd "$(dirname "$0")" && pwd)"
CELLS="$(cd "$GATE/../.." && pwd)"
EQ="$(cd "$CELLS/.." && pwd)"
ROOT="$(cd "$EQ/../.." && pwd)"
OUT="$CELL_DIR/behavior"
MAN="$OUT/manifest.txt"
C_LIB="${CELLS_CORE_LIB:-/tmp/opencode/cbuild/libequiv-core.so}"
L_LIB="${CELLS_TWIN_LIB:-$EQ/twin/build/libtwin.so}"
mkdir -p "$OUT"

[ -f "$MAN" ] || { echo "missing $MAN" >&2; exit 2; }

RES="$OUT/result.txt"
{
  echo "# cell: $ID"
  echo "# command: per-witness python3 _tools/gate/witness.py"
  echo "# note: behavioral witnesses only; not proof evidence"
  echo
} > "$RES"

N=0
GREEN=0
while read -r spk expect label; do
  [ -z "${spk:-}" ] && continue
  N=$((N + 1))
  {
    echo "### witness: $label spk=$spk expect=$expect"
    python3 "$GATE/witness.py" --cell "$ID/$label" --spk "$spk" \
      --c-lib "$C_LIB" --twin-lib "$L_LIB" --expect "$expect" || true
    echo
  } >> "$RES" 2>&1
done < "$MAN"

# The loop's cumulative grep is not enough: count only the latest block.
GREEN=$(grep -c "witness_status=behavior-match" "$RES" || true)
if [ "$GREEN" -eq "$N" ]; then
  echo "STATUS=behavior-match" >> "$RES"
  STATUS=0
else
  echo "STATUS=behavior-mismatch (matches=$GREEN/$N)" >> "$RES"
  STATUS=1
fi

{
  cd "$ROOT"
  REL_CELL="${CELL_DIR#"$ROOT"/}"
  sha256sum "$REL_CELL/behavior/result.txt" 2>/dev/null || true
  sha256sum "$REL_CELL/behavior/run.sh" 2>/dev/null || true
  sha256sum "spec/equiv/cells/_tools/gate/run_behavior_multi.sh"
  echo "# c_lib $(sha256sum "$C_LIB")"
  echo "# l_lib $(sha256sum "$L_LIB")"
  sha256sum "spec/equiv/cells/_tools/gate/witness.py"
} > "$OUT/certificate.sha256" 2>/dev/null || true

exit "$STATUS"
