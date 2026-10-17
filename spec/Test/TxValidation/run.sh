#!/usr/bin/env bash
# run.sh — W10 test runner: TxValidation conformance vectors (build-time
# `decide` examples; mirrors the W12/W13 spec/Test layout).
#
# Tests.lean      — pure vectors (needs only TxValidation + DataLaws)
# LedgerCross.lean — TXV-042 cross-check vs Bitcoin.Ledger.MEMPOOL_HEIGHT
#                    (needs the Ledger interface module, W12-owned)
set -euo pipefail
CORE="$(cd "$(dirname "$0")/../../core" && pwd)"
cd "$CORE"

echo "== lake build TxValidation module =="
lake build Bitcoin.TxValidation.Interface

echo "== Tests.lean =="
lake env lean ../Test/TxValidation/Tests.lean

echo "== LedgerCross.lean =="
lake env lean ../Test/TxValidation/LedgerCross.lean

echo "== LocktimeVec.lean (X09: CLTV/CSV tx-side, sigops, exact-weight) =="
lake env lean ../Test/TxValidation/LocktimeVec.lean

echo "W10 tests: all vector files elaborated clean"
