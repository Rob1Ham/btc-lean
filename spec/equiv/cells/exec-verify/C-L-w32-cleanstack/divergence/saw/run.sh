#!/usr/bin/env bash
# SCR-008 witness-implicit probe: a SAW proof failure is the expected result.
set -euo pipefail
CELL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
export X_BUILD="$CELL_DIR/divergence/build"
export X_OUT="$CELL_DIR/divergence/saw"
export X_RUNSH="$CELL_DIR/divergence/saw/run.sh"
export X_CRY="$CELL_DIR/divergence/probe.cry"
exec "$CELL_DIR/../../_tools/w32-exec-006-009/run_saw.sh" \
  "$CELL_DIR" "$CELL_DIR/divergence/manifest.txt" red
