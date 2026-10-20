#!/usr/bin/env bash
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$CELL_DIR/../../_tools/e3/cellsig/run_alive2.sh" "$CELL_DIR" \
  "cell_cms,cell_cmsverify,cell_cms_nulldummy,cell_cms_empty" "e3-cms/C-L-cms-1of1" cms
