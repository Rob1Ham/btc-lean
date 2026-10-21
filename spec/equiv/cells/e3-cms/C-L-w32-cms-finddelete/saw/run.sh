#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/w32cms/run_saw.sh" "$CELL_DIR" \
  "cell_fd_found,cell_fd_len,cell_fd_bytes,cell_fd_chain,cell_fd_chain_n" \
  "e3-cms/C-L-w32-cms-finddelete" c_finddel.cpp l_finddel.cpp \
  oracle_finddel.py ""
