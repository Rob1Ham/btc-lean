#!/usr/bin/env bash
# run_schnorr.sh — X02 test runner: builds the Schnorr modules and runs the
# 19-official-vector BIP340 conformance harness (compiled runtime execution
# of Schnorr.Verify.verifyImpl; kernel checks stay on the structural layer).
set -euo pipefail
CORE="$(cd "$(dirname "$0")/../../core" && pwd)"
cd "$CORE"

echo "== lake build Schnorr modules =="
lake build Bitcoin.Crypto.Schnorr.TaggedHash \
  Bitcoin.Crypto.Schnorr.Verify Bitcoin.Crypto.Schnorr.Interface

echo "== SchnorrTest (19 official BIP340 vectors through verifyImpl) =="
lake env lean --run ../Test/Crypto/SchnorrTest.lean

echo "X02 tests: harness exited 0"
