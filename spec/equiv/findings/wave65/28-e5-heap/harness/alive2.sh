#!/usr/bin/env bash
# Alive2 ingestion checks for the wave65/28 result.
#
# The engine is still rejected (invoke is unsupported by Alive2 v20).  The
# model *leaves* translate, but a self-comparison is only a translation check,
# never an equivalence proof.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OUT="${OUT:-/tmp/opencode/wave65/28-e5-heap-scratch}"
LOGS="$ROOT/logs"
ALIVE="${ALIVE:-/usr/local/bin/alive-tv}"
VS='_Z12VerifyScriptRK7CScriptS1_PK14CScriptWitness19script_verify_flagsRK20BaseSignatureCheckerP13ScriptError_t'
mkdir -p "$LOGS"

{
  echo "# alive-tv: $($ALIVE --version 2>&1 | tr '\n' ' ')"
  echo "# input: $OUT/closure-model-128.bc"
  echo "# func:  $VS"
} > "$LOGS/alive2-verifyScript-closure.log"
"$ALIVE" "$OUT/closure-model-128.bc" --func="$VS" --passes=verify --skip-smt \
  >> "$LOGS/alive2-verifyScript-closure.log" 2>&1
echo "verifyScript closure rc=$?"

for fn in _Znwm __cxa_guard_acquire __cxa_guard_release; do
  {
    echo "# alive-tv self-comparison (translation check only, not a proof)"
    echo "# func: $fn"
  } > "$LOGS/alive2-leaf-${fn}.log"
  "$ALIVE" "$OUT/closure-model-128.bc" --func="$fn" --passes=verify --skip-smt \
    >> "$LOGS/alive2-leaf-${fn}.log" 2>&1
  echo "leaf $fn rc=$?"
done
