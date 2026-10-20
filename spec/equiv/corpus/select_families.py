#!/usr/bin/env python3
"""Derive per-family selections from the pinned script_tests corpus.

Read-only over spec/data/core/script_tests.json. Emits one JSONL per family
with the source row, its raw sha256, and the mnemonics that matched. It does
NOT invent expectations: `expected` is copied verbatim from the corpus.

Usage: python3 corpus/select_families.py [--out corpus/selections]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
CORPUS = os.path.join(ROOT, "spec/data/core/script_tests.json")

# Opcode mnemonics per family. A row may match several families; that is
# intentional (the cell ledger decides coverage, not this script).
FAMILIES: dict[str, set[str]] = {
    "stack": {
        "DUP", "DROP", "SWAP", "ROT", "TOALTSTACK", "FROMALTSTACK", "2DROP",
        "2DUP", "3DUP", "2OVER", "2ROT", "2SWAP", "IFDUP", "DEPTH", "PICK",
        "ROLL", "TUCK", "NIP", "OVER",
    },
    "flow": {"IF", "NOTIF", "ELSE", "ENDIF", "VERIFY", "RETURN"},
    "numeric": {
        "1ADD", "1SUB", "NEGATE", "ABS", "NOT", "0NOTEQUAL", "ADD", "SUB",
        "BOOLAND", "BOOLOR", "NUMEQUAL", "NUMEQUALVERIFY", "NUMNOTEQUAL",
        "LESSTHAN", "GREATERTHAN", "LESSTHANOREQUAL", "GREATERTHANOREQUAL",
        "MIN", "MAX", "WITHIN",
    },
    "hash": {"RIPEMD160", "SHA1", "SHA256", "HASH160", "HASH256"},
    "checksig": {"CHECKSIG", "CHECKSIGVERIFY", "CODESEPARATOR"},
    "cms": {"CHECKMULTISIG", "CHECKMULTISIGVERIFY"},
    "locktime": {"CHECKLOCKTIMEVERIFY", "CHECKSEQUENCEVERIFY", "CLTV", "CSV"},
    "disabled": {
        "CAT", "SUBSTR", "LEFT", "RIGHT", "INVERT", "AND", "OR", "XOR",
        "2MUL", "2DIV", "MUL", "DIV", "MOD", "LSHIFT", "RSHIFT",
    },
}

WITNESS_FLAGS = ("WITNESS", "TAPROOT")


def is_case(entry) -> bool:
    if not isinstance(entry, list) or len(entry) < 3:
        return False
    return not (len(entry) == 1 and isinstance(entry[0], str))


def split_entry(entry):
    """Return (witness_form, script_sig, script_pubkey, flags, expected)."""
    if isinstance(entry[0], list):
        return True, entry[1], entry[2], entry[3], entry[4] if len(entry) > 4 else None
    return False, entry[0], entry[1], entry[2], entry[3] if len(entry) > 3 else None


def tokens(script: str) -> set[str]:
    out = set()
    for tok in str(script).replace("(", " ").replace(")", " ").split():
        t = tok.strip("'\",;").upper()
        if t:
            out.add(t)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="corpus/selections")
    args = ap.parse_args()
    outdir = args.out if os.path.isabs(args.out) else os.path.join(
        os.path.dirname(__file__), os.path.basename(args.out))
    os.makedirs(outdir, exist_ok=True)

    data = json.load(open(CORPUS, encoding="utf-8"))
    rows = []
    for idx, entry in enumerate(data):
        if not is_case(entry):
            continue
        wit, ss, spk, flags, expected = split_entry(entry)
        ops = tokens(ss) | tokens(spk)
        raw = json.dumps(entry, sort_keys=True, separators=(",", ":")).encode()
        rows.append({
            "source_index": idx,
            "witness_form": wit,
            "script_sig": ss,
            "script_pubkey": spk,
            "flags": flags,
            "expected": expected,
            "ops": sorted(ops),
            "row_sha256": hashlib.sha256(raw).hexdigest(),
        })

    summary = []
    for fam, names in FAMILIES.items():
        sel = [r for r in rows if names & set(r["ops"])]
        path = os.path.join(outdir, f"{fam}.jsonl")
        with open(path, "w", encoding="utf-8") as fh:
            for r in sel:
                fh.write(json.dumps(r, sort_keys=True) + "\n")
        summary.append((fam, len(sel), path))

    # witness/taproot are flag selections, not mnemonic selections
    for fam, flag in (("witness", "WITNESS"), ("taproot", "TAPROOT")):
        sel = [r for r in rows if flag in str(r["flags"])]
        path = os.path.join(outdir, f"{fam}.jsonl")
        with open(path, "w", encoding="utf-8") as fh:
            for r in sel:
                fh.write(json.dumps(r, sort_keys=True) + "\n")
        summary.append((fam, len(sel), path))

    total = len(rows)
    with open(os.path.join(outdir, "SUMMARY.md"), "w", encoding="utf-8") as fh:
        fh.write("# Derived family selections\n\n")
        fh.write(f"Source: `spec/data/core/script_tests.json` "
                 f"({total} case-like rows; 1258 expected).\n\n")
        fh.write("| Family | Rows | File |\n|---|---:|---|\n")
        for fam, n, path in summary:
            fh.write(f"| {fam} | {n} | `{os.path.basename(path)}` |\n")
        fh.write("\nRows may appear in several families. Expectations are "
                 "copied verbatim from the corpus; this script invents none.\n")

    for fam, n, path in summary:
        print(f"{fam:10s} {n:5d}  {path}")
    print(f"{'total':10s} {total:5d}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
