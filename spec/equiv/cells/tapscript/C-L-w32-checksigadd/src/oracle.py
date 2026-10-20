#!/usr/bin/env python3
"""Independent oracle for C-L-w32-checksigadd (SCR-156/157).

Python model of the pinned Core slice and of the Lean equations.  The
expected packed observables are derived HERE, not read from either leg.
"""
import json
import sys


def pack(ok, err, depth, top):
    top = list(top)
    assert 0 <= len(top) <= 5
    payload = 0
    for i, b in enumerate(top):
        payload |= (b & 0xFF) << (8 * i)
    return (ok & 1) | ((err & 0x3F) << 1) | ((depth & 7) << 7) \
        | ((len(top) & 7) << 10) | (payload << 13)


def fail(err):
    return pack(0, err, 0, [])


OOD = 0xFFFFFFFFFFFFFFFF


def decode_num(b, minimal):
    """CScriptNum(vch, fRequireMinimal, 4); None = scriptnum_error."""
    if len(b) > 4:
        return None
    if minimal and len(b) > 0:
        if (b[-1] & 0x7F) == 0:
            if len(b) <= 1 or (b[-2] & 0x80) == 0:
                return None
    if not b:
        return 0
    v = 0
    for i, x in enumerate(b):
        v |= (x & 0xFF) << (8 * i)
    if b[-1] & 0x80:
        v &= ~(0x80 << (8 * (len(b) - 1)))
        return -v
    return v


def encode_num(v):
    """CScriptNum::getvch / serialize: canonical LE sign-magnitude."""
    if v == 0:
        return []
    neg = v < 0
    a = abs(v)
    out = []
    while a:
        out.append(a & 0xFF)
        a >>= 8
    if out[-1] & 0x80:
        out.append(0x80 if neg else 0x00)
    elif neg:
        out[-1] |= 0x80
    return out


def eval_tapscript(sig_len, pk_len, vw, discourage, checker):
    """Returns (ok, err, success, vw_after, called)."""
    success = sig_len != 0
    called = False
    if success:
        vw2 = vw - 50
        if vw2 < 0:
            return (False, 49, False, vw2, called)
        vw = vw2
    if pk_len == 0:
        return (False, 52, success, vw, called)
    if pk_len == 32:
        if success:
            called = True
            if not checker:
                return (False, 47, False, vw, called)
        return (True, 0, success, vw, called)
    if discourage:
        return (False, 37, success, vw, called)
    return (True, 0, success, vw, called)


def add_dispatch(sv, depth):
    if sv > 2 or depth > 7:
        return OOD
    if sv in (0, 1):
        return fail(16)
    if depth < 3:
        return fail(18)
    ok, err, success, _vw, _c = eval_tapscript(0, 32, 100, False, 0)
    assert ok and not success
    return pack(1, 0, depth - 2, encode_num(2 + (1 if success else 0)))


def add_num(num, depth, sig_len, pk_len, minimal, discourage, vw_seed,
            checker):
    if len(num) > 5 or sig_len > 255 or pk_len > 255 or depth > 7 \
            or minimal > 1 or discourage > 1 or vw_seed > 1023:
        return OOD
    if depth < 3:
        return fail(18)
    n = decode_num(num, bool(minimal))
    if n is None:
        return fail(4)
    ok, err, success, _vw, _c = eval_tapscript(
        sig_len, pk_len, vw_seed - 100, bool(discourage), checker)
    if not ok:
        return fail(err)
    return pack(1, 0, depth - 2, encode_num(n + (1 if success else 0)))


SIG32 = [0] * 32
SIG64 = [0] * 63 + [1]
SIG65 = [0] * 64 + [1]


def dispatch_scenarios():
    out = []
    for sv in range(3):
        for depth in (0, 1, 2, 3, 5, 7):
            out.append(dict(fn="cell_add_dispatch", args=[sv, depth],
                            expected=add_dispatch(sv, depth)))
    out.append(dict(fn="cell_add_dispatch", args=[2, 8], expected=OOD))
    out.append(dict(fn="cell_add_dispatch", args=[3, 3], expected=OOD))
    return out


