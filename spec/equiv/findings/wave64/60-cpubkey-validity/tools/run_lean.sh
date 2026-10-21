#!/usr/bin/env bash
# Run the Lean witness against the pinned core package.
# Usage: tools/run_lean.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SPEC="$(cd "$HERE/../../../../.." && pwd)"
OUT="$ROOT/results"
mkdir -p "$OUT"

cd "$SPEC"
lake build Bitcoin.Crypto.Seam.Entry Bitcoin.Crypto.EcdsaDeep.PubKeyParse \
  Bitcoin.Interpreter.Defs >/dev/null
lake env lean "$HERE/lean_witness.lean" > "$OUT/lean_table.txt" 2> "$OUT/lean_stderr.txt"
if [[ -s "$OUT/lean_stderr.txt" ]]; then
  echo "Lean stderr:" >&2
  cat "$OUT/lean_stderr.txt" >&2
fi
echo "wrote $OUT/lean_table.txt"
