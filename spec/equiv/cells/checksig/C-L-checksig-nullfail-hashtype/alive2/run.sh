#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$CELL_DIR/../../../findings/wave16/10-checksig-policy/tools"
exec "$TOOLS/run_alive2.sh" "$CELL_DIR" \
  "cell_checksig_nullfail,cell_hashtype" \
  "checksig/C-L-checksig-nullfail-hashtype" nullfail
