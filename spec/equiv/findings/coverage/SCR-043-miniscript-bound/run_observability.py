#!/usr/bin/env python3
"""Run the SCR-043 observability corpus through three Core shims over the
normative ABI v2 (`equiv_entry`), and report:

  * base            vs mut-pubkeys  : expected identical everywhere
  * base            vs mut-stack    : expected to differ on multi_a-n999-k1
                                      (positive control for non-vacuity)

Usage:
  python3 tapegen.py --out corpus.json
  python3 run_observability.py --corpus corpus.json \
      --lib base=...so --lib mut-pubkeys=...so --lib mut-stack=...so \
      --tsv results.tsv

Exit 0 iff base == mut-pubkeys on every case and base != mut-stack on at
least one case.
"""
from __future__ import annotations

import argparse
import ctypes
import json
import sys


def load(path: str):
    lib = ctypes.CDLL(path)
    fn = lib.equiv_entry
    fn.restype = ctypes.c_int
    fn.argtypes = [
        ctypes.POINTER(ctypes.c_uint8), ctypes.c_uint64,
        ctypes.POINTER(ctypes.c_uint8), ctypes.c_uint64,
        ctypes.c_int64, ctypes.c_uint32, ctypes.c_uint64,
        ctypes.POINTER(ctypes.c_int32),
    ]
    return fn


def call(fn, case: dict) -> tuple[int, int]:
    tx = bytes.fromhex(case["tx"])
    spk = bytes.fromhex(case["spk"])
    tb = (ctypes.c_uint8 * len(tx)).from_buffer_copy(tx)
    sb = (ctypes.c_uint8 * len(spk)).from_buffer_copy(spk) if spk else None
    kind = ctypes.c_int32(-1)
    rc = fn(tb, len(tx), sb, len(spk), case["amount"], case["index"],
            case["flags"], ctypes.byref(kind))
    return rc, kind.value


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--lib", action="append", required=True,
                    help="name=path (repeatable)")
    ap.add_argument("--tsv", default="-")
    args = ap.parse_args()

    corpus = json.load(open(args.corpus))
    libs = []
    for spec in args.lib:
        name, _, path = spec.partition("=")
        libs.append((name, load(path)))

    rows = []
    for case in corpus:
        verdicts = {name: call(fn, case) for name, fn in libs}
        rows.append((case["name"], verdicts))

    out = args.tsv
    fh = sys.stdout if out == "-" else open(out, "w")
    try:
        names = [n for n, _ in libs]
        fh.write("case\t" + "\t".join(names) + "\n")
        for name, verdicts in rows:
            fh.write(name + "\t" + "\t".join(
                f"{verdicts[n][0]}/{verdicts[n][1]}" for n in names) + "\n")
    finally:
        if fh is not sys.stdout:
            fh.close()

    base = [n for n, _ in libs if n == "base"]
    if not base:
        print("need a --lib base=... entry", file=sys.stderr)
        return 2
    base = "base"
    pub_diff = [name for name, v in rows if v[base] != v.get("mut-pubkeys")]
    stack_diff = [name for name, v in rows if v[base] != v.get("mut-stack")]

    # Positive control: a constant the interpreter does read must change a
    # verdict.  At 999 keys the base build reaches EVAL_FALSE and the
    # MAX_STACK_SIZE=999 build reports STACK_SIZE, for both thresholds.
    expected_stack_diff = {"multi_a-n999-k1", "multi_a-n999-k999"}

    print(f"cases: {len(rows)}")
    print(f"base vs mut-pubkeys differing cases: {len(pub_diff)} {pub_diff}")
    print(f"base vs mut-stack  differing cases: {len(stack_diff)} {stack_diff}")

    ok = not pub_diff and set(stack_diff) == expected_stack_diff
    print("SCR043_OBSERVABILITY_OK" if ok else "SCR043_OBSERVABILITY_FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
