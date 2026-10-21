#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/e2/run_alive2.sh" "$CELL_DIR" \
  "e2-hash/hash160-vector" cell_hash160
