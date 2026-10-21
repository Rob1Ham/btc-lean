#!/usr/bin/env bash
# SCR-001 CVE-2010-5141 witness on the PINNED Core IR.
#
# Four singleton VerifyScript executions on the real, pinned Core parser +
# interpreter module.  Each one fixes a concrete scriptSig whose final push
# declares more payload bytes than the scriptSig buffer contains:
#
#   w01  scriptSig {0x01},           scriptPubKey {0x51} OP_1
#   w02  scriptSig {0x01},           scriptPubKey {0x76} OP_DUP
#   w03  scriptSig {0x01},           scriptPubKey {0x6a} OP_RETURN
#   w04  scriptSig {0x4e ff ff ff ff}, scriptPubKey {0x51} OP_1
#
# All four must return false with SCRIPT_ERR_BAD_OPCODE (16).  w02/w03 show
# that the scriptPubKey is not evaluated at all (OP_DUP would report 18,
# OP_RETURN 3); w04 shows the same decision for the PUSHDATA4 encoding.
#
# This is a CONCRETE witness, not a universal proof: it inherits the probe
# module's transforms (exception erasure, internalization to the five-symbol
# API, ABI-global stubs, __cxa_guard pinned to 1).  The universal half of the
# row is the separate C-L cell.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MODULE="${SCR001_CORE_IR:-/tmp/opencode/wave16b/02-e5-getscriptop/spec/equiv/cells/e5-whole/PROTO-w16b-getscriptop/build/out/interp-script-roots3.bc}"
EXPECT_SHA=2795c02ea67c77ff3674d16da074b1f8b884861fc6f157b6274feba9d8227ae1
SAW=/opt/equiv-tools/saw-1.6/bin/saw

test -f "$MODULE" || { echo "missing module: $MODULE" >&2; exit 1; }
GOT_SHA="$(sha256sum "$MODULE" | cut -d' ' -f1)"
test "$GOT_SHA" = "$EXPECT_SHA" || {
  echo "module hash mismatch: $GOT_SHA != $EXPECT_SHA" >&2; exit 1; }

RES="$HERE/result.txt"
{
  echo "# SCR-001 real-Core witness"
  echo "# saw: $("$SAW" --version 2>&1 | head -1)"
  echo "# module: $MODULE"
  echo "# module-sha256: $GOT_SHA"
  echo "# env override: SCR001_CORE_IR"
  OK=1
  for spec in "$HERE"/w0*.saw; do
    echo
    echo "===== $(basename "$spec") ====="
    out="$("$SAW" "$spec" 2>&1 || true)"
    printf '%s\n' "$out"
    printf '%s' "$out" | grep -q '^Proof succeeded!' || OK=0
  done
  echo
  if [ "$OK" -eq 1 ]; then
    echo "STATUS=core-witness-green"
  else
    echo "STATUS=core-witness-not-green"
  fi
} > "$RES" 2>&1

grep -q 'STATUS=core-witness-green' "$RES"
