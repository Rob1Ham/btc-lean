#!/usr/bin/env python3
"""Independent reference oracle for the checksig/serialize-scriptcode cell.

Restates interpreter.cpp:1282-1302 SerializeScriptCode and
SigHash.Ops.serializeScriptCodeL (Ops.lean:133-141):
  - CompactSize(scriptCode.size() - number_of_parsed_OP_CODESEPARATORs);
  - then the script bytes with each *parsed* 1-byte OP_CODESEPARATOR (0xab)
    spliced out; 0xab bytes inside push payloads are copied verbatim;
  - the reachable scriptCode is fully parseable (EvalScript rejects a
    malformed push before CHECKSIG); a parse failure is out of domain and the
    harness abstains with the sentinel 0xFFFFFFFFFFFFFFFF.

Packing (0xab has one-byte CompactSize in this bounded domain):
  prefix(8) | outn(4) << 8 | out[k] << (12 + 8k)
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


def serialize(s: bytes) -> int:
    it, nsep, beg = 0, 0, 0
    out = bytearray()
    while it < len(s):
        g = getop(s, it)
        if g is None:
            return 0xFFFFFFFFFFFFFFFF
        op, nx = g
        if op == 0xAB:
            out += s[beg:it]
            beg = nx
            nsep += 1
        it = nx
    out += s[beg:]
    prefix = len(s) - nsep
    assert prefix < 0xFD
    r = prefix & 0xFF
    r |= (len(out) & 15) << 8
    for k, b in enumerate(out):
        r |= b << (12 + 8 * k)
    return r


def scenarios():
    def sc(name, s):
        return {"module": "ser", "fn": "cell_ser", "name": name,
                "args": list(s), "expected": serialize(bytes(s))}

    return [
        sc("no_sep", [0x51, 0x52, 0x53, 0x54, 0x55, 0x56]),
        sc("sep0", [0xAB, 0x52, 0x53, 0x54, 0x55, 0x56]),
        sc("sep_mid", [0x51, 0x52, 0xAB, 0x54, 0x55, 0x56]),
        sc("sep_tail", [0x51, 0x52, 0x53, 0x54, 0x55, 0xAB]),
        sc("two_seps", [0xAB, 0x51, 0xAB, 0x53, 0x54, 0x55]),
        sc("three_seps", [0xAB, 0x51, 0xAB, 0x52, 0xAB, 0x53]),
        sc("all_seps", [0xAB, 0xAB, 0xAB, 0xAB, 0xAB, 0xAB]),
        sc("push_payload", [0x02, 0xAB, 0xAB, 0x54, 0x55, 0x56]),
        sc("pushdata1_payload", [0x4C, 0x02, 0xAB, 0xAB, 0x55, 0x56]),
        sc("pushdata2_payload", [0x4D, 0x02, 0x00, 0xAB, 0xAB, 0x56]),
        sc("pushdata4_payload", [0x4E, 0x01, 0x00, 0x00, 0x00, 0xAB]),
        sc("malformed_tail", [0x06, 0xAB, 0xAB, 0xAB, 0xAB, 0xAB]),
        sc("sep_then_malformed", [0xAB, 0x06, 0xAB, 0xAB, 0xAB, 0xAB]),
    ]


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
