#!/usr/bin/env python3
"""E0 three-leg tape runner (C / L / R).

Loads three shared libraries exporting the ABI v2 symbol

    int equiv_entry(const uint8_t*, uint64_t, const uint8_t*, uint64_t,
                    int64_t, uint32_t, uint64_t, int32_t*);

and runs the same tapes through each. Prints `E0_TRIPLE_OK` only when all
three legs agree with each other *and* with the expected (result, kind) for
every tape. A leg that returns the stub value (3, UNKNOWN) is reported as
STUB and prevents the OK line.

This runner does not fabricate a result: it loads and calls the real
libraries. It does not build them; pass --core-so/--twin-so/--rust-so or use
the defaults produced by the fleet.

Usage:
  python3 tools/tests/e0_triple.py [--core-so P] [--twin-so P] [--rust-so P]
"""
from __future__ import annotations

import argparse
import ctypes
import struct
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Shared taxonomy: Core ordinals at the pin.
EQUIV_ERR_OK = 0
EQUIV_ERR_UNKNOWN_ERROR = 1
EQUIV_ERR_EVAL_FALSE = 2
EQUIV_ERR_OP_RETURN = 3

RESULT_FAIL, RESULT_PASS, RESULT_BAD_INPUT, RESULT_INTERNAL = 0, 1, 2, 3


def varint(n: int) -> bytes:
    if n < 0xFD:
        return bytes([n])
    if n <= 0xFFFF:
        return b"\xfd" + struct.pack("<H", n)
    if n <= 0xFFFFFFFF:
        return b"\xfe" + struct.pack("<I", n)
    return b"\xff" + struct.pack("<Q", n)


def legacy_tx(script_sig: bytes = b"", n_in: int = 1) -> bytes:
    """A decodable non-witness transaction with `n_in` inputs.

    The tx's own outputs are irrelevant to script verification here; the
    scriptPubKey being spent is passed separately in the tape.
    """
    out = struct.pack("<i", 2) + varint(n_in)
    for i in range(n_in):
        out += b"\x00" * 32 + struct.pack("<I", 0xFFFFFFFF)
        out += varint(len(script_sig)) + script_sig
        out += struct.pack("<I", 0xFFFFFFFF)
    out += varint(1) + struct.pack("<q", 0) + varint(0)
    out += struct.pack("<I", 0)
    return out


@dataclass
class Case:
    name: str
    tx: bytes
    spk: bytes
    amount: int
    index: int
    flags: int
    want: tuple[int, int]


CASES = [
    Case("OP_1 passes", legacy_tx(), b"\x51", 0, 0, 0, (RESULT_PASS, EQUIV_ERR_OK)),
    Case("OP_0 fails", legacy_tx(), b"\x00", 0, 0, 0, (RESULT_FAIL, EQUIV_ERR_EVAL_FALSE)),
    Case("OP_RETURN fails", legacy_tx(), b"\x6a", 0, 0, 0, (RESULT_FAIL, EQUIV_ERR_OP_RETURN)),
    # A bad input: empty tx bytes is outside the domain.
    Case("empty tx is bad input", b"", b"\x51", 0, 0, 0, (RESULT_BAD_INPUT, EQUIV_ERR_UNKNOWN_ERROR)),
]


def load(path: Path):
    lib = ctypes.CDLL(str(path))
    fn = lib.equiv_entry
    fn.restype = ctypes.c_int
    fn.argtypes = [
        ctypes.POINTER(ctypes.c_uint8), ctypes.c_uint64,
        ctypes.POINTER(ctypes.c_uint8), ctypes.c_uint64,
        ctypes.c_int64, ctypes.c_uint32, ctypes.c_uint64,
        ctypes.POINTER(ctypes.c_int32),
    ]
    return fn


def call(fn, case: Case) -> tuple[int, int]:
    tb = (ctypes.c_uint8 * len(case.tx)).from_buffer_copy(case.tx) if case.tx else None
    sb = (ctypes.c_uint8 * len(case.spk)).from_buffer_copy(case.spk) if case.spk else None
    kind = ctypes.c_int32(EQUIV_ERR_UNKNOWN_ERROR)
    rc = fn(tb, len(case.tx), sb, len(case.spk), case.amount, case.index, case.flags,
            ctypes.byref(kind))
    return rc, kind.value


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--core-so", default="/tmp/opencode/cbuild/libequiv-core.so")
    ap.add_argument("--twin-so", default="/tmp/opencode/shim-build/libequiv-twin.so")
    ap.add_argument("--rust-so", default="/tmp/opencode/shim-build/libequiv_rust.so")
    args = ap.parse_args()

    legs = {"C": Path(args.core_so), "L": Path(args.twin_so), "R": Path(args.rust_so)}
    missing = [f"{k} ({v})" for k, v in legs.items() if not v.is_file()]
    if missing:
        print("E0 triple: MISSING library/binaries: " + ", ".join(missing))
        print("E0_TRIPLE_PENDING")
        return 2

    fns = {}
    for k, v in legs.items():
        try:
            fns[k] = load(v)
        except OSError as exc:
            print(f"E0 triple: cannot load {k} {v}: {exc}")
            print("E0_TRIPLE_PENDING")
            return 2

    ok = True
    stubs = set()
    for case in CASES:
        got = {k: call(fn, case) for k, fn in fns.items()}
        for k, (rc, kind) in got.items():
            if (rc, kind) == (RESULT_INTERNAL, EQUIV_ERR_UNKNOWN_ERROR):
                stubs.add(k)
        agree = len(set(got.values())) == 1
        want_ok = all(v == case.want for v in got.values())
        case_ok = agree and want_ok
        ok = ok and case_ok
        print(f"[{'PASS' if case_ok else 'FAIL'}] {case.name}: "
              + "  ".join(f"{k}=({r},{e})" for k, (r, e) in got.items())
              + f"  want={case.want}")

    if stubs:
        print(f"STUB legs (returned 3/UNKNOWN on every failing case): {', '.join(sorted(stubs))}")
    if ok and not stubs:
        print("E0_TRIPLE_OK")
        return 0
    print("E0_TRIPLE_PENDING" if stubs else "E0_TRIPLE_FAIL")
    return 1 if not stubs else 2


if __name__ == "__main__":
    sys.exit(main())
