#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$CELL_DIR/../../../findings/wave16/10-checksig-policy/tools"
exec "$TOOLS/run_alive2.sh" "$CELL_DIR" \
  "cell_dersig_flag,cell_dersig_flag_mainnet,cell_dersig_or" \
  "checksig/C-L-checksig-bip66" bip66
