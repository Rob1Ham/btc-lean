#!/usr/bin/env bash
# SCR-008 full-domain probe under the PINNED model, SAW leg.
# The Core leaf must verify against `core_arms`; the pinned Lean leaf must
# FAIL at the P2SH-wrapped witness + CLEANSTACK class (F-DIV-W32-01).
# Expected: STATUS=saw-divergence-as-expected (one proof, one refutation).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FIND="$(cd "$HERE/.." && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
SAW="${SAW:-/opt/equiv-tools/saw-1.6/bin/saw}"
[ -x "$SAW" ] || SAW="$(command -v saw)"
export PATH="$(dirname "$SAW"):$PATH"

bash "$FIND/src/build.sh" "$FIND/build"

OUT="$HERE/result.txt"
{
  echo "# SCR-008 full-domain probe — PINNED Lean model — SAW"
  echo "# saw: $("$SAW" --version 2>&1 | head -1)"
  echo "# defs_blob=$(git -C "$ROOT" rev-parse HEAD:spec/core/Bitcoin/Interpreter/Defs.lean)"
  echo "# command: (cd saw-pinned && saw cell.saw)   [cwd = the saw/ dir; module paths are ../build/...]"
  echo "# expected: C succeeds, pinned-L refuted at p2sh/wrapped/cleanstack"
  echo
  ( cd "$HERE" && "$SAW" cell.saw )
} > "$OUT" 2>&1 || true

NSUCC=$(grep -c 'Proof succeeded!' "$OUT" || true)
if [ "$NSUCC" -eq 1 ] && grep -q "Proof failed" "$OUT"; then
  echo "STATUS=saw-divergence-as-expected" >> "$OUT"
  RC=0
else
  echo "STATUS=saw-unexpected-outcome" >> "$OUT"
  RC=1
fi

{
  cd "$ROOT"
  for f in \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/probe_common.h \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/c_core.cpp \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/l_pinned.cpp \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/build.sh \
    spec/equiv/findings/wave65/02-scr008-full-cell/saw-pinned/cell.cry \
    spec/equiv/findings/wave65/02-scr008-full-cell/saw-pinned/cell.saw \
    spec/equiv/findings/wave65/02-scr008-full-cell/saw-pinned/run.sh \
    spec/equiv/findings/wave65/02-scr008-full-cell/saw-pinned/result.txt ; do
    sha256sum "$f"
  done
} > "$HERE/certificate.sha256"

grep -E "Proof (succeeded|failed)|STATUS|cleanstack|witness|p2sh" "$OUT" | head -30 || true
exit "$RC"
