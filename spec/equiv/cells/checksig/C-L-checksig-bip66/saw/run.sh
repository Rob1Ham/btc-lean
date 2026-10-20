#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$CELL_DIR/../../../findings/wave16/10-checksig-policy/tools"
exec "$TOOLS/run_saw.sh" "$CELL_DIR" "checksig/C-L-checksig-bip66" bip66
