#!/usr/bin/env bash
# Mutation test for numeric/C-L-numeric-default-4byte (SCR-080).
#
# Injects a bug into the *L* leg in a scratch copy of the cell and requires
# both tools to reject it.  The tracked cell is never modified.
#
# Mutation M-W64-080-a: at decode site 1 (OP_PICK/OP_ROLL) the twin's cap is
# changed from 4 to 5.  The C leg (Core's nDefaultMaxNumSize = 4) still
# rejects a 5-byte operand while L accepts it, so both directions must fail.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
EQ="$(cd "$HERE/../../../.." && pwd)"   # spec/equiv
CELL="$EQ/cells/numeric/C-L-numeric-default-4byte"
SCRATCH="$EQ/cells/numeric/_mut-M-W64-080-a"
OUT="$HERE/runs"
mkdir -p "$OUT"
rm -rf "$SCRATCH"
cp -r "$CELL" "$SCRATCH"
rm -rf "$SCRATCH/build" "$SCRATCH/alive2/result.txt" "$SCRATCH/saw/result.txt" \
       "$SCRATCH"/alive2/certificate.sha256 "$SCRATCH"/saw/certificate.sha256

# Inject: the site-1 twin decode cap 4 -> 5.
python3 - "$SCRATCH/src/l_leaf.cpp" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = "  const TwinErr e = decode_num(p, len, /*minimal=*/false, 4, n);\n  if (e != TWIN_OK) return dflt_obs(1,"
new = "  const TwinErr e = decode_num(p, len, /*minimal=*/false, 5, n);\n  if (e != TWIN_OK) return dflt_obs(1,"
assert s.count(old) == 1, "site-1 decode call not found exactly once"
open(p, "w").write(s.replace(old, new))
PY
diff -u "$CELL/src/l_leaf.cpp" "$SCRATCH/src/l_leaf.cpp" > "$OUT/M-W64-080-a.diff" || true

set +e
bash "$SCRATCH/alive2/run.sh" > "$OUT/M-W64-080-a-alive2.log" 2>&1
A=$?
bash "$SCRATCH/saw/run.sh" > "$OUT/M-W64-080-a-saw.log" 2>&1
S=$?
set -e

# Keep the verdict lines only; the raw logs are large (Alive2 prints both IRs).
{
  echo "# mutation M-W64-080-a: L site-1 cap 4 -> 5"
  echo "# alive2 runner exit: $A"
  echo "# saw runner exit: $S"
  echo "# --- alive2 verdict:"
  grep -E "^(# command|# FAILED|Transformation doesn't verify|ERROR:|These functions seem|  1 correct|  1 incorrect)" \
    "$SCRATCH/alive2/result.txt" | head -40
  echo "# --- saw verdict:"
  grep -E "^(Proof failed|Proof succeeded!|STATUS=)" "$SCRATCH/saw/result.txt" | head -40
} > "$OUT/M-W64-080-a-verdict.txt"
rm -f "$OUT/M-W64-080-a-alive2.log" "$OUT/M-W64-080-a-saw.log"
rm -rf "$SCRATCH"

cat "$OUT/M-W64-080-a-verdict.txt"
# The mutation must be killed by both tools.
if [ "$A" -eq 0 ] || [ "$S" -eq 0 ]; then
  echo "MUTATION NOT KILLED: alive2=$A saw=$S" >&2
  exit 1
fi
if ! grep -q "1 incorrect transformations" "$OUT/M-W64-080-a-verdict.txt"; then
  echo "Alive2 did not report an incorrect transformation" >&2
  exit 1
fi
if ! grep -q "^Proof failed" "$OUT/M-W64-080-a-verdict.txt"; then
  echo "SAW did not report a failed proof" >&2
  exit 1
fi
echo "MUTATION KILLED by Alive2 and SAW"
