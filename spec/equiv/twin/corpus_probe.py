#!/usr/bin/env python3
"""twin/corpus_probe.py -- run the stack-family selection through the twin.

Builds `build/twin.cpp` + `build/libtwin.so` from the current generator, then
assembles a `TX_WITH_WITNESS` tape for every `corpus/selections/stack.jsonl`
row (script text -> bytes via Core's parser reference, read-only) and calls
the normative `equiv_entry`.

This is a *Core-corpus differential* (the corpus `expected` field is Core's
verdict at the pin), not the Lean differential: no Lean tape runner exists.
Rows that return result 3 are outside the twin subset and are excluded from
the comparison; every in-domain row is compared against `expected`.

Usage:
    python3 twin/corpus_probe.py [--json PATH] [--no-build] [--limit N]

Exit: 0 every in-domain row matched; 1 a mismatch or build failure.
"""

from __future__ import annotations

import argparse
import ctypes
import json
import os
import re
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
EQUIV = HERE.parent
SPEC = EQUIV.parent
CONTRACT = EQUIV / "contract" / "error_kind.h"
SELECTION = EQUIV / "corpus" / "selections" / "stack.jsonl"
BUILD = HERE / "build"
GEN = BUILD / "twin.cpp"
LIB = BUILD / "libtwin.so"

FLAGS = {
    "P2SH": 0x000001,
    "STRICTENC": 0x000002,
    "DERSIG": 0x000004,
    "LOW_S": 0x000008,
    "NULLDUMMY": 0x000010,
    "SIGPUSHONLY": 0x000020,
    "MINIMALDATA": 0x000040,
    "DISCOURAGE_UPGRADABLE_NOPS": 0x000080,
    "CLEANSTACK": 0x000100,
    "CHECKLOCKTIMEVERIFY": 0x000200,
    "CHECKSEQUENCEVERIFY": 0x000400,
    "WITNESS": 0x000800,
    "DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM": 0x001000,
    "MINIMALIF": 0x002000,
    "NULLFAIL": 0x004000,
    "WITNESS_PUBKEYTYPE": 0x008000,
    "CONST_SCRIPTCODE": 0x010000,
    "TAPROOT": 0x020000,
    "DISCOURAGE_UPGRADABLE_TAPROOT_VERSION": 0x040000,
    "DISCOURAGE_OP_SUCCESS": 0x080000,
    "DISCOURAGE_UPGRADABLE_PUBKEYTYPE": 0x100000,
}

UNSUPPORTED_WIRES = {
    0xAC: "CHECKSIG", 0xAD: "CHECKSIGVERIFY",
    0xAE: "CHECKMULTISIG", 0xAF: "CHECKMULTISIGVERIFY",
    0xBA: "CHECKSIGADD",
    0xA7: "SHA1",
    0xB1: "CHECKLOCKTIMEVERIFY", 0xB2: "CHECKSEQUENCEVERIFY",
}


def core_values() -> dict[str, int]:
    text = CONTRACT.read_text(encoding="utf-8")
    return {m.group(1): int(m.group(2))
            for m in re.finditer(r"EQUIV_ERR_([A-Z0-9_]+)\s*=\s*(\d+)", text)}


def load_ref():
    sys.path.insert(0, str(SPEC / "core" / "Test" / "Script" / "Parser"))
    import ref  # type: ignore
    return ref


def cs(n: int) -> bytes:
    if n < 0xFD:
        return bytes([n])
    if n <= 0xFFFF:
        return b"\xfd" + n.to_bytes(2, "little")
    if n <= 0xFFFFFFFF:
        return b"\xfe" + n.to_bytes(4, "little")
    return b"\xff" + n.to_bytes(8, "little")


def make_tx(ss: bytes, witness_items: list[bytes] | None = None) -> bytes:
    out = (2).to_bytes(4, "little", signed=True)
    if witness_items is not None:
        out += b"\x00\x01"
    out += cs(1)
    out += b"\x00" * 32 + b"\xff" * 4
    out += cs(len(ss)) + ss + b"\xff" * 4
    out += cs(1) + (0).to_bytes(8, "little", signed=True) + cs(0)
    if witness_items is not None:
        out += cs(len(witness_items))
        for item in witness_items:
            out += cs(len(item)) + item
    out += (0).to_bytes(4, "little")
    return out


def flag_bits(text: str) -> int:
    bits = 0
    for tok in text.split(","):
        tok = tok.strip()
        if tok:
            bits |= FLAGS[tok]
    return bits


def build() -> None:
    BUILD.mkdir(parents=True, exist_ok=True)
    subprocess.check_call([sys.executable, str(HERE / "gen.py"),
                           "--out", str(GEN)])
    cxx = os.environ.get("CXX", "")
    if not cxx:
        cxx = "clang++-20" if shutil.which("clang++-20") else "clang++"
    cmd = [cxx, "-std=c++17", "-O0", "-fPIC", "-shared",
           "-fno-strict-aliasing", "-Wall", "-Wextra",
           "-I", str(EQUIV / "contract"), str(GEN), "-o", str(LIB)]
    subprocess.check_call(cmd)


