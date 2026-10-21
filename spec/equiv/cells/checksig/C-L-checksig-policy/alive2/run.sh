#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$CELL_DIR/../../../findings/wave16/10-checksig-policy/tools"
exec "$TOOLS/run_alive2.sh" "$CELL_DIR" \
  "cell_hashtype_gate,cell_is_defined_hashtype,cell_pubkey_encoding,cell_pubkey_predicates" \
  "checksig/C-L-checksig-policy" policy
