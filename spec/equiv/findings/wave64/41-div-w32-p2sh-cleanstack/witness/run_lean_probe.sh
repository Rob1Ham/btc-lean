#!/usr/bin/env bash
# Wave64 / 41-div-w32-p2sh-cleanstack
# Run the concrete Lean probe for F-DIV-W32-01 on the exact tapes the Core
# probe executes.  Requires a built spec/core (lake build).
#
# usage: run.sh      (from anywhere; repository root is derived from HERE)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
LEAN="$ROOT/spec/core"

[ -d "$LEAN/.lake/build/lib/lean" ] || { echo "run 'lake build' in $LEAN first" >&2; exit 2; }

{
  echo "# F-DIV-W32-01 concrete Lean probe"
  echo "# lean=$( cd "$LEAN" && lake env lean --version | head -1 )"
  echo "# command: (cd spec/core && lake env lean ../equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/lean_probe.lean)"
  echo "# expected: P2SH-P2WPKH/P2WSH cleanstack=true FAIL cleanstack; controls OK"
  echo
  ( cd "$LEAN" && lake env lean \
      ../equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/lean_probe.lean )
} > "$HERE/lean-probe.txt" 2>&1
cat "$HERE/lean-probe.txt"

{
  cd "$ROOT"
  for f in \
    spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/lean_probe.lean \
    spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/run_lean_probe.sh \
    spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/lean-probe.txt ; do
    sha256sum "$f"
  done
} > "$HERE/lean-probe.sha256"
