#!/usr/bin/env python3
"""Behavioral C-L witness for the E1 gate cell.

This is NOT a proof.  It calls the real C and L `equiv_entry` symbols on the
exact tape and records the result pair.  The proof evidence lives in
`alive2/` and `saw/`; this script only shows the two whole-entry shims agree
on the concrete milestone witness.

Tape: one input, empty scriptSig, no witness, input 0, amount 0, flags 0.
The tx is Core TX_WITH_WITNESS serialization with no witness record.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import sys
from pathlib import Path


def make_tx() -> bytes:
    # version=1, 1 input, prevout=(0x00*32, 0), empty scriptSig,
    # sequence=0xffffffff, 1 output, value=0, empty spk, locktime=0.
    return bytes.fromhex(
        "01000000"
        "01"
        + "00" * 32
        + "00000000"
        + "00"
        + "ffffffff"
        + "01"
        + "00" * 8
        + "00"
        + "00000000"
    )


def load(path: Path):
    lib = ctypes.CDLL(str(path), mode=ctypes.RTLD_LOCAL)
    fn = lib.equiv_entry
    fn.argtypes = [
        ctypes.POINTER(ctypes.c_ubyte), ctypes.c_uint64,
        ctypes.POINTER(ctypes.c_ubyte), ctypes.c_uint64,
        ctypes.c_int64, ctypes.c_uint32, ctypes.c_uint64,
        ctypes.POINTER(ctypes.c_int),
    ]
    fn.restype = ctypes.c_int
    return fn


def call(fn, tx: bytes, spk: bytes):
    tx_buf = (ctypes.c_ubyte * len(tx)).from_buffer_copy(tx) if tx else None
    spk_buf = (ctypes.c_ubyte * len(spk)).from_buffer_copy(spk) if spk else None
    err = ctypes.c_int(-1)
    rc = fn(tx_buf, len(tx), spk_buf, len(spk), 0, 0, 0, ctypes.byref(err))
    return int(rc), int(err.value)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cell", required=True)
    ap.add_argument("--spk", required=True, help="scriptPubKey hex")
    ap.add_argument("--c-lib", required=True)
    ap.add_argument("--twin-lib", required=True)
    ap.add_argument("--expect", default="1,0")
    a = ap.parse_args()

    c_lib = Path(a.c_lib).resolve()
    l_lib = Path(a.twin_lib).resolve()
    spk = bytes.fromhex(a.spk)
    tx = make_tx()
    want = tuple(int(x) for x in a.expect.split(","))

    c_fn = load(c_lib)
    l_fn = load(l_lib)
    c_out = call(c_fn, tx, spk)
    l_out = call(l_fn, tx, spk)

    print(f"cell={a.cell}")
    print(f"witness_spk={a.spk}")
    print(f"tx_bytes={tx.hex()}")
    print("flags=0 amount=0 input_index=0 script_sig=<empty> witness_form=false")
    print(f"c_lib={c_lib} sha256={sha(c_lib)}")
    print(f"l_lib={l_lib} sha256={sha(l_lib)}")
    print(f"C=({c_out[0]},{c_out[1]})")
    print(f"L=({l_out[0]},{l_out[1]})")
    ok = c_out == l_out == want
    print(f"witness_status={'behavior-match' if ok else 'behavior-mismatch'}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
