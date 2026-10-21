#!/usr/bin/env bash
# Alive2 probe for F-DIV-w32-001: the pair is expected to DIVERGE.
#
# Two runs are recorded because Alive2 20.0 is unsound on the raw clang -O1 IR:
# it reports "Transformation seems to be correct" even when one constant is
# changed, i.e. it silently skips the query.  After `opt -O2` the same pair
# yields the counterexample.  SAW and the concrete driver (run_driver.sh) back
# the finding independently.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="$HERE/build"
OUT="$HERE/alive2"
mkdir -p "$OUT"
"$HERE/build.sh"
{
  echo "# probe: F-DIV-w32-001 (OP_SUCCESSx pre-scan ordering on a truncated tail)"
  echo "# alive-tv: $(/usr/local/bin/alive-tv --version 2>&1 | head -1)"
  echo "# pair: build/{c,l}_probe.fn.ll, both derived from clang++-20 -O1"
  echo "# expected: C = BAD_OPCODE (64) where L = STACK_SIZE (32) / PUSH_SIZE (24)"
  echo
  echo "### run 1: raw -O1 IR (Alive2 20.0 skips the query: unsound 'correct')"
  /usr/local/bin/alive-tv --always-verify --smt-to=60000 \
      "$BUILD/c_probe.fn.ll" "$BUILD/l_probe.fn.ll" 2>&1 || true
  echo
  echo "### run 2: same pair after opt -O2 (counterexample found)"
  /usr/local/bin/alive-tv --always-verify --smt-to=60000 \
      "$BUILD/c_probe.opt.ll" "$BUILD/l_probe.opt.ll" 2>&1 || true
} > "$OUT/result.txt" 2>&1
if grep -q "^ERROR: Value mismatch" "$OUT/result.txt"; then
  echo "STATUS=divergence-confirmed" >> "$OUT/result.txt"
else
  echo "STATUS=not-confirmed" >> "$OUT/result.txt"
fi
