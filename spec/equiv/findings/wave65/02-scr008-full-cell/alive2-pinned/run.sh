#!/usr/bin/env bash
# SCR-008 full-domain probe, PINNED model: Core (c_core.cpp) vs the pinned
# Lean `finalLen` rule (l_pinned.cpp).  Expected: a counterexample at the
# P2SH-wrapped witness arm under CLEANSTACK (F-DIV-W32-01).
#
#   ./run.sh   ->  result.txt, STATUS=alive2-counterexample-as-expected
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FIND="$(cd "$HERE/.." && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
ALIVE="${ALIVE_TV:-/opt/equiv-tools/alive-tv-v20.0}"
[ -x "$ALIVE" ] || ALIVE="$(command -v alive-tv)"

bash "$FIND/src/build.sh" "$HERE/build"

OUT="$HERE/result.txt"
{
  echo "# SCR-008 full-domain probe — PINNED Lean model"
  echo "# alive-tv: $("$ALIVE" --version 2>&1 | head -1)"
  echo "# clang: $(/usr/bin/clang++-20 --version | head -1)"
  echo "# defs_blob=$(git -C "$ROOT" rev-parse HEAD:spec/core/Bitcoin/Interpreter/Defs.lean)"
  echo "# command: alive-tv build/c_core.ll build/l_pinned.ll"
  echo "# expected: counterexample at p2sh=1 spk_p2sh=1 witness=1 redeem_wit=1 cleanstack=1 inner_len!=1"
  echo
  "$ALIVE" "$HERE/build/c_core.ll" "$HERE/build/l_pinned.ll" 2>&1 || true
} > "$OUT"

if grep -q "Transformation doesn't verify" "$OUT" \
   && grep -q "^Example:" "$OUT"; then
  echo "STATUS=alive2-counterexample-as-expected" >> "$OUT"
else
  echo "STATUS=alive2-unexpected-green-or-error" >> "$OUT"
fi

{
  cd "$ROOT"
  for f in \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/probe_common.h \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/c_core.cpp \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/l_pinned.cpp \
    spec/equiv/findings/wave65/02-scr008-full-cell/src/build.sh \
    spec/equiv/findings/wave65/02-scr008-full-cell/alive2-pinned/run.sh \
    spec/equiv/findings/wave65/02-scr008-full-cell/alive2-pinned/result.txt ; do
    sha256sum "$f"
  done
} > "$HERE/certificate.sha256"

grep -E "^(Example:|  i64|  i32|Source value|Target value|STATUS)" "$OUT" || true
