#!/usr/bin/env bash
# SAW probe for F-DIV-w32-001: the C leg must match Core's order; the L leg
# must produce a counterexample.  Raw output is kept as evidence.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="$HERE/build"
OUT="$HERE/saw"
mkdir -p "$OUT"
"$HERE/build.sh"
PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw "$HERE/probe.saw" > "$OUT/result.txt" 2>&1 || true
if grep -q 'Proof failed' "$OUT/result.txt" \
   && [ "$(grep -c 'Proof succeeded!' "$OUT/result.txt")" -ge 1 ]; then
  echo "STATUS=divergence-confirmed" >> "$OUT/result.txt"
else
  echo "STATUS=not-confirmed" >> "$OUT/result.txt"
fi
