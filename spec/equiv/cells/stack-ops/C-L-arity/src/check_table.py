#!/usr/bin/env python3
"""Cross-check the SCR-074 arity table against both leaf sources.

The table (src/table.csv) is the row census.  This script fails the run if the
hand-written rows in c_leaf.cpp / l_leaf.cpp / fns.txt drift from it, if a
depth is missing, or if an expected observable is recomputed differently.

Usage: python3 check_table.py [--quiet]
"""
from __future__ import annotations
import csv
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TABLE = HERE.parent / "table.csv"
C = HERE / "c_leaf.cpp"
L = HERE / "l_leaf.cpp"
FNS = HERE / "fns.txt"

# pack_vals: res:2 | err:6<<2 | depth:3<<8 | value-lo of slot i at 11+8i.
def obs(post: int) -> int:
    v = 1 | (post << 8)
    for i in range(post):
        v |= 1 << (11 + 8 * i)
    return v

UNDERFLOW = 0x48  # res=0 | INVALID_STACK_OPERATION(18) << 2


def read_table():
    rows = []
    with TABLE.open() as f:
        for r in csv.DictReader(f):
            for k in ("wire", "core_case_line", "core_guard_line"):
                r[k] = int(r[k], 0)
            for k in ("arity", "depth"):
                r[k] = int(r[k])
            r["post_depth"] = int(r["post_depth"]) if r["post_depth"] else None
            for k in ("old_cell", "previously_missing"):
                r[k] = int(r[k])
            rows.append(r)
    return rows


def names(table):
    return [f"cell_{r['op']}_{'ok' if r['kind'] == 'boundary' else 'd' + str(r['depth'])}"
            for r in table]


def main() -> int:
    errs = []
    rows = read_table()
    if len(rows) != 55:
        errs.append(f"table has {len(rows)} rows, expected 55")
    by_op = {}
    for r in rows:
        by_op.setdefault(r["op"], []).append(r)
    for op, rs in by_op.items():
        arities = {r["arity"] for r in rs}
        if len(arities) != 1:
            errs.append(f"{op}: inconsistent arity {arities}")
        k = arities.pop()
        und = sorted(r["depth"] for r in rs if r["kind"] == "underflow")
        bnd = [r["depth"] for r in rs if r["kind"] == "boundary"]
        if und != list(range(k)):
            errs.append(f"{op}: underflow depths {und} != 0..{k-1}")
        if bnd != [k]:
            errs.append(f"{op}: boundary depth {bnd} != [{k}]")
        for r in rs:
            if r["kind"] == "underflow":
                if r["expect_hex"] != f"{UNDERFLOW:016x}":
                    errs.append(f"{op} d{r['depth']}: underflow expect != 0x48")
                if r["post_depth"] is not None:
                    errs.append(f"{op} d{r['depth']}: underflow has post_depth")
            elif r["expect_hex"] != f"{obs(r['post_depth']):016x}":
                errs.append(f"{op} d{r['depth']}: boundary expect mismatch")

    # The two columns must say exactly what the previous cell did and did not
    # cover: only the n=0 underflow probe existed.
    for r in rows:
        want_old = 1 if (r["kind"] == "underflow" and r["depth"] == 0) else 0
        if r["old_cell"] != want_old:
            errs.append(f"{r['op']} {r['kind']} d{r['depth']}: old_cell column")
        if r["previously_missing"] != (1 - want_old):
            errs.append(f"{r['op']} {r['kind']} d{r['depth']}: previously_missing column")

    ctext, ltext = C.read_text(), L.read_text()
    c_fail = {(m[0], int(m[1]), int(m[2])) for m in
              re.findall(r"ROW_FAIL\((\w+),\s*(\d+),\s*(\d+)\)", ctext)}
    c_ok = {(m[0], int(m[1])) for m in
            re.findall(r"ROW_OK\((\w+),\s*(\d+)\)", ctext)}
    l_fail = {(m[0], int(m[1], 0), int(m[2])) for m in
              re.findall(r"ROW_FAIL\((\w+),\s*(0x[0-9a-fA-F]+),\s*(\d+)\)", ltext)}
    l_ok = {(m[0], int(m[1], 0), int(m[2])) for m in
            re.findall(r"ROW_OK\((\w+),\s*(0x[0-9a-fA-F]+),\s*(\d+)\)", ltext)}

    want_c_fail = {(r["op"], r["arity"], r["depth"]) for r in rows if r["kind"] == "underflow"}
    want_c_ok = {(r["op"], r["post_depth"]) for r in rows if r["kind"] == "boundary"}
    want_l_fail = {(r["op"], r["wire"], r["depth"]) for r in rows if r["kind"] == "underflow"}
    want_l_ok = {(r["op"], r["wire"], r["arity"]) for r in rows if r["kind"] == "boundary"}
    for label, got, want in (("c ROW_FAIL", c_fail, want_c_fail),
                             ("c ROW_OK", c_ok, want_c_ok),
                             ("l ROW_FAIL", l_fail, want_l_fail),
                             ("l ROW_OK", l_ok, want_l_ok)):
        if got != want:
            errs.append(f"{label}: missing {sorted(want - got)} extra {sorted(got - want)}")

    want_fns = names(rows)
    got_fns = [x for x in FNS.read_text().split() if x]
    if got_fns != want_fns:
        errs.append("fns.txt does not match table order")
    if len(set(got_fns)) != len(got_fns):
        errs.append("duplicate function name in fns.txt")

    if errs:
        for e in errs:
            print(f"FAIL {e}")
        return 1
    n_und = sum(1 for r in rows if r["kind"] == "underflow")
    n_old = sum(r["old_cell"] for r in rows)
    print(f"OK table: {len(rows)} rows = {n_und} underflow + "
          f"{len(rows) - n_und} boundary; {n_old} previously covered, "
          f"{len(rows) - n_old} previously missing")
    return 0


if __name__ == "__main__":
    sys.exit(main())
