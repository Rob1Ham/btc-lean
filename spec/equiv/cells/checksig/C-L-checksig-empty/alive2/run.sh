#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$CELL_DIR/../../../findings/wave16/10-checksig-policy/tools"
exec "$TOOLS/run_alive2.sh" "$CELL_DIR" \
  "cell_checksig_empty,cell_checksig_empty_continue,cell_checksigverify_empty" \
  "checksig/C-L-checksig-empty" empty
