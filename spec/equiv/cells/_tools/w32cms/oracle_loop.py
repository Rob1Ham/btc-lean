#!/usr/bin/env python3
"""Independent scenario oracle for the SCR-116/117 CMS loop cell.

Models, from the rule text and the Lean equations:
  * the CMS stack layout [dummy, sigs..., nSigs, keys..., nKeys]
    with one-byte positional signature/pubkey kinds (see e32_common.h);
  * CheckSignatureEncoding (DER gate, LOW_S, defined hashtype);
  * CheckPubKeyEncoding (STRICTENC, WITNESS_PUBKEYTYPE under witness v0);
  * the ordered while loop and the "more sigs than keys left" early exit;
  * the cleanup, dummy pop, bool push and CMSVERIFY ordinal.
The cell checker is the concrete predicate:
  ((siglen*31 + sig[0]*7 + pklen*13 + pk[0]*3 + salt) & 7) == 0.

usage: oracle_loop.py <out.json> [checker]
"""
import json
import sys

DER = 24
HIGHS = 27
HASHTYPE = 23
PUBKEYTYPE = 29
WITPUBKEYTYPE = 44
EVAL_FALSE = 2
CMSVERIFY = 13

F_DERSIG, F_STRICTENC, F_LOW_S, F_WITPUB, F_WITNESS_V0, F_VERIFY = (
    1, 2, 4, 8, 16, 32)

HALF = int("7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0", 16)


def elem(bs):
    return {"len": len(bs), "b": list(bs) + [0] * (40 - len(bs))}


def sig_elem(idx, salt):
    k = (idx + salt) % 5
    if k == 0:
        return elem([])
    if k == 1:
        return elem([0x30, 0x06, 0x02, 0x01, 0x01, 0x02, 0x01, 0x01, 0x01])
    if k == 2:
        return elem([0x30, 0x06, 0x02, 0x01, 0x01])
    if k == 3:
        return elem([0x30, 0x25, 0x02, 0x01, 0x01, 0x02, 0x20, 0x7F] +
                    [0xFF] * 31 + [0x01])
    return elem([0x30, 0x06, 0x02, 0x01, 0x01, 0x02, 0x01, 0x01, 0x00])


def key_elem(idx, salt):
    k = (idx + salt) % 3
    if k == 0:
        return elem([0x02] + [0] * 32)
    if k == 1:
        return elem([0x04] + [0] * 64)
    return elem([0x05])


def stack(nk, ns, salt):
    s = [elem([])]                     # dummy
    for i in range(ns):
        s.append(sig_elem(i, salt))
    s.append(elem([ns]))               # nSigs
    for j in range(nk):
        s.append(key_elem(j, salt))
    s.append(elem([nk]))               # nKeys
    return s


def valid_sig(sig):
    ln, b = sig["len"], sig["b"]
    if ln < 9 or ln > 73:
        return False
    if b[0] != 0x30 or b[1] != ln - 3:
        return False
    lenR = b[3]
    if 5 + lenR >= ln:
        return False
    lenS = b[5 + lenR]
    if lenR + lenS + 7 != ln:
        return False
    if b[2] != 0x02 or lenR == 0 or (b[4] & 0x80):
        return False
    if lenR > 1 and b[4] == 0 and not (b[5] & 0x80):
        return False
    if b[lenR + 4] != 0x02 or lenS == 0 or (b[lenR + 6] & 0x80):
        return False
    if lenS > 1 and b[lenR + 6] == 0 and not (b[lenR + 7] & 0x80):
        return False
    return True


def low_s(sig):
    ln = sig["len"]
    if ln == 0:
        return False
    t = elem(sig["b"][:ln - 1] + [0x01])
    if not valid_sig(t):
        return False
    lenR = t["b"][3]
    lenS = t["b"][5 + lenR]
    sval = 0
    for j in range(lenS):
        sval = sval * 256 + t["b"][6 + lenR + j]
    return sval <= HALF


def defined_hashtype(sig):
    return sig["len"] > 0 and 1 <= (sig["b"][sig["len"] - 1] & 0x7F) <= 3


def comp_or_uncomp(pk):
    if pk["len"] < 33:
        return False
    b0 = pk["b"][0]
    if b0 == 0x04:
        return pk["len"] == 65
    if b0 in (0x02, 0x03):
        return pk["len"] == 33
    return False


def compressed(pk):
    return pk["len"] == 33 and pk["b"][0] in (0x02, 0x03)


def sig_err(sig, flags):
    if sig["len"] == 0:
        return 0
    if (flags & (F_DERSIG | F_LOW_S | F_STRICTENC)) and not valid_sig(sig):
        return DER
    if (flags & F_LOW_S) and not low_s(sig):
        return HIGHS
    if (flags & F_STRICTENC) and not defined_hashtype(sig):
        return HASHTYPE
    return 0


