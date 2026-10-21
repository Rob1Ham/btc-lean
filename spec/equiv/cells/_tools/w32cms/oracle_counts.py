#!/usr/bin/env python3
"""Independent scenario oracle for the SCR-114 counts cell.

Models the CHECKMULTISIG argument prelude from the rule text and Core
interpreter.cpp:1122-1146 (CScriptNum width 4, MAX_PUBKEYS_PER_MULTISIG 20,
MAX_OPS_PER_SCRIPT 201).  Emits packed expected observables for SAW; the
implementation is written from the spec, not from the C/L cell sources.

usage: oracle_counts.py <out.json> [checker]
"""
import json
import sys

EV = 18   # EQUIV_ERR_INVALID_STACK_OPERATION
SN = 4    # EQUIV_ERR_SCRIPTNUM
PK = 10   # EQUIV_ERR_PUBKEY_COUNT
OP = 7    # EQUIV_ERR_OP_COUNT
SG = 9    # EQUIV_ERR_SIG_COUNT
MAX_KEYS = 20
MAX_OPS = 201


def elem(ln, *bs):
    v = ln & 0xFF
    for i, b in enumerate(bs):
        v |= (b & 0xFF) << (8 + 8 * i)
    return v


def dec(enc):
    ln = enc & 0xFF
    bs = [(enc >> (8 + 8 * i)) & 0xFF for i in range(5)]
    if ln > 4:
        return None
    if ln == 0:
        return 0
    v = sum(bs[i] << (8 * i) for i in range(ln))
    if bs[ln - 1] & 0x80:
        return -(v & ~(0x80 << (8 * (ln - 1))))
    return v


def top(k, n, keys_enc, sigs_enc):
    if k > n:
        return elem(1, 0)
    if k == 1:
        return keys_enc
    nk = dec(keys_enc)
    if nk is not None and nk >= 0 and k == nk + 2:
        return sigs_enc
    return elem(1, 0)


def pack(res, err, f1=0, f2=0, f3=0, f4=0):
    return ((res & 1) | ((err & 0x3F) << 2) | ((f1 & 0xFF) << 8) |
            ((f2 & 0xFF) << 16) | ((f3 & 0xFF) << 24) | ((f4 & 0xFF) << 32))


def run(n, keys_enc, sigs_enc, ops):
    if n < 1:
        return pack(0, EV)
    nk = dec(keys_enc)
    if nk is None:
        return pack(0, SN)
    if nk < 0 or nk > MAX_KEYS:
        return pack(0, PK)
    op = ops + nk
    if op > MAX_OPS:
        return pack(0, OP)
    if n < nk + 2:
        return pack(0, EV)
    ns = dec(top(nk + 2, n, keys_enc, sigs_enc))
    if ns is None:
        return pack(0, SN)
    if ns < 0 or ns > nk:
        return pack(0, SG)
    if n < nk + ns + 3:
        return pack(0, EV)
    return pack(1, 0, nk, ns, op, n)


CASES = []


def case(n, keys_enc, sigs_enc, ops):
    CASES.append({"fn": "cell_cms_counts",
                  "args": [n, keys_enc, sigs_enc, ops],
                  "expected": run(n, keys_enc, sigs_enc, ops)})


ZERO1 = elem(1, 0)
ONE1 = elem(1, 1)
NEG1 = elem(1, 0x81)
# depth arms
case(0, ONE1, ONE1, 0)                       # INVALID_STACK_OPERATION (first)
case(1, ZERO1, ZERO1, 0)                     # nKeys=0, needs 3 -> EV
case(2, ZERO1, ZERO1, 0)                     # EV
case(3, ZERO1, ZERO1, 0)                     # success 0-of-0
# nKeys decode / range
case(5, elem(5, 0, 0, 0, 0, 0), ONE1, 0)     # SCRIPTNUM (len 5 > 4)
case(5, NEG1, ONE1, 0)                       # PUBKEY_COUNT (nKeys -1)
case(5, elem(1, 21), ONE1, 0)                # PUBKEY_COUNT (nKeys 21)
case(5, elem(4, 0xFF, 0xFF, 0xFF, 0xFF), ONE1, 0)  # -2147483647 -> PUBKEY_COUNT
case(5, elem(2, 0x00, 0x80), ONE1, 0)        # negative zero -> nKeys 0
# opCount
case(5, elem(1, 20), ONE1, 181)              # 201 -> pass
case(5, elem(1, 20), ONE1, 182)              # 202 -> OP_COUNT
case(5, elem(1, 20), ONE1, 255)              # OP_COUNT
# second depth check and nSigs decode/range
case(21, elem(1, 20), ONE1, 0)               # n < 22 -> EV
case(22, elem(1, 20), elem(5, 0, 0, 0, 0, 0), 0)   # sigs len5 -> SCRIPTNUM
case(22, elem(1, 20), NEG1, 0)               # nSigs -1 -> SIG_COUNT
case(22, elem(1, 20), elem(1, 21), 0)        # nSigs 21 > nKeys -> SIG_COUNT
case(24, elem(1, 20), elem(1, 20), 0)        # 24 < 43 -> EV (third depth)
case(43, elem(1, 20), elem(1, 20), 0)        # success 20-of-20
case(43, elem(1, 20), elem(1, 20), 182)      # opCount 202 -> OP_COUNT
# third depth check
case(22, elem(1, 20), elem(1, 1), 0)         # 22 < 24 -> EV
case(23, elem(1, 4), elem(1, 3), 0)          # 23 < 24 -> EV
case(24, elem(1, 4), elem(1, 3), 0)          # success 4-of-3
case(28, elem(1, 4), elem(1, 3), 197)        # opCount 201 -> success
case(28, elem(1, 4), elem(1, 3), 198)        # opCount 202 -> OP_COUNT
# 4-byte largest in-range counts, minimal width boundary
case(45, elem(4, 20, 0, 0, 0), elem(4, 20, 0, 0, 0), 0)  # success (non-minimal)
# one-byte 0x80 (negative zero) nSigs -> 0
case(22, elem(1, 20), elem(1, 0x80), 0)      # nSigs 0, n=22 >=23? 22<23 -> EV
case(23, elem(1, 20), elem(1, 0x80), 0)      # success 20-of-0


def main():
    out = sys.argv[1]
    with open(out, "w") as f:
        json.dump(CASES, f, indent=1)
    errs = sorted({(c["expected"] >> 2) & 0x3F for c in CASES})
    print("expected error ordinals covered:", errs)


if __name__ == "__main__":
    main()
