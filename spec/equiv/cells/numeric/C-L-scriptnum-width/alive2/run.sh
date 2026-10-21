#!/usr/bin/env bash
# Alive2 leg: C excerpt vs L (twin IR) for the CScriptNum width guard
# (script.h:246-271), symbolic over every 8-byte content word and every
# element length 0..8.
set -euo pipefail
CELL="$(cd "$(dirname "$0")/.." && pwd)"
EQ="$(cd "$CELL/../../.." && pwd)"
exec "$EQ/findings/wave16/07-numeric-ops/tools/run_alive2.sh" \
  "$CELL" numeric/C-L-scriptnum-width cell_scriptnum cell_1add
