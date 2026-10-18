#!/usr/bin/env bash
# run.sh — parser unit tests + script_tests.json conformance.
#
# Chain: ref.py (Python port of Core ParseScript + GetScriptOp @ cce32b168)
#       -> /tmp conf_input.txt + conf_expected.txt
#       Conformance.lean (Lean parseFrom) -> per-line diff + roundtrip axis.
# Corpus: the hash-pinned spec/data/core/script_tests.json.
set -euo pipefail
CORE="$(cd "$(dirname "$0")/../../.." && pwd)"
SPEC="$(cd "$CORE/.." && pwd)"
OUT=build/parser-conformance
mkdir -p "$OUT"
cd "$CORE"

echo "== lake build parser modules =="
lake build Bitcoin.Script.Parser.Defs Bitcoin.Script.Parser.Interface

echo "== unit tests (decide, kernel-reduced) =="
lake env lean Test/Script/Parser/Tests.lean
echo "unit tests: OK"

echo "== conformance vs Core script_tests.json =="
CORPUS="$SPEC/data/core/script_tests.json"
if [ -f "$SPEC/vectors/core/script_tests.json" ]; then
  CORPUS="$SPEC/vectors/core/script_tests.json"
fi
python3 Test/Script/Parser/ref.py "$CORPUS" "$OUT"
lake env lean --run Test/Script/Parser/Conformance.lean \
  "$OUT/conf_input.txt" "$OUT/conf_expected.txt"

echo "parser tests: all harnesses exited 0"
