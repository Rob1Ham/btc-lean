#!/usr/bin/env bash
# Pin probe: measure the real VerifyWitnessProgram at the pinned bitcode and
# show the first Alive2 blocker.  This is evidence for why the prototype in
# cells/e5-whole/C-L-w2-v0-witness-exec is a bounded slice, not the engine.
#
# The pinned module is the [core.ir] O0 single-TU lane from spec/equiv/PINS.lock
# (sha256 f5718af7...); it is not the [ir] 15-TU closure.
set -euo pipefail

PIN_BC=${1:-/tmp/opencode/equiv-work/ir20/interpreter-O0.bc}
OUT=${2:-$(cd "$(dirname "$0")" && pwd)}
FN='_ZL20VerifyWitnessProgramRK14CScriptWitnessiRKSt6vectorIhSaIhEE19script_verify_flagsRK20BaseSignatureCheckerP13ScriptError_tb'

sha256sum "$PIN_BC"
/usr/lib/llvm-20/bin/llvm-nm "$PIN_BC" | grep VerifyWitnessProgram || true

/usr/lib/llvm-20/bin/llvm-extract --func="$FN" "$PIN_BC" -o "$OUT/verifywitnessprogram-O0.bc"
/usr/lib/llvm-20/bin/llvm-dis "$OUT/verifywitnessprogram-O0.bc" -o "$OUT/verifywitnessprogram-O0.ll"

{
  echo "invoke=$(grep -c ' invoke ' "$OUT/verifywitnessprogram-O0.ll")"
  echo "landingpad=$(grep -c 'landingpad' "$OUT/verifywitnessprogram-O0.ll")"
  echo "alloca=$(grep -c ' alloca ' "$OUT/verifywitnessprogram-O0.ll")"
  echo "call=$(grep -c ' call ' "$OUT/verifywitnessprogram-O0.ll")"
  /usr/lib/llvm-20/bin/opt -passes='print<loops>' -disable-output "$OUT/verifywitnessprogram-O0.bc"
} > "$OUT/shape.txt" 2>&1
cat "$OUT/shape.txt"

/opt/equiv-tools/alive-tv-v20.0 "$OUT/verifywitnessprogram-O0.ll" \
  --passes=verify --skip-smt > "$OUT/alive2.log" 2>&1 || true
cat "$OUT/alive2.log"
