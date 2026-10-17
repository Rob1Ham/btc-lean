#!/usr/bin/env bash
# run_taproot_program.sh — X06 test runner: builds the Taproot program /
# output-key / activation modules and runs the BIP341 wallet-vector
# conformance harness (compiled runtime execution of the X06 rule-row
# layer over X02 liftX/taggedHash + X03 taptweak/tweakPoint).
set -euo pipefail
CORE="$(cd "$(dirname "$0")/../../core" && pwd)"
cd "$CORE"

echo "== lake build Taproot modules =="
lake build Bitcoin.Crypto.Taproot.Program \
  Bitcoin.Crypto.Taproot.OutputKey Bitcoin.Activation.Taproot

echo "== TaprootProgramTest (BIP341 wallet vectors + synthetic annex/control cases) =="
lake env lean --run ../Test/Crypto/TaprootProgramTest.lean

echo "X06 tests: harness exited 0"
