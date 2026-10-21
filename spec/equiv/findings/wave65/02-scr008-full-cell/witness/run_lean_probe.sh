#!/usr/bin/env bash
# Wave65 / 02-scr008-full-cell
# Run the concrete Lean probe on the exact tapes the Core probe executes.
# Requires a built spec/core: (cd spec/core && lake build Bitcoin.Interpreter.Defs).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
LEAN="$ROOT/spec/core"

[ -d "$LEAN/.lake/build/lib/lean" ] || { echo "run 'lake build' in $LEAN first" >&2; exit 2; }

{
  echo "# F-DIV-W32-01 concrete Lean probe — wave65 re-run"
  echo "# lean=$( cd "$LEAN" && lake env lean --version | head -1 )"
  echo "# defs_blob=$(git -C "$ROOT" rev-parse HEAD:spec/core/Bitcoin/Interpreter/Defs.lean)"
  echo "# command: (cd spec/core && lake env lean ../equiv/findings/wave65/02-scr008-full-cell/witness/lean_probe.lean)"
  echo "# expected: P2SH-P2WPKH/P2WSH cleanstack=true FAIL cleanstack; controls OK"
  echo
  ( cd "$LEAN" && lake env lean \
      ../equiv/findings/wave65/02-scr008-full-cell/witness/lean_probe.lean )
} > "$HERE/lean-probe.txt" 2>&1
cat "$HERE/lean-probe.txt"

{
  cd "$ROOT"
  for f in \
    spec/equiv/findings/wave65/02-scr008-full-cell/witness/lean_probe.lean \
    spec/equiv/findings/wave65/02-scr008-full-cell/witness/run_lean_probe.sh \
    spec/equiv/findings/wave65/02-scr008-full-cell/witness/lean-probe.txt ; do
    sha256sum "$f"
  done
} > "$HERE/lean-probe.sha256"
