#!/usr/bin/env python3
"""Independent oracle for C-L-w32-pubkey-triage (SCR-158/159/160)."""
import json
import sys


def pack(ok, err, depth, top):
    payload = 0
    for i, b in enumerate(top):
        payload |= (b & 0xFF) << (8 * i)
    return (ok & 1) | ((err & 0x3F) << 1) | ((depth & 7) << 7) \
        | ((len(top) & 7) << 10) | (payload << 13)


def fail(err):
    return pack(0, err, 0, [])


def encode_num(v):
    if v == 0:
        return []
    neg = v < 0
    a = abs(v)
    out = []
    while a:
        out.append(a & 0xFF)
        a >>= 8
    if out[-1] & 0x80:
        out.append(0x80 if neg else 0)
    elif neg:
        out[-1] |= 0x80
    return out


def tpack(ok, err, success, weight, called):
    return (ok & 1) | ((err & 0x3F) << 1) | ((success & 1) << 7) \
        | (((weight & 0xFFFF)) << 8) | ((called & 1) << 24)


def eval_triage(sig_nonempty, pk_len, vw, discourage, checker):
    """EvalChecksigTapscript (Core 357-400 / Defs.lean 757-780)."""
    success = sig_nonempty
    called = 0
    if success:
        vw2 = vw - 50
        if vw2 < 0:
            return tpack(0, 49, 0, vw2, called)
        vw = vw2
    if pk_len == 0:
        return tpack(0, 52, 0, vw, called)
    if pk_len == 32:
        if success:
            called = 1
            if not checker:
                return tpack(0, 47, 0, vw, called)
        return tpack(1, 0, 1 if success else 0, vw, called)
    if discourage:
        return tpack(0, 37, 0, vw, called)
    return tpack(1, 0, 1 if success else 0, vw, called)


def scenarios(checker):
    out = []

    def add(sl, pl, disc, seed):
        # Triage reads only the element lengths; the ABI carries at most five
        # payload bytes, which do not affect any branch in this cell.
        sig = 64 if sl else 0
        pk = pl & 0xFF
        out.append(dict(fn="cell_triage",
                        args=[sig, pk, disc, seed],
                        expected=eval_triage(bool(sl), pl, seed - 100,
                                             bool(disc), checker)))

    # SCR-159: empty pubkey with both sig states, on both sides of the
    # validation-weight decrement.
    # seed = initial vw + 100 (the ABI domain is vw in [-100, 923]).
    add(0, 0, 0, 200)      # empty sig + empty pk: EMPTY_PUBKEY, no decrement
    add(1, 0, 0, 200)      # non-empty sig + empty pk: 52 after -50
    add(1, 0, 0, 101)      # vw 1 -> -49: weight error precedes empty pk
    add(1, 0, 0, 150)      # vw 50 -> 0 after decrement: empty pk wins
    # SCR-158/160: the 32-byte x-only lane with empty and non-empty sig.
    add(0, 32, 0, 200)     # empty sig: ok(false), weight unchanged, no call
    add(0, 32, 1, 200)     # empty sig: policy irrelevant in the 32 lane
    add(1, 32, 0, 200)     # non-empty: checker call, success=checker
    add(1, 32, 0, 160)     # vw 60 -> weight 10, checker call
    add(1, 32, 0, 150)     # vw 50 -> weight 0, checker call
    add(1, 32, 0, 149)     # vw 49 -> 49 before the checker call
    # SCR-158: other non-empty pubkey lengths (upgradable).
    add(0, 33, 0, 200)     # empty sig, upgradable -> ok(false), no weight
    add(0, 33, 1, 200)     # empty sig, policy -> 37
    add(1, 33, 0, 200)     # non-empty -> ok(true), -50, no call
    add(1, 33, 1, 200)     # non-empty, policy -> 37, -50, no call
    add(1, 1, 0, 200)      # 1-byte key is also upgradable
    add(1, 31, 0, 200)     # 31-byte key is upgradable
    add(1, 34, 0, 200)     # 34-byte key is upgradable
    return out


def continue_scenarios(checker):
    out = []

    def add(sl, pl, nb, disc, seed):
        sig = 64 if sl else 0
        pk = pl & 0xFF
        ok, err, success, _vw, _c = eval_triage_checksig(
            bool(sl), pl, seed - 100, bool(disc), checker)
        exp = pack(1, 0, 1, encode_num(nb + (1 if success else 0))) \
            if ok else fail(err)
        out.append(dict(fn="cell_triage_continue",
                        args=[sig, pk, nb, disc, seed], expected=exp))

    # SCR-160: empty sig + x-only key -> success false, num unchanged,
    # script continues.
    add(0, 32, 0, 0, 200)
    add(0, 32, 1, 0, 200)
    add(0, 32, 2, 1, 200)
    add(0, 32, 127, 0, 200)
    add(0, 32, 128, 0, 200)
    add(0, 32, 255, 0, 200)
    # Non-empty sig + x-only: checker verdict decides the +1.
    add(1, 32, 2, 0, 200)
    add(1, 32, 254, 0, 200)
    # Empty pubkey still aborts before the push.
    add(0, 0, 2, 0, 200)
    add(1, 0, 2, 0, 200)
    return out


def eval_triage_checksig(sig_nonempty, pk_len, vw, discourage, checker):
    """Same equations as eval_triage, returning the caller-visible tuple."""
    success = sig_nonempty
    called = 0
    if success:
        vw2 = vw - 50
        if vw2 < 0:
            return (False, 49, False, vw2, called)
        vw = vw2
    if pk_len == 0:
        return (False, 52, success, vw, called)
    if pk_len == 32:
        if success:
            called = 1
            if not checker:
                return (False, 47, False, vw, called)
        return (True, 0, success, vw, called)
    if discourage:
        return (False, 37, success, vw, called)
    return (True, 0, success, vw, called)


if __name__ == "__main__":
    checker = int(sys.argv[1])
    path = sys.argv[2]
    data = scenarios(checker) + continue_scenarios(checker)
    with open(path, "w") as f:
        json.dump(data, f, indent=1)
