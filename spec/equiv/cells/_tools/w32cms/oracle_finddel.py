#!/usr/bin/env python3
"""Independent scenario oracle for the SCR-115 FindAndDelete cell.

Models Core CScript::FindAndDelete (script.cpp:239-265) directly from the
iterator formulation, plus the CHECKMULTISIG pre-loop that deletes the
serialized push of every signature before any checker call.

usage: oracle_finddel.py <out.json> [checker]
"""
import json
import sys

OOD = 0xFFFFFFFFFFFFFFFF


def pack_bytes(bs):
    r = 0
    for i, b in enumerate(bs):
        r |= (b & 0xFF) << (8 * i)
    return r


def unpack(payload, ln):
    return [(payload >> (8 * i)) & 0xFF for i in range(ln)]


def get_op(s, pc):
    n = len(s)
    if pc >= n:
        return None
    op = s[pc]
    q = pc + 1
    if op <= 0x4B:
        size = op
    elif op == 0x4C:
        if n - q < 1:
            return None
        size = s[q]
        q += 1
    elif op == 0x4D:
        if n - q < 2:
            return None
        size = s[q] | (s[q + 1] << 8)
        q += 2
    elif op == 0x4E:
        if n - q < 4:
            return None
        size = s[q] | (s[q + 1] << 8) | (s[q + 2] << 16) | (s[q + 3] << 24)
        q += 4
    else:
        return q
    if size > n - q:
        return None
    return q + size


def find_delete(s, b):
    if not b:
        return 0, s
    out = []
    pc = pc2 = 0
    found = 0
    while True:
        out.extend(s[pc2:pc])
        while len(s) - pc >= len(b) and s[pc:pc + len(b)] == b:
            pc += len(b)
            found += 1
        pc2 = pc
        nxt = get_op(s, pc)
        if nxt is None:
            break
        pc = nxt
    if found > 0:
        out.extend(s[pc2:])
        return found, out
    return 0, s


def chain(ns, script, sig0, sig1):
    s = list(script)
    for k in range(min(ns, 2)):
        sig = sig0 if k == 0 else sig1
        needle = [len(sig)] + list(sig)          # CScript() << vchSig
        _, s = find_delete(s, needle)
    return s


CASES = []


def add(fn, args, expected):
    CASES.append({"fn": fn, "args": args, "expected": expected})


# script payload, script length, needle payload, needle length
def fd_case(script, needle):
    sp = pack_bytes(script)
    np = pack_bytes(needle)
    found, out = find_delete(list(script), list(needle))
    add("cell_fd_found", [sp, len(script), np, len(needle)], found)
    add("cell_fd_len", [sp, len(script), np, len(needle)], len(out))
    add("cell_fd_bytes", [sp, len(script), np, len(needle)], pack_bytes(out))


def chain_case(ns, script, sig0, sig1):
    out = chain(ns, script, sig0, sig1)
    add("cell_fd_chain",
        [ns, pack_bytes(script), len(script), pack_bytes(sig0), len(sig0),
         pack_bytes(sig1), len(sig1)],
        (len(out) << 56) | pack_bytes(out))


# empty script / empty needle
fd_case([], [])
fd_case([0x51, 0x52], [])
fd_case([], [0x01])
# exact whole-script match
fd_case([0x01, 0xAA], [0x01, 0xAA])
# head, middle, tail
fd_case([0x01, 0xAA, 0x51, 0x52], [0x01, 0xAA])
fd_case([0x51, 0x01, 0xAA, 0x52], [0x01, 0xAA])
fd_case([0x51, 0x52, 0x01, 0xAA], [0x01, 0xAA])
# no match
fd_case([0x51, 0x52], [0x01, 0xAA])
# greedy run: two adjacent occurrences
fd_case([0x01, 0xAA, 0x01, 0xAA], [0x01, 0xAA])
# needle spanning an opcode boundary (matched only at an opcode boundary)
fd_case([0x02, 0xAA, 0xBB], [0x02, 0xAA])
# match starting at a byte that is not an opcode boundary (must not delete)
fd_case([0x02, 0xAA, 0xBB], [0xAA, 0xBB])
# PUSHDATA1 boundary
fd_case([0x4C, 0x01, 0xAA, 0x51], [0x4C, 0x01])
# truncated push: walk stops, tail handled
fd_case([0x02, 0xAA], [0x02])
# needle longer than script
fd_case([0x51], [0x51, 0x52])
# 8-byte script, 4-byte needle
fd_case([0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58],
        [0x53, 0x54, 0x55, 0x56])
# out of domain
add("cell_fd_found", [0, 9, 0, 0], OOD)
add("cell_fd_len", [0, 0, 0, 5], OOD)
# chains: ns = 0, 1, 2
chain_case(0, [0x01, 0xAA, 0x51], [0xAA], [0xBB])
chain_case(1, [0x01, 0xAA, 0x51], [0xAA], [0xBB])
chain_case(1, [0x01, 0xAA, 0x01, 0xAA, 0x51], [0xAA], [0xBB])
chain_case(2, [0x01, 0xAA, 0x01, 0xBB, 0x51], [0xAA], [0xBB])
chain_case(2, [0x01, 0xBB, 0x01, 0xAA, 0x51], [0xAA], [0xBB])
chain_case(2, [0x01, 0xAA, 0x01, 0xBB], [0xAA], [0xBB])
chain_case(2, [0x51, 0x01, 0xAA, 0x52], [0xAA], [0xBB])
chain_case(2, [0x01, 0xAA], [0xAA], [0xBB])


def chain_n(ns, script, salt, sv):
    s = list(script)
    for k in range(min(ns, 20)):
        if sv != 0:
            continue
        needle = [0x01, (37 * k + salt) & 0xFF]
        _, s = find_delete(s, needle)
    return s


def chain_n_case(ns, script, salt, sv):
    out = chain_n(ns, script, salt, sv)
    add("cell_fd_chain_n",
        [ns, pack_bytes(script), len(script), salt, sv],
        (len(out) << 56) | pack_bytes(out))


# symbolic-count chain: nSigs = 0, 1, 2, 3, 20; base and witness sigversion
chain_n_case(0, [0x01, 0x00, 0x01, 0x25, 0x51], 0, 0)
chain_n_case(1, [0x01, 0x00, 0x01, 0x25, 0x51], 0, 0)
chain_n_case(2, [0x01, 0x00, 0x01, 0x25, 0x51], 0, 0)
chain_n_case(3, [0x01, 0x00, 0x01, 0x25, 0x01, 0x4A, 0x52], 0, 0)
chain_n_case(20, [0x01, 0x00, 0x01, 0x25, 0x51], 0, 0)
chain_n_case(2, [0x01, 0x00, 0x01, 0x25, 0x51], 0, 1)
chain_n_case(3, [0x01, 0x01, 0x01, 0x26, 0x01, 0x4B], 1, 0)
chain_n_case(3, [0x01, 0x02, 0x01, 0x27, 0x01, 0x4C], 2, 0)
chain_n_case(5, [0x51, 0x52, 0x53], 3, 0)


def main():
    out = sys.argv[1]
    with open(out, "w") as f:
        json.dump(CASES, f, indent=1)
    print("scenarios:", len(CASES))


if __name__ == "__main__":
    main()