def num_scenarios(checker):
    out = []

    def add(num, sl, pl, minimal, disc, seed, depth=3):
        out.append(dict(fn="cell_add_num",
                        args=[num_of(num), num_of(SIG32 if sl else []),
                              num_of(SIG32[:pl] if pl <= 32 else [0] * pl),
                              depth, minimal, disc, seed],
                        expected=add_num(num, depth, sl, pl, minimal, disc,
                                         seed, checker)))

    def num_of(b):
        # The cell ABI packs len in byte 0 and payload in bytes 1..5.
        v = len(b)
        for i, x in enumerate(b[:5]):
            v |= (x & 0xFF) << (8 * (i + 1))
        return v

    # SCR-157: decode/minimality/width, with a non-empty sig only where the
    # checker verdict matters.
    add([], 0, 32, 1, 0, 100)                    # 0 -> push 0
    add([2], 0, 32, 1, 0, 100)                   # 2 -> push 2
    add([0x80], 0, 32, 1, 0, 100)                # negative zero, minimal -> 4
    add([0x80], 0, 32, 0, 0, 100)                # negative zero, lax -> 0
    add([0x01, 0x00], 0, 32, 1, 0, 100)          # non-minimal 1 -> 4
    add([0x01, 0x00], 0, 32, 0, 0, 100)          # lax -> 1
    add([0xFF, 0x00], 0, 32, 1, 0, 100)          # 255, minimal exception
    add([0x00, 0x00, 0x00, 0x00, 0x00], 0, 32, 1, 0, 100)  # 5 bytes -> 4
    add([0xFF, 0xFF, 0xFF, 0xFF], 0, 32, 1, 0, 100)        # -1
    add([0xFE, 0xFF, 0xFF, 0xFF], 0, 32, 1, 0, 100)        # -2 -> +0 = -2
    add([0xFF, 0xFF, 0xFF, 0x7F], 64, 32, 1, 0, 100)       # 2^31-1 +1 -> 5-byte output
    # SCR-156: stack effect for both success values.
    add([2], 64, 32, 1, 0, 100)                  # checker=1 -> 3 / checker=0 -> 47
    add([2], 64, 0, 1, 0, 100)                   # empty pubkey -> 52
    add([2], 64, 33, 0, 0, 100)                  # upgradable, no policy -> +1
    add([2], 64, 33, 0, 1, 100)                  # upgradable + policy -> 37
    add([2], 0, 0, 1, 0, 100)                    # empty sig, empty pk -> 52
    add([2], 0, 32, 1, 0, 100)                   # empty sig, x-only -> push 2
    add([2], 64, 32, 1, 0, 60)                   # vw 60 -> 10, ok
    add([2], 64, 32, 1, 0, 49)                   # vw 49 -> -1, 49
    add([2], 64, 32, 1, 0, 0)                    # vw -100 -> 49 (underflow first)
    # Arity precedes both the ScriptNum parse and EvalChecksig.
    add([0x01, 0x00], 64, 32, 1, 0, 100, 0)      # depth 0 -> 18, not 4
    add([0x01, 0x00], 64, 32, 1, 0, 100, 1)      # depth 1 -> 18
    add([0x01, 0x00], 64, 32, 1, 0, 100, 2)      # depth 2 -> 18
    add([2], 64, 32, 1, 0, 100, 5)               # deeper stack -> depth 3
    return out


if __name__ == "__main__":
    which = sys.argv[1]
    checker = int(sys.argv[2])
    path = sys.argv[3]
    if which == "dispatch":
        scen = dispatch_scenarios()
    elif which == "num":
        scen = num_scenarios(checker)
    else:
        raise SystemExit("unknown scenario group")
    with open(path, "w") as f:
        json.dump(scen, f, indent=1)
