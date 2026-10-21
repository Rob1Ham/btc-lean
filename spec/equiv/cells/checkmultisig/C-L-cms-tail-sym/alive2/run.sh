#!/usr/bin/env bash
# Alive2 lane for cells/checkmultisig/C-L-cms-tail-sym.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../_shared/run_alive2.sh" "$CELL_DIR" "cell_cms_tail"
