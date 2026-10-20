#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/arity/run_saw.sh" "$CELL_DIR"
