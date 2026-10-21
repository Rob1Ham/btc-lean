#!/usr/bin/env python3
"""Out-of-corpus probe for F-DIV-001 (Lean eager parse vs Core streaming GetOp).

The pinned ``script_tests.json`` contains no malformed-tail script, so the
1258-row differential cannot exercise F-DIV-001.  This probe builds the two
tapes named in that finding, runs the C leg, and prints its verdict.  There
is **no L verdict** for these tapes in ``tierC.l2r``; the Lean side remains a
code-reading prediction and must not be presented as executed.

Usage: python3 spec/equiv/differential/probe_fdiv001.py [--core-lib PATH]
"""

from __future__ import annotations

import argparse
import os
import sys

import run as harness

CASES = [
    ("OP_VERIFY + truncated PUSH2", "690201"),
    ("disabled OP_CAT + truncated PUSH2", "7e0201"),
]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--core-lib", default=harness.DEFAULT_CORE_LIB)
    args = ap.parse_args()

    if not os.path.isfile(args.core_lib):
        print(f"C leg library not found: {args.core_lib}", file=sys.stderr)
        return 2
    name_to_value, value_to_name = harness.load_error_names(
        os.path.join(harness.EQUIV, "contract/error_kind.h")
    )
    c_leg = harness.CLeg(args.core_lib)
    print(f"# C leg: {args.core_lib} sha256 {c_leg.sha256}")
    print("# No L verdict exists for these tapes; F-DIV-001's Lean side is a")
    print("# code-reading prediction only (BAD_OPCODE / value 16).")
    for label, spk_hex in CASES:
        spk = bytes.fromhex(spk_hex)
        script_sig = b""
        witness: list[bytes] = []
        amount = 0
        flags = 0
        tape = harness.build_tape(spk, script_sig, witness, amount)
        result, kind = c_leg.call(tape, spk, amount, flags)
        print(
            f"{label}: spk={spk_hex} "
            f"tape_sha256={harness.sha256_bytes(tape)} "
            f"C=({result},{value_to_name.get(kind, kind)}) "
            f"C_error_value={kind}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
