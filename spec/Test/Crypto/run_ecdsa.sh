#!/usr/bin/env bash
# run_ecdsa.sh — ECDSA-lax test runner: builds the Curve/Ecdsa modules and runs
# the 215-vector ECDSA-lax conformance harness (compiled runtime execution
# of verifyLax; kernel checks only on the structural Der layer).
set -euo pipefail
CORE="$(cd "$(dirname "$0")/../../core" && pwd)"
cd "$CORE"

echo "== lake build Curve/Ecdsa modules =="
lake build Bitcoin.Crypto.Curve.Mod Bitcoin.Crypto.Curve.Secp \
  Bitcoin.Crypto.Curve.Interface Bitcoin.Crypto.Ecdsa.Der \
  Bitcoin.Crypto.Ecdsa.Verify Bitcoin.Crypto.Ecdsa.Interface

echo "== EcdsaTest (215 conformance vectors through verifyLax) =="
lake env lean --run ../Test/Crypto/EcdsaTest.lean

echo "ECDSA-lax tests: harness exited 0"
