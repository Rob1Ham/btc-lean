#!/usr/bin/env bash
# run.sh — W09 test runner: script interpreter unit tests.
#
# Tests.lean — decide/native_decide vectors for the interpreter core:
#   hash defs (FIPS/Dobbertin vectors on the real ByteArray path),
#   opcode semantics, signature-encoding layers, CLTV/CSV gates,
#   end-to-end VerifyScript (P2SH/P2WPKH/P2WSH with the stub checker),
#   STACK_SIZE theorem instances, and axiom pins for the theorem
#   portfolio (mirrored in scripts/axiom_probe.lean / the manifest).
set -euo pipefail
CORE="$(cd "$(dirname "$0")/../../../core" && pwd)"
cd "$CORE"

echo "== lake build interpreter modules =="
lake build Bitcoin.Interpreter.Interface

echo "== Tests.lean =="
lake env lean ../Test/Script/Interpreter/Tests.lean

echo "W09 tests: vector file elaborated clean"
