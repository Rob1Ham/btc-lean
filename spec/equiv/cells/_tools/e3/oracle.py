#!/usr/bin/env python3
"""Independent reference oracle for the E3 cell postconditions.

NOT extracted from the C or L engine code.  It restates the declared
postcondition (verdict / error ordinal / depth / top) so the SAW closed
scenarios and the behavior run have expected constants.  The checker return
is the only nondeterminism; the SAW lane pins it to 0 and 1.

Domain and packing match cells/_tools/e3/e3_common.h.
"""
from __future__ import annotations
import json, sys

EVAL_FALSE = 2
CHECKMULTISIGVERIFY = 13
CHECKSIGVERIFY = 14
INVALID_STACK_OPERATION = 18
SIG_NULLDUMMY = 28


def pack(res, err, stack):
    m = min(len(stack), 3)
    k = 0
    if len(stack) == 4:
        k = 1
    r = (res & 3) | ((err & 0x3F) << 2) | ((len(stack) & 7) << 8)
    for j in range(m):
        ln, val = stack[k + j]
        off = 11 + 10 * j
        r |= (ln & 3) << off
        r |= (val & 0xFF) << (off + 2)
    return r


def finish(stack):
    if not stack:
        return pack(0, EVAL_FALSE, stack)
    ln, val = stack[-1]
    if ln == 0:
        truth = 0
    elif ln == 1:
        truth = 0 if val in (0, 0x80) else 1
    else:
        truth = 1 if (val & 0xFF) != 0 else (0 if ((val >> 8) & 0xFF) in (0, 0x80) else 1)
    return pack(1 if truth else 0, 0 if truth else EVAL_FALSE, stack)


SIG1 = (1, 0x41)
PK1 = (1, 0x02)


def checksig_witness(wire, stack_n, checker):
    stack = [SIG1] if stack_n >= 1 else []
    if stack_n >= 2:
        stack.append(PK1)
    if stack_n < 2:
        return pack(0, INVALID_STACK_OPERATION, [])
    stack.pop(); stack.pop()
    stack.append((1, 1) if checker else (0, 0))
    if wire == 0xAD:
        if not checker:
            return pack(0, CHECKSIGVERIFY, [])
        stack.pop()
        stack.append((1, 1))
    return finish(stack)


def cms_witness(wire, stack_n, dummy, null_dummy, checker):
    stack = []
    if stack_n == 5:
        stack = [dummy, SIG1, (1, 1), PK1, (1, 1)]
    if not stack:
        return pack(0, INVALID_STACK_OPERATION, [])
    stack = stack[:-4]                    # cleanup pops nKeys+nSigs+2 = 4
    if not stack:
        return pack(0, INVALID_STACK_OPERATION, [])
    if null_dummy and stack[-1][0] != 0:
        return pack(0, SIG_NULLDUMMY, [])
    stack.pop()
    stack.append((1, 1) if checker else (0, 0))
    if wire == 0xAF:
        if not checker:
            return pack(0, CHECKMULTISIGVERIFY, [])
        stack.pop()
        stack.append((1, 1))
    return finish(stack)


def checksig_scenarios(checker):
    return [
        {"fn": "cell_checksig", "args": [], "expected": checksig_witness(0xAC, 2, checker)},
        {"fn": "cell_checksigverify", "args": [], "expected": checksig_witness(0xAD, 2, checker)},
        {"fn": "cell_checksig_underflow", "args": [], "expected": checksig_witness(0xAC, 1, checker)},
    ]


def cms_scenarios(checker):
    return [
        {"fn": "cell_cms", "args": [], "expected": cms_witness(0xAE, 5, (0, 0), False, checker)},
        {"fn": "cell_cmsverify", "args": [], "expected": cms_witness(0xAF, 5, (0, 0), False, checker)},
        {"fn": "cell_cms_nulldummy", "args": [], "expected": cms_witness(0xAE, 5, (1, 0x55), True, checker)},
        {"fn": "cell_cms_empty", "args": [], "expected": cms_witness(0xAE, 0, (0, 0), False, checker)},
    ]


def main() -> int:
    cells = {"checksig": checksig_scenarios, "cms": cms_scenarios}
    which = sys.argv[1] if len(sys.argv) > 1 else "checksig"
    checker = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    outs = cells[which](checker)
    for s in outs:
        print(f'{s["fn"]}: checker={checker} expected=0x{s["expected"]:x}')
    if len(sys.argv) > 2:
        with open(sys.argv[2], "w") as f:
            json.dump(outs, f, indent=2)
            f.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
