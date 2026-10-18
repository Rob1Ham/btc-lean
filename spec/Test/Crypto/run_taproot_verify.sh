#!/usr/bin/env bash
# run_taproot_verify.sh — BIP341 output/script-path test runner: builds the BIP341
# taproot-verify module and runs the conformance harness (compiled runtime
# execution of p2trOutput/treeMerkleRoot over ALL 7 official wallet-vector
# scriptPubKey-section output cases + 4 synthetic script-path control-block
# verdicts), then the independent pure-python secp256k1 crosscheck.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT/core"

echo "== lake build Taproot.Verify =="
lake build Bitcoin.Crypto.Taproot.Verify

echo "== TaprootVerifyTest (7 official output cases + 4 synthetic script-path verdicts) =="
lake env lean --run ../Test/Crypto/TaprootVerifyTest.lean

echo "== crosscheck (independent pure-python secp256k1 mirror) =="
python3 ../Test/Crypto/taproot_verify_crosscheck.py

echo "BIP341 output/script-path tests: harness + crosscheck exited 0"
