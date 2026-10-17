#!/usr/bin/env bash
# run_taproot_sighash.sh — X03 Unit-2 test runner: builds the BIP341 sighash
# module and runs the conformance harness (compiled runtime execution of
# sigMsgTaproot/sighashTaproot over the 7 official wallet-vector key-path
# cases + 3 synthetic annex/tapscript cases + 2 rejects), then the
# independent hashlib crosscheck of every embedded literal.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT/core"

echo "== lake build Taproot.Sighash =="
lake build Bitcoin.Crypto.Taproot.Sighash

echo "== TaprootSighashTest (7 official + 3 synthetic + 2 rejects) =="
lake env lean --run ../Test/Crypto/TaprootSighashTest.lean

echo "== crosscheck (independent hashlib mirror re-derives every literal) =="
python3 ../Test/Crypto/taproot_sighash_crosscheck.py

echo "X03 Unit-2 tests: harness + crosscheck exited 0"
