#!/usr/bin/env python3
"""Independent reference oracle for the checksig/constscriptcode cell.

Restates interpreter.cpp:336-343 and Defs.lean:720-733:
  - scriptCode starts at the last code separator (this cell starts at 0);
  - only SigVersion::BASE runs FindAndDelete(scriptCode, CScript() << sig);
  - if found > 0 and SCRIPT_VERIFY_CONST_SCRIPTCODE is set, the call fails
    with SCRIPT_ERR_SIG_FINDANDDELETE (=54), before any encoding check;
  - WITNESS_V0 skips FindAndDelete entirely (BIP143).

Packing: err(6) | found(4) << 6 | outn(4) << 10 | out[k] << (14 + 8k)
"""
from __future__ import annotations
import argparse, json

SIG_FINDANDDELETE = 54


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


def pack(err: int, found: int, out: bytes) -> int:
    r = (err & 63) | ((found & 15) << 6) | ((len(out) & 15) << 10)
    for k, b in enumerate(out):
        r |= b << (14 + 8 * k)
    return r


def policy(s: bytes, needle: bytes, sv: int, constsc: int) -> int:
    if sv == 0:
        body, found = fad(s, needle)
        err = SIG_FINDANDDELETE if (found > 0 and constsc) else 0
        return pack(err, found, body)
    return pack(0, 0, s)


def ser_needle(sig: bytes) -> bytes:
    return bytes([len(sig)]) + sig


def scenarios():
    specs = [
        # (PL, name, script, signature payload, sv, constsc)
        (1, "pl1_found_policy", [0x00, 0x52, 0x53, 0x54, 0x55, 0x56], [], 0, 1),
        (1, "pl1_found_nopolicy", [0x00, 0x52, 0x53, 0x54, 0x55, 0x56], [], 0, 0),
        (1, "pl1_notfound_policy", [0x51, 0x52, 0x53, 0x54, 0x55, 0x56], [], 0, 1),
        (1, "pl1_witness", [0x00, 0x52, 0x53, 0x54, 0x55, 0x56], [], 1, 1),
        (1, "pl1_two_policy", [0x00, 0x00, 0x53, 0x54, 0x55, 0x56], [], 0, 1),
        (2, "pl2_found_policy", [0x01, 0xAB, 0x53, 0x54, 0x55, 0x56], [0xAB], 0, 1),
        (2, "pl2_found_nopolicy", [0x01, 0xAB, 0x53, 0x54, 0x55, 0x56], [0xAB], 0, 0),
        (2, "pl2_notfound_policy", [0x51, 0x52, 0x53, 0x54, 0x55, 0x56], [0xAB], 0, 1),
        (2, "pl2_witness", [0x01, 0xAB, 0x53, 0x54, 0x55, 0x56], [0xAB], 1, 1),
        (2, "pl2_two_policy", [0x01, 0xAB, 0x01, 0xAB, 0x55, 0x56], [0xAB], 0, 1),
        (3, "pl3_found_policy", [0x02, 0xAB, 0xCD, 0x54, 0x55, 0x56], [0xAB, 0xCD], 0, 1),
        (3, "pl3_found_nopolicy", [0x02, 0xAB, 0xCD, 0x54, 0x55, 0x56], [0xAB, 0xCD], 0, 0),
        (3, "pl3_notfound_policy", [0x51, 0x52, 0x53, 0x54, 0x55, 0x56], [0xAB, 0xCD], 0, 1),
        (3, "pl3_witness", [0x02, 0xAB, 0xCD, 0x54, 0x55, 0x56], [0xAB, 0xCD], 1, 1),
        (3, "pl3_two_policy", [0x02, 0xAB, 0xCD, 0x02, 0xAB, 0xCD], [0xAB, 0xCD], 0, 1),
    ]
    out = []
    for pl, name, script, sig, sv, constsc in specs:
        nd = ser_needle(bytes(sig))
        assert len(nd) == pl, (name, nd)
        out.append({"module": f"fadpol_pl{pl}", "fn": f"cell_fadpol_pl{pl}", "name": name,
                    "args": list(script) + list(nd) + [sv, constsc],
                    "expected": policy(bytes(script), nd, sv, constsc)})
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
