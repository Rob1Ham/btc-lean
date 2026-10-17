#!/usr/bin/env bash
# run.sh — W06 test runner: builds the Activation modules as lake module
# targets, then runs both harnesses via `lake env lean --run`.
set -euo pipefail
CORE="$(cd "$(dirname "$0")/../../core" && pwd)"
cd "$CORE"

echo "== lake build Activation modules =="
lake build Bitcoin.Activation.Interface Bitcoin.Activation.Flags Bitcoin.Activation.Bip9

echo "== FlagsTest =="
lake env lean --run ../Test/Activation/FlagsTest.lean

echo "== Bip9Test =="
lake env lean --run ../Test/Activation/Bip9Test.lean

echo "W06 tests: all harnesses exited 0"
