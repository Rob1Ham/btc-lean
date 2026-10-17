#!/usr/bin/env bash
# run_map.sh — X13 U1 runner: HashMap-backed UtxoSet instance scenarios
# (mirrors W12's Test/Ledger/run.sh; same fixtures, HashMap execution).
set -euo pipefail
CORE="$(cd "$(dirname "$0")/../../core" && pwd)"
cd "$CORE"

echo "== lake build Ledger.HashMap module =="
lake build Bitcoin.Ledger.HashMap

echo "== HashMapTests =="
lake env lean --run ../Test/Ledger/HashMapTests.lean

echo "X13 HashMap tests: harness exited 0"
