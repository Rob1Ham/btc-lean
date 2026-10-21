#!/usr/bin/env python3
"""Independent reference oracle for the checksig/findanddelete cell.

Restates CScript::FindAndDelete (interpreter.cpp:239-265) and
SigHash.findAndDeleteL (Ops.lean:112-124) at the byte level:
  - try the needle at the current boundary; consecutive matches are consumed;
  - otherwise take one GetOp step and copy the whole opcode span;
  - a GetOp failure copies the verbatim tail.
The needle is the serialized signature push CScript() << vchSig, i.e.
length byte + payload, so it is never empty.  PL=1 covers sig length 0
(needle 0x00), PL=2 covers sig length 1, PL=3 covers sig length 2.

Packing: found(4) | outn(4) << 4 | out[k] << (8 + 8k)
"""
from __future__ import annotations
import argparse, json


def getop(s: bytes, i: int):
    if i >= len(s):
        return None
    v = s[i]
    if v <= 0x4E:
        if v < 0x4C:
            size, p = v, i + 1
        elif v == 0x4C:
            if i + 1 >= len(s):
                return None
            size, p = s[i + 1], i + 2
        elif v == 0x4D:
            if i + 2 >= len(s):
                return None
            size, p = s[i + 1] | (s[i + 2] << 8), i + 3
        else:
            if i + 4 >= len(s):
                return None
            size = s[i + 1] | (s[i + 2] << 8) | (s[i + 3] << 16) | (s[i + 4] << 24)
            p = i + 5
        if p + size > len(s):
            return None
        return (v, p + size)
    return (v, i + 1)


def fad(s: bytes, needle: bytes):
    assert needle
    i, found, out = 0, 0, bytearray()
    while i < len(s):
        if s[i:i + len(needle)] == needle:
            i += len(needle)
            found += 1
            continue
        g = getop(s, i)
        if g is None:
            out += s[i:]
            break
        _, nx = g
        out += s[i:nx]
        i = nx
    return bytes(out), found


def pack(found: int, out: bytes) -> int:
    r = (found & 15) | ((len(out) & 15) << 4)
    for k, b in enumerate(out):
        r |= b << (8 + 8 * k)
    return r


def ser_needle(sig: bytes) -> bytes:
    return bytes([len(sig)]) + sig


def scenarios():
    specs = [
        # (PL, name, script, signature payload)
        (1, "pl1_no_match", [0x51, 0x52, 0x53, 0x54], []),
        (1, "pl1_match0", [0x00, 0x52, 0x53, 0x54], []),
        (1, "pl1_consecutive", [0x00, 0x00, 0x53, 0x54], []),
        (1, "pl1_after_push", [0x01, 0x00, 0x00, 0x54], []),
        (1, "pl1_all", [0x00, 0x00, 0x00, 0x00], []),
        (1, "pl1_malformed", [0x04, 0x00, 0x00, 0x00], []),
        (2, "pl2_no_match", [0x51, 0x52, 0x53, 0x54], [0xAB]),
        (2, "pl2_match0", [0x01, 0xAB, 0x53, 0x54], [0xAB]),
        (2, "pl2_consecutive", [0x01, 0xAB, 0x01, 0xAB], [0xAB]),
        (2, "pl2_continue", [0x01, 0xAB, 0x01, 0x54], [0xAB]),
        (2, "pl2_after_push", [0x02, 0x01, 0xAB, 0x54], [0xAB]),
        (2, "pl2_malformed", [0x05, 0x01, 0xAB, 0x01], [0xAB]),
        (3, "pl3_no_match", [0x51, 0x52, 0x53, 0x54, 0x55, 0x56], [0xAB, 0xCD]),
        (3, "pl3_match0", [0x02, 0xAB, 0xCD, 0x53, 0x54, 0x55], [0xAB, 0xCD]),
        (3, "pl3_consecutive", [0x02, 0xAB, 0xCD, 0x02, 0xAB, 0xCD], [0xAB, 0xCD]),
        (3, "pl3_continue", [0x02, 0xAB, 0xCD, 0x02, 0xAB, 0x54], [0xAB, 0xCD]),
        (3, "pl3_after_push", [0x03, 0x02, 0xAB, 0xCD, 0x55, 0x56], [0xAB, 0xCD]),
        (3, "pl3_malformed", [0x06, 0x02, 0xAB, 0xCD, 0x55, 0x56], [0xAB, 0xCD]),
    ]
    out = []
    for pl, name, script, sig in specs:
        nd = ser_needle(bytes(sig))
        assert len(nd) == pl, (name, nd)
        body, found = fad(bytes(script), nd)
        out.append({"module": f"fad_pl{pl}", "fn": f"cell_fad_pl{pl}", "name": name,
                    "args": list(script) + list(nd),
                    "expected": pack(found, body)})
    return out


def emit_saw(scen, path):
    mods = sorted({s["module"] for s in scen})
    lines = []
    for m in mods:
        lines.append(f'mC_{m} <- llvm_load_module "c_{m}.bc";')
        lines.append(f'mL_{m} <- llvm_load_module "l_{m}.bc";')
    for i, s in enumerate(scen):
        args = ", ".join(f"llvm_term {{{{ 0x{a:02x} : [8] }}}}" for a in s["args"])
        lines.append(f'let s{i} = do {{ llvm_execute_func [{args}]; '
                     f'llvm_return (llvm_term {{{{ 0x{s["expected"]:016x} }}}}); }};')
        lines.append(f'llvm_verify mC_{s["module"]} "{s["fn"]}" [] false s{i} abc;')
        lines.append(f'llvm_verify mL_{s["module"]} "{s["fn"]}" [] false s{i} abc;')
    lines.append('print "SAW_SCENARIOS_DONE";')
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json")
    ap.add_argument("--saw")
    a = ap.parse_args()
    scen = scenarios()
    for s in scen:
        print(f'{s["name"]}: expected=0x{s["expected"]:016x}')
    if a.json:
        with open(a.json, "w") as f:
            json.dump(scen, f, indent=2)
            f.write("\n")
    if a.saw:
        emit_saw(scen, a.saw)


if __name__ == "__main__":
    main()