def pk_err(pk, flags):
    if (flags & F_STRICTENC) and not comp_or_uncomp(pk):
        return PUBKEYTYPE
    if (flags & F_WITPUB) and (flags & F_WITNESS_V0) and not compressed(pk):
        return WITPUBKEYTYPE
    return 0


def check_pair(sig, pk, salt):
    return ((sig["len"] * 31 + sig["b"][0] * 7 + pk["len"] * 13 +
             pk["b"][0] * 3 + salt) & 7) == 0


def pack(res, err, fs, early, ns, nk, isig, ikey):
    return ((res & 3) | ((err & 0x3F) << 2) | ((fs & 1) << 8) |
            ((early & 1) << 9) | ((ns & 0x3F) << 10) | ((nk & 0x3F) << 16) |
            ((isig & 0x3F) << 22) | ((ikey & 0x3F) << 28))


def run(nk, ns, salt, flags):
    if nk > 20 or ns > nk:
        return pack(3, 0, 0, 0, 0, 0, 0, 0)
    st = stack(nk, ns, salt)
    depth = len(st)
    ikey, isig = 2, nk + 3
    fs = True
    err = 0
    while fs and ns > 0:
        sig = st[depth - isig]
        pk = st[depth - ikey]
        e = sig_err(sig, flags)
        if e:
            err = e
            break
        e = pk_err(pk, flags)
        if e:
            err = e
            break
        if check_pair(sig, pk, salt):
            isig += 1
            ns -= 1
        ikey += 1
        nk -= 1
        if ns > nk:
            fs = False
    if err:
        return pack(0, err, 0, 0, ns, nk, isig, ikey)
    early = (not fs) and ns > 0
    if flags & F_VERIFY:
        if fs:
            return pack(1, 0, 1, 0, 0, nk, isig, ikey)
        return pack(0, CMSVERIFY, 0, int(early), ns, nk, isig, ikey)
    if fs:
        return pack(1, 0, 1, 0, 0, nk, isig, ikey)
    return pack(0, EVAL_FALSE, 0, int(early), ns, nk, isig, ikey)


CASES = []


def case(nk, ns, salt, flags):
    CASES.append({"fn": "cell_cms_loop", "args": [nk, ns, salt, flags],
                  "expected": run(nk, ns, salt, flags)})


# no signatures: loop skipped, success
case(1, 0, 0, 0)
case(20, 0, 3, 0)
case(0, 0, 0, F_VERIFY)
# matching sequences (salt chosen by search below)
for salt in range(0, 12):
    case(3, 2, salt, 0)
# early fail: all signatures fail, more sigs than keys left
for salt in range(0, 12):
    case(2, 2, salt, 0)
    case(3, 1, salt, 0)
# encoding gates, at the first and at later iterations (inside-loop evidence)
case(3, 2, 1, F_DERSIG)          # sig kinds vary; DER gate
case(2, 2, 52, F_DERSIG)         # DER error at iteration 2
case(3, 2, 52, F_DERSIG)         # DER error at iteration 3
case(1, 1, 4, F_STRICTENC)       # hashtype error
case(1, 1, 5, F_STRICTENC)       # pubkeytype error
case(2, 1, 8, F_STRICTENC)       # pubkeytype error at iteration 2
case(3, 2, 2, F_LOW_S)           # high-S arm
case(2, 2, 13, F_LOW_S)          # high-S at iteration 2
case(3, 2, 13, F_LOW_S)          # high-S at iteration 3
case(3, 2, 3, F_STRICTENC | F_LOW_S | F_DERSIG)
case(3, 2, 4, F_WITPUB | F_WITNESS_V0)       # uncompressed key under witness
case(2, 1, 8, F_WITPUB | F_WITNESS_V0)       # witness pubkeytype at iteration 2
case(3, 2, 5, F_WITPUB | F_STRICTENC)        # witness flag but BASE sv
case(3, 2, 0, F_WITPUB | F_WITNESS_V0)
# verify wire
case(3, 2, 7, F_VERIFY)
case(2, 2, 7, F_VERIFY)
# full 20-of-20 and 20-of-1
case(20, 20, 9, 0)
case(20, 1, 9, 0)
case(20, 20, 9, F_VERIFY)
# out of domain (sentinel)
case(0, 1, 0, 0)
case(21, 1, 0, 0)


def main():
    out = sys.argv[1]
    with open(out, "w") as f:
        json.dump(CASES, f, indent=1)
    errs = sorted({(c["expected"] >> 2) & 0x3F for c in CASES})
    early = sum(1 for c in CASES if (c["expected"] >> 9) & 1)
    print("error ordinals covered:", errs, "early-exit cases:", early)


if __name__ == "__main__":
    main()
