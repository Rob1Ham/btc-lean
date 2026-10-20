#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/w32cms/run_saw.sh" "$CELL_DIR" \
  "cell_cms_loop" "e3-cms/C-L-w32-cms-loop" c_loop.cpp l_loop.cpp \
  oracle_loop.py ""
