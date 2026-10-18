#!/usr/bin/env bash
# run.sh — legacy/BIP143 sighash test runner (mirrors spec/Test/Crypto/run.sh):
#  1. elaborates the generated harness — every native_decide example is a
#     build-time-verified conformance vector (52 legacy corpus rows + 1
#     synthetic legacy SINGLE-overflow + 7 BIP143 worked examples);
#  2. runs crosscheck.py — independently re-derives every emitted vector
#     from the raw corpora through the hashlib-based Python mirror.
set -euo pipefail
SPEC="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$SPEC/core"

echo "== build sighash modules =="
lake build Bitcoin.SigHash.Interface Bitcoin.SigHash.Digest Bitcoin.SigHash.Ops

echo "== sighash harness elaboration (native_decide checks fire here) =="
lake env lean "$SPEC/Test/Sighash/SighashTest.lean"

echo "== independent python crosscheck =="
python3 "$SPEC/Test/Sighash/crosscheck.py"

echo "sighash tests: OK"
