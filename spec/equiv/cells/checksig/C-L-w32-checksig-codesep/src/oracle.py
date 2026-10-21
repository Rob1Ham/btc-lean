#!/usr/bin/env python3
"""Independent reference oracle for the checksig/codesep cell.

This file restates the row semantics (Core interpreter.cpp and the Lean
Defs.lean equations) directly; it is not generated from the C or L cell
sources.  It produces the closed SAW scenarios and their expected packed
constants.  Behavioral output is not proof evidence.

Packing (cell harness):
  err(6) | codeSep(3) << 6 | outn(3) << 9 | out[k] << (12 + 8k)
"""
from __future__ import annotations
import argparse, json

BAD_OPCODE = 16
OP_CODESEPARATOR = 53


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


def pack(err: int, code_sep: int, out: bytes) -> int:
    r = (err & 63) | ((code_sep & 7) << 6) | ((len(out) & 7) << 9)
    for k, b in enumerate(out):
        r |= b << (12 + 8 * k)
    return r


def codesep(s: bytes, mask: int, sv: int, constsc: int) -> int:
    code_sep, it, err = 0, 0, 0
    for k in range(len(s)):
        if it >= len(s):
            break
        g = getop(s, it)
        if g is None:
            err = BAD_OPCODE
            break
        op, nx = g
        # interpreter.cpp:484-486 / Defs.lean:833: checked before fExec.
        if op == 0xAB and sv == 0 and constsc:
            err = OP_CODESEPARATOR
            break
        # Defs.lean:1031-1032 / interpreter.cpp:1058-1067: update only if fExec.
        if ((mask >> k) & 1) and op == 0xAB:
            code_sep = nx
        it = nx
    return pack(err, code_sep, s[code_sep:] if err == 0 else b"")


def scenarios():
    def sc(name, s, mask, sv, constsc):
        return {"module": "codesep", "fn": "cell_codesep", "name": name,
                "args": list(s) + [mask, sv, constsc],
                "expected": codesep(bytes(s), mask, sv, constsc)}

    return [
        sc("exec_sep", [0x51, 0xAB, 0x52, 0x53, 0x54, 0x55], 0b000010, 0, 0),
        sc("unexec_sep", [0x51, 0xAB, 0x52, 0x53, 0x54, 0x55], 0b000000, 0, 0),
        sc("unexec_policy", [0x51, 0xAB, 0x52, 0x53, 0x54, 0x55], 0b000000, 0, 1),
        sc("exec_policy", [0x51, 0xAB, 0x52, 0x53, 0x54, 0x55], 0b000010, 0, 1),
        sc("witness_exec", [0x51, 0xAB, 0x52, 0x53, 0x54, 0x55], 0b000010, 1, 1),
        sc("trailing_sep", [0x51, 0x52, 0x53, 0x54, 0x55, 0xAB], 0b100000, 0, 0),
        sc("two_seps", [0xAB, 0x51, 0xAB, 0x52, 0x53, 0x54], 0b000101, 0, 0),
        sc("bad_opcode", [0x4C, 0x05, 0x51, 0x52, 0x53, 0x54], 0b000000, 0, 0),
        sc("payload_ab", [0x02, 0xAB, 0xAB, 0xAB, 0xAB, 0xAB], 0b000010, 0, 0),
        sc("no_sep", [0x51, 0x52, 0x53, 0x54, 0x55, 0x56], 0b111111, 0, 0),
    ]


def emit_saw(scen, path):
    mods = sorted({s["module"] for s in scen})
    out = []
    for m in mods:
        out.append(f'mC_{m} <- llvm_load_module "c_{m}.bc";')
        out.append(f'mL_{m} <- llvm_load_module "l_{m}.bc";')
    for i, s in enumerate(scen):
        args = ", ".join(f"llvm_term {{{{ 0x{a:02x} : [8] }}}}" for a in s["args"])
        out.append(f'let s{i} = do {{ llvm_execute_func [{args}]; '
                   f'llvm_return (llvm_term {{{{ 0x{s["expected"]:016x} }}}}); }};')
        out.append(f'llvm_verify mC_{s["module"]} "{s["fn"]}" [] false s{i} abc;')
        out.append(f'llvm_verify mL_{s["module"]} "{s["fn"]}" [] false s{i} abc;')
    out.append('print "SAW_SCENARIOS_DONE";')
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")


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
