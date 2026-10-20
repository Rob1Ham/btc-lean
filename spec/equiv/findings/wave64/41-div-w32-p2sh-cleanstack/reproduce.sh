#!/usr/bin/env bash
# Wave64 / 41-div-w32-p2sh-cleanstack — reproduce F-DIV-W32-01 end to end.
#
#   1. concrete Core  (real pinned VerifyScript, pristine extraction)
#   2. concrete Lean  (verifyScriptFull on the same byte tapes)
#   3. bounded Alive2 differential probe (domain-exact)
#
# usage: ./reproduce.sh
# Env:   CORE_SRC=/path/to/bitcoin-at-cce32b16   (default /tmp/pcore01)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"

echo "== 1/3 concrete Core =="
"$HERE/witness/run_core_probe.sh" >/dev/null
grep '^tape=' "$HERE/witness/core-probe.txt"

echo "== 2/3 concrete Lean =="
"$HERE/witness/run_lean_probe.sh" >/dev/null
grep '^"verifyScriptFull' "$HERE/witness/lean-probe.txt"

echo "== 3/3 bounded Alive2 differential =="
"$HERE/witness/alive2/run.sh" >/dev/null
grep -E 'Transformation doesn|Source value|Target value|STATUS=' "$HERE/witness/alive2/result.txt"

echo "== certificates =="
( cd "$ROOT"
  sha256sum -c spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/alive2/certificate.sha256
  sha256sum -c spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/core-probe.sha256
  sha256sum -c spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/lean-probe.sha256 )
