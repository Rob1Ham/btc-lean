#!/usr/bin/env bash
# run.sh — W12 test runner: builds the Ledger module as a lake target,
# then runs the harness via `lake env lean --run`.
set -euo pipefail
CORE="$(cd "$(dirname "$0")/../../core" && pwd)"
cd "$CORE"

echo "== lake build Ledger module =="
lake build Bitcoin.Ledger.Interface

echo "== LedgerTest =="
lake env lean --run ../Test/Ledger/Tests.lean

echo "W12 tests: harness exited 0"
