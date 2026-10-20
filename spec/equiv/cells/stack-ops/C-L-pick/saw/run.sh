#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../_harness/run_saw.sh" "$CELL_DIR" "stack-ops/C-L-pick" "OP_PICK" 4 1 O1 build-saw
