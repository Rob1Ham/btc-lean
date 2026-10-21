#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../../findings/wave16/01-exec-verify/tools/run_saw.sh" "$CELL_DIR"
