#!/usr/bin/env bash
# SCR-008 full-domain probe under the PROPOSED model fix, SAW leg.
# Both the Core leaf and the fixed-L leaf must verify against the same
# `core_arms` Cryptol table (which includes the wrapped-witness CLEANSTACK
# class).  Expected: STATUS=saw-green.
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
  echo "# SCR-008 full-domain probe — PROPOSED fix — SAW"
  echo "# saw: $("$SAW" --version 2>&1 | head -1)"
  echo "# defs_blob=$(git -C "$ROOT" rev-parse HEAD:spec/core/Bitcoin/Interpreter/Defs.lean)"
  echo "# command: (cd saw-fixed && saw cell.saw)   [cwd = the saw/ dir; module paths are ../build/...]"
  echo
  ( cd "$HERE" && "$SAW" cell.saw )
} > "$OUT" 2>&1 || true

if [ "$(grep -c 'Proof succeeded!' "$OUT" || true)" -eq 2 ] \
   && grep -q "W65_SCR008_SAW_FIXED_GREEN" "$OUT" \
   && ! grep -q "Proof failed" "$OUT"; then
  echo "STATUS=saw-green" >> "$OUT"
  RC=0
else
  echo "STATUS=saw-not-green" >> "$OUT"
  RC=1
fi

{
  cd "$ROOT"
  for f in \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/probe_common.h \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/c_core.cpp \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/l_fixed.cpp \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/build.sh \
    spec/equiv/findings/wave65/02-scr008-full-cell/saw-fixed/cell.cry \
    spec/equiv/findings/wave65/02-scr008-full-cell/saw-fixed/cell.saw \
    spec/equiv/findings/wave65/02-scr008-full-cell/saw-fixed/run.sh \
    spec/equiv/findings/wave65/02-scr008-full-cell/saw-fixed/result.txt ; do
    sha256sum "$f"
  done
} > "$HERE/certificate.sha256"

grep -E "Proof (succeeded|failed)|STATUS" "$OUT" || true
exit "$RC"