def wire_ops(script: bytes) -> list[int]:
    """Opcode bytes after pushes (structural walk; unexecuted branches included)."""
    ops: list[int] = []
    i, n = 0, len(script)
    while i < n:
        op = script[i]
        i += 1
        if op <= 0x4E:
            if op < 0x4C:
                k = op
            elif op == 0x4C:
                if i >= n:
                    break
                k = script[i]
                i += 1
            elif op == 0x4D:
                if i + 1 >= n:
                    break
                k = script[i] | (script[i + 1] << 8)
                i += 2
            else:
                if i + 3 >= n:
                    break
                k = int.from_bytes(script[i:i + 4], "little")
                i += 4
            i += k
        elif op != 0x4F and not (0x51 <= op <= 0x60):
            ops.append(op)
    return ops


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", metavar="PATH")
    ap.add_argument("--no-build", action="store_true")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args(argv)

    if not args.no_build:
        build()
    elif not LIB.exists():
        print(f"missing {LIB}; run without --no-build", file=sys.stderr)
        return 1

    ref = load_ref()
    vals = core_values()
    lib = ctypes.CDLL(str(LIB))
    lib.equiv_entry.restype = ctypes.c_int
    lib.equiv_entry.argtypes = [
        ctypes.c_char_p, ctypes.c_uint64, ctypes.c_char_p, ctypes.c_uint64,
        ctypes.c_int64, ctypes.c_uint32, ctypes.c_uint64,
        ctypes.POINTER(ctypes.c_int),
    ]

    rows = [json.loads(line) for line in SELECTION.read_text().splitlines() if line]
    if args.limit:
        rows = rows[: args.limit]

    counts: Counter = Counter()
    unsigned: Counter = Counter()
    mismatches = []
    tapes = []

    for row in rows:
        try:
            ss = ref.parse_script(row["script_sig"])
            spk = ref.parse_script(row["script_pubkey"])
        except Exception as exc:  # noqa: BLE001
            counts["parse_fail"] += 1
            mismatches.append({"source_index": row["source_index"],
                               "kind": "parse_fail", "error": str(exc)})
            continue
        if row["witness_form"]:
            counts["unbuildable_witness"] += 1
            continue
        bits = flag_bits(row["flags"])
        tape = make_tx(ss)
        kind = ctypes.c_int(-1)
        rc = lib.equiv_entry(tape, len(tape), spk, len(spk), 0, 0, bits,
                             ctypes.byref(kind))
        expected = row["expected"]
        exp_rc = 1 if expected == "OK" else 0
        exp_err = vals["OK"] if expected == "OK" else vals[expected]
        ss_kind = "empty" if len(ss) == 0 else "nonempty"
        flag_kind = "flags" if row["flags"] else "noflags"
        counts["total"] += 1
        counts[("sig", ss_kind, flag_kind)] += 1
        if rc == 3:
            counts["out_result3"] += 1
            counts[("out", ss_kind, flag_kind)] += 1
            for op in set(wire_ops(ss) + wire_ops(spk)):
                if op in UNSUPPORTED_WIRES:
                    unsigned[UNSUPPORTED_WIRES[op]] += 1
        else:
            counts["in_domain"] += 1
            counts[("in", ss_kind, flag_kind)] += 1
            if (rc, kind.value) == (exp_rc, exp_err):
                counts["match"] += 1
            else:
                counts["mismatch"] += 1
                mismatches.append({
                    "source_index": row["source_index"],
                    "expected": expected,
                    "got": [rc, kind.value],
                    "flags": row["flags"],
                    "script_sig": row["script_sig"],
                    "script_pubkey": row["script_pubkey"],
                })
        tapes.append({"source_index": row["source_index"],
                      "tx_hex": tape.hex(), "spk_hex": spk.hex(),
                      "flags": bits, "expected": expected,
                      "result": rc, "error_kind": kind.value})

    if not args.no_build:
        tape_path = BUILD / "stack_tapes.jsonl"
        tape_path.write_text("".join(json.dumps(t) + "\n" for t in tapes))
    report = {
        "selection": str(SELECTION),
        "rows": len(rows),
        "counts": {str(k): v for k, v in counts.items()},
        "unsupported_opcode_rows": dict(unsigned),
        "mismatches": mismatches,
    }
    if args.json:
        Path(args.json).write_text(json.dumps(report, indent=2) + "\n")

    print(f"rows={len(rows)}")
    print(f"in_domain={counts['in_domain']} out_result3={counts['out_result3']} "
          f"match={counts['match']} mismatch={counts['mismatch']}")
    for k in [("in", "empty", "flags"), ("in", "nonempty", "flags"),
              ("in", "empty", "noflags"), ("in", "nonempty", "noflags"),
              ("out", "empty", "flags"), ("out", "nonempty", "flags"),
              ("out", "empty", "noflags"), ("out", "nonempty", "noflags")]:
        print(f"  {k[0]:3} ss={k[1]:8} {k[2]:7}: {counts[k]}")
    print("unsupported opcode rows (structural):",
          ", ".join(f"{k}={v}" for k, v in sorted(unsigned.items())) or "none")
    if mismatches:
        print(f"MISMATCHES ({len(mismatches)}):")
        for m in mismatches[:10]:
            print(" ", m)
        return 1
    print("corpus differential: PASS (all in-domain rows match Core corpus)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
