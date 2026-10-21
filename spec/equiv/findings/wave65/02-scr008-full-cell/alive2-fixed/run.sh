#!/usr/bin/env bash
# SCR-008 full-domain probe, FIXED model: Core (c_core.cpp) vs the proposed
# `finalLen` fix keyed off the P2SH redeem script (l_fixed.cpp).
# Expected: green over the whole (shape-valid) input space, including
# P2SH-wrapped witness + CLEANSTACK.
#
#   ./run.sh   ->  result.txt, STATUS=alive2-green
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FIND="$(cd "$HERE/.." && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
ALIVE="${ALIVE_TV:-/opt/equiv-tools/alive-tv-v20.0}"
[ -x "$ALIVE" ] || ALIVE="$(command -v alive-tv)"

bash "$FIND/src/build.sh" "$HERE/build"

OUT="$HERE/result.txt"
{
  echo "# SCR-008 full-domain probe — PROPOSED fix (shadow model, not the pin)"
  echo "# alive-tv: $("$ALIVE" --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# defs_blob=$(git -C "$ROOT" rev-parse HEAD:spec/core/Bitcoin/Interpreter/Defs.lean)"
  echo "# command: alive-tv build/c_core.ll build/l_fixed.ll"
  echo "# expected: correct transformation for every shape-valid input, incl. wrapped witness + cleanstack"
  echo
  "$ALIVE" "$HERE/build/c_core.ll" "$HERE/build/l_fixed.ll" 2>&1 || true
} > "$OUT"

if grep -q "Transformation seems to be correct" "$OUT" \
   && grep -q "0 incorrect transformations" "$OUT" \
   && grep -q "0 Alive2 errors" "$OUT"; then
  echo "STATUS=alive2-green" >> "$OUT"
else
  echo "STATUS=alive2-not-green" >> "$OUT"
fi

{
  cd "$ROOT"
  for f in \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/probe_common.h \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/c_core.cpp \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/l_fixed.cpp \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/build.sh \
    spec/equiv/findings/wave65/02-scr008-full-cell/alive2-fixed/run.sh \
    spec/equiv/findings/wave65/02-scr008-full-cell/alive2-fixed/result.txt ; do
    sha256sum "$f"
  done
} > "$HERE/certificate.sha256"

tail -8 "$OUT"
