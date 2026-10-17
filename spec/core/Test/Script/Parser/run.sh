#!/usr/bin/env bash
# run.sh — W05 test runner: parser unit tests + script_tests.json conformance.
#
# Chain: ref.py (Python port of Core ParseScript + GetScriptOp @ cce32b168)
#       -> /tmp conf_input.txt + conf_expected.txt
#       Conformance.lean (Lean parseFrom) -> per-line diff + roundtrip axis.
# Corpus: the hash-pinned spec/vectors/core/script_tests.json (W07 copy;
# sha256 7fb93dea245f68b6…, identical to the cce32b168 checkout W05 used).
set -euo pipefail
CORE="$(cd "$(dirname "$0")/../../.." && pwd)"
SPEC="$(cd "$CORE/.." && pwd)"
OUT=build/scratch/w05-conf
mkdir -p "$OUT"
cd "$CORE"

echo "== lake build parser modules =="
lake build Bitcoin.Script.Parser.Defs Bitcoin.Script.Parser.Interface

echo "== unit tests (decide, kernel-reduced) =="
lake env lean Test/Script/Parser/Tests.lean
echo "unit tests: OK"

echo "== conformance vs Core script_tests.json =="
python3 Test/Script/Parser/ref.py "$SPEC/vectors/core/script_tests.json" "$OUT"
lake env lean --run Test/Script/Parser/Conformance.lean \
  "$OUT/conf_input.txt" "$OUT/conf_expected.txt"

echo "W05 tests: all harnesses exited 0"
