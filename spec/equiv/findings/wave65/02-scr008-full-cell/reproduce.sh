#!/usr/bin/env bash
# Wave65 / 02-scr008-full-cell — reproduce everything in this finding.
#
#   ./reproduce.sh            # all runs, prints each STATUS line
#   CORE_SRC=/path ./reproduce.sh
#
# Requirements: /opt/equiv-tools/alive-tv-v20.0, SAW 1.6, clang++-20/LLVM 20,
# Lean 4.35 with spec/core buildable (lake build Bitcoin.Interpreter.Defs),
# and a Bitcoin Core checkout at pin cce32b168 (CORE_SRC, default /tmp/pcore01)
# for the concrete Core probe.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
cd "$ROOT"

echo "== concrete Core probe (expects verify=true on all tapes) =="
CORE_SRC="${CORE_SRC:-/tmp/pcore01}" "$HERE/witness/run_core_probe.sh" >/dev/null
grep -E "^tape=" "$HERE/witness/core-probe.txt"

echo
echo "== concrete Lean probe (expects W1/W2 FAIL cleanstack, controls OK) =="
"$HERE/witness/run_lean_probe.sh" >/dev/null
grep -E "verifyScriptFull" "$HERE/witness/lean-probe.txt"

echo
echo "== Alive2: full-domain, pinned model (expects counterexample) =="
"$HERE/alive2-pinned/run.sh" >/dev/null
grep -E "^STATUS=" "$HERE/alive2-pinned/result.txt"

echo
echo "== Alive2: full-domain, proposed fix (expects green) =="
"$HERE/alive2-fixed/run.sh" >/dev/null
grep -E "^STATUS=" "$HERE/alive2-fixed/result.txt"

echo
echo "== SAW: full-domain, pinned model (expects C proof + L refutation) =="
"$HERE/saw-pinned/run.sh" >/dev/null
grep -E "^STATUS=" "$HERE/saw-pinned/result.txt"

echo
echo "== SAW: full-domain, proposed fix (expects green) =="
"$HERE/saw-fixed/run.sh" >/dev/null
grep -E "^STATUS=" "$HERE/saw-fixed/result.txt"

echo
echo "== the sound-domain cell (expects both green) =="
bash "$ROOT/spec/equiv/cells/exec-verify/C-L-w65-scr008-cleanstack-arms/alive2/run.sh" >/dev/null
grep -E "^STATUS=" "$ROOT/spec/equiv/cells/exec-verify/C-L-w65-scr008-cleanstack-arms/alive2/result.txt"
bash "$ROOT/spec/equiv/cells/exec-verify/C-L-w65-scr008-cleanstack-arms/saw/run.sh" >/dev/null
grep -E "^STATUS=" "$ROOT/spec/equiv/cells/exec-verify/C-L-w65-scr008-cleanstack-arms/saw/result.txt"

echo
echo "== certificates =="
( cd "$ROOT"
  sha256sum -c "$HERE/alive2-pinned/certificate.sha256"
  sha256sum -c "$HERE/alive2-fixed/certificate.sha256"
  sha256sum -c "$HERE/saw-pinned/certificate.sha256"
  sha256sum -c "$HERE/saw-fixed/certificate.sha256"
  sha256sum -c "$HERE/witness/core-probe.sha256"
  sha256sum -c "$HERE/witness/lean-probe.sha256" )
