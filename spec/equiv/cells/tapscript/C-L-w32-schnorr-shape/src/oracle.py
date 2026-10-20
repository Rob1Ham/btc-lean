#!/usr/bin/env python3
"""Independent oracle for C-L-w32-schnorr-shape (SCR-161/162).

The oracle is written from the SCR rows and interpreter.cpp:1736,1741-1744,
not from either leg.  The abstract tail verdict is an input (the shared
symbol), so scenarios with a 64/65-byte signature and a non-default
explicit hashtype expect the tail's own constant.
"""
import json
import sys

OOD = 0xFFFFFFFFFFFFFFFF

# Cell error ordinals (contract/error_kind.h).
SCHNORR_SIG_SIZE = 45
SCHNORR_SIG_HASHTYPE = 46


def pack(ok, err):
    return (ok & 1) | ((err & 0x3F) << 1)


def fail(err):
    return pack(0, err)


def elem(length, b0=0, b1=0, b2=0, b3=0, b4=0):
    return ((length & 0xFF)
            | ((b0 & 0xFF) << 8) | ((b1 & 0xFF) << 16)
            | ((b2 & 0xFF) << 24) | ((b3 & 0xFF) << 32)
            | ((b4 & 0xFF) << 40))


def expect(tail_result, sig_len, sig_last, pk_len=32):
    """checkSchnorrForInput shape prefix (RealChecker.lean:125-131)."""
    if pk_len != 32:
        return OOD                       # caller contract, out of domain
    if sig_len != 64 and sig_len != 65:
        return fail(SCHNORR_SIG_SIZE)    # interpreter.cpp:1736
    if sig_len == 65 and sig_last == 0:
        return fail(SCHNORR_SIG_HASHTYPE)  # interpreter.cpp:1741-1744
    return pack(1, 0) if tail_result == 0 else fail(tail_result)


def scenarios(tail_result):
    out = []

    def add(sig, sig_last, pk_len=32):
        sig_len = sig & 0xFF
        out.append(dict(fn="cell_schnorr_shape",
                        args=[sig, sig_last & 0xFF, pk_len & 0xFF],
                        expected=expect(tail_result, sig_len, sig_last & 0xFF,
                                        pk_len & 0xFF)))

    # SCR-161: every size outside {64, 65} is SCHNORR_SIG_SIZE (45).  The
    # payload bytes and the trailing-byte operand must not matter.
    for n in (0, 1, 2, 3, 4, 5, 6, 31, 32, 63, 66, 67, 127, 128, 255):
        add(elem(n, 0x11, 0x22, 0x33, 0x44, 0x55), 0x00)
    add(elem(63, 0xde, 0xad, 0xbe, 0xef, 0xaa), 0x41)
    add(elem(66, 0xde, 0xad, 0xbe, 0xef, 0xaa), 0x41)

    # SCR-161: 64 and 65 are in range.  A 64-byte signature uses the
    # implicit SIGHASH_DEFAULT, so sig_last is ignored entirely.
    add(elem(64, 0x00, 0x00, 0x00, 0x00, 0x00), 0x00)
    add(elem(64, 0x11, 0x22, 0x33, 0x44, 0x55), 0x00)
    add(elem(64, 0x11, 0x22, 0x33, 0x44, 0x55), 0x27)

    # SCR-162: a 65-byte signature with explicit hashtype 0x00 is rejected
    # (SIGHASH_DEFAULT is implicit only), regardless of the tail verdict.
    add(elem(65, 0x00, 0x00, 0x00, 0x00, 0x00), 0x00)
    add(elem(65, 0x11, 0x22, 0x33, 0x44, 0x55), 0x00)

    # SCR-162: any non-zero explicit hashtype reaches the tail (the tail,
    # not this cell, decides BIP341 hashtype validity).
    for last in (0x01, 0x02, 0x03, 0x41, 0x81, 0x83, 0xFF):
        add(elem(65, 0x11, 0x22, 0x33, 0x44, 0x55), last)
    return out


if __name__ == "__main__":
    tail_result = int(sys.argv[1])
    path = sys.argv[2]
    with open(path, "w") as f:
        json.dump(scenarios(tail_result), f, indent=1)
