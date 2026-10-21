#!/usr/bin/env python3
"""Emit the SAW spec (src/cell.cry + src/cell.saw) for the SCR-074 arity table.

One llvm_verify per (row, leg).  Underflow rows take six symbolic seed bytes:
the claim is that the verdict is INVALID_STACK_OPERATION for *every* element
content, i.e. the guard is purely a depth test.  Boundary rows are closed
(fixed uniform seed) and assert the packed observable for the net depth.

Usage: python3 gen_saw.py [--check]
  --check  regenerate in memory and compare with the tracked files
"""
from __future__ import annotations
import csv
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TABLE = HERE.parent / "table.csv"
CRY = HERE / "cell.cry"
SAW = HERE / "cell.saw"

UNDERFLOW = 0x48


def obs(post: int) -> int:
    v = 1 | (post << 8)
    for i in range(post):
        v |= 1 << (11 + 8 * i)
    return v


def read_rows():
    with TABLE.open() as f:
        return list(csv.DictReader(f))


def fname(r) -> str:
    return f"cell_{r['op']}_{'ok' if r['kind'] == 'boundary' else 'd' + r['depth']}"


def cell_cry() -> str:
    return """module CellArity where

// SCR-074 — packed observables for the 2DROP..TUCK arity rows.
// Format is leaf_common.h:
//   failure  pack_fail: res:2 | error_kind:6<<2
//            INVALID_STACK_OPERATION = 18 -> 18 << 2 = 0x48.
//   boundary pack_vals: res:2 | err:6<<2 | depth:3<<8 | value-lo of slot i
//            at bit 11+8i.  The seed is the uniform one-byte 0x01, so every
//            live slot contributes 1 << (11+8i).
underflowv : [64]
underflowv = 0x0000000000000048

obs : [4] -> [64]
obs n =
  0x0000000000000001
  || ((zext n : [64]) << 8)
  || (if n > 0 then 0x0000000000000800 else 0)
  || (if n > 1 then 0x0000000000080000 else 0)
  || (if n > 2 then 0x0000000008000000 else 0)
  || (if n > 3 then 0x0000000800000000 else 0)
  || (if n > 4 then 0x0000080000000000 else 0)
  || (if n > 5 then 0x0008000000000000 else 0)
"""


def cell_saw(rows) -> str:
    out = ['import "cell.cry";', ""]
    for r in rows:
        fn = fname(r)
        out.append(f'mc_{fn} <- llvm_load_module "c_{fn}.bc";')
        out.append(f'ml_{fn} <- llvm_load_module "l_{fn}.bc";')
        out.append("")
    for r in rows:
        fn = fname(r)
        if r["kind"] == "underflow":
            out.append(f"let spec_{fn} = do {{")
            for i in range(6):
                out.append(f'  b{i} <- llvm_fresh_var "b{i}" (llvm_int 8);')
            out.append("  llvm_execute_func [" +
                       ", ".join(f"llvm_term b{i}" for i in range(6)) + "];")
            out.append("  llvm_return (llvm_term {{ underflowv }});")
            out.append("};")
        else:
            out.append(f"let spec_{fn} = do {{")
            out.append("  llvm_execute_func [];")
            out.append(f"  llvm_return (llvm_term {{{{ obs {r['post_depth']} }}}});")
            out.append("};")
        out.append("")
    for r in rows:
        fn = fname(r)
        out.append(f'llvm_verify mc_{fn} "{fn}" [] false spec_{fn} abc;')
        out.append(f'llvm_verify ml_{fn} "{fn}" [] false spec_{fn} abc;')
    out.append("")
    out.append('print "CELL_arity_SAW_GREEN";')
    return "\n".join(out) + "\n"


def main() -> int:
    rows = read_rows()
    cry, saw = cell_cry(), cell_saw(rows)
    if "--check" in sys.argv:
        bad = 0
        for path, want in ((CRY, cry), (SAW, saw)):
            if not path.is_file() or path.read_text() != want:
                print(f"STALE {path} (run gen_saw.py)")
                bad = 1
        if bad:
            return 1
        print(f"OK saw spec: {len(rows)} rows, {2 * len(rows)} llvm_verify")
        return 0
    CRY.write_text(cry)
    SAW.write_text(saw)
    print(f"wrote {CRY.name}, {SAW.name}: {len(rows)} rows, {2 * len(rows)} llvm_verify")
    return 0


if __name__ == "__main__":
    sys.exit(main())
