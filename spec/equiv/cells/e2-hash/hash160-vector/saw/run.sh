#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/e2/run_saw.sh" "$CELL_DIR" \
  "e2-hash/hash160-vector" 2
