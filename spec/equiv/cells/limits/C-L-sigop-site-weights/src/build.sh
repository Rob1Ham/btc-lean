#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../_shared/build_leaf.sh" "$CELL_DIR"
