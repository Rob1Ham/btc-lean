#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$CELL_DIR/../../../findings/wave16/10-checksig-policy/tools"
exec "$TOOLS/run_alive2.sh" "$CELL_DIR" \
  "cell_invalid_pubkey,cell_invalid_pubkey_continue" \
  "checksig/C-L-checksig-invalid-pubkey" invalidpubkey
