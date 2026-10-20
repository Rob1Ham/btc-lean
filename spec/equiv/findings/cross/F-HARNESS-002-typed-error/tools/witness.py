#!/usr/bin/env python3
"""F-HARNESS-002 bounded witness: typed classifier vs the real C and R shims.

For each `domain=abi` tape:
  * C leg  : load the Core shim and call `equiv_entry` (oracle for this probe).
  * R legs : (a) the pinned R shim as built today (narrow 3-token map), and
             (b) the F-HARNESS-002 classifier's kind, taken from the witness
                 binary that calls rbitcoin's public verify entry.
Compare `(result, error_kind)`.

`domain=direct` tapes are outside the ABI (the R shim rejects spk_len > 10000)
and are reported as classifier-only observations.

This is an advisory, off-pin probe. It does not claim R equivalence and does
not modify any pinned artifact.

Usage:
  python3 tools/witness.py \
      --core-so /tmp/opencode/cbuild/libequiv-core.so \
      --rust-so build/libequiv-rust-pinned.so \
      [--witness build/witness] [--cases cases.tsv] [--out logs/witness.tsv]
"""
from __future__ import annotations

import argparse
import ctypes
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE.parents[2] / "tools" / "tests"))
from e0_triple import legacy_tx, load  # noqa: E402

RESULT_NAMES = {0: "FAIL", 1: "PASS", 2: "BAD_INPUT", 3: "INTERNAL"}


def call(fn, tx: bytes, spk: bytes, amount: int, index: int, flags: int):
    tb = (ctypes.c_uint8 * len(tx)).from_buffer_copy(tx) if tx else None
    sb = (ctypes.c_uint8 * len(spk)).from_buffer_copy(spk) if spk else None
    kind = ctypes.c_int32(1)
    rc = fn(tb, len(tx), sb, len(spk), amount, index, flags, ctypes.byref(kind))
    return rc, kind.value


def parse_cases(path: Path):
    cases = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        name, spk_hex, domain, flags = line.split("\t")
        cases.append(
            (name, bytes.fromhex(spk_hex), domain, int(flags))
        )
    return cases


def run_witness(binary: Path, cases_path: Path):
    import subprocess

    out = subprocess.run(
        [str(binary), str(cases_path)],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    rows = {}
    header = None
    for line in out.splitlines():
        if header is None:
            header = line.split("\t")
            continue
        f = line.split("\t")
        if len(f) < 5:
            continue
        rows[f[0]] = {
            "spk_len": int(f[1]),
            "result": int(f[2]),
            "typed_kind": int(f[3]),
            "message": "\t".join(f[4:]),
        }
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cases", default=str(HERE / "cases.tsv"))
    ap.add_argument("--witness", default=str(HERE / "build" / "witness"))
    ap.add_argument("--core-so", default="/tmp/opencode/cbuild/libequiv-core.so")
    ap.add_argument("--rust-so", default=str(HERE / "build" / "libequiv-rust-pinned.so"))
    ap.add_argument(
        "--rust-typed-so",
        default=str(HERE / "build" / "libequiv-rust-typed.so"),
        help="pinned entry.rs + entry-typed.diff + typed_error.rs (proposal)",
    )
    ap.add_argument("--out", default=str(HERE / "logs" / "witness.tsv"))
    args = ap.parse_args()

    core = load(Path(args.core_so))
    rust = load(Path(args.rust_so))
    typed_shim = load(Path(args.rust_typed_so))
    cases_path = Path(args.cases)
    cases = parse_cases(cases_path)
    wit = run_witness(Path(args.witness), cases_path)
    tx = legacy_tx()

    header = [
        "name",
        "domain",
        "spk_len",
        "core_result",
        "core_kind",
        "r_result",
        "r_kind_current",
        "r_kind_typed",
        "r_kind_typed_shim",
        "typed_matches_core",
        "current_matches_core",
        "typed_shim_matches_core",
        "r_message",
    ]
    lines = ["\t".join(header)]
    abi_ok = True
    typed_ok = 0
    typed_total = 0
    current_ok = 0
    current_total = 0
    typed_shim_ok = 0
    for name, spk, domain, flags in cases:
        w = wit[name]
        if domain != "abi":
            lines.append(
                "\t".join(
                    [
                        name,
                        domain,
                        str(len(spk)),
                        "N/A",
                        "N/A",
                        "N/A",
                        "N/A",
                        str(w["typed_kind"]),
                        "N/A",
                        "N/A",
                        "N/A",
                        "N/A",
                        w["message"],
                    ]
                )
            )
            continue
        cr, ck = call(core, tx, spk, 0, 0, flags)
        rr, rk = call(rust, tx, spk, 0, 0, flags)
        tr, tk = call(typed_shim, tx, spk, 0, 0, flags)
        typed_total += 1
        if w["typed_kind"] == ck:
            typed_ok += 1
        current_total += 1
        if (rr, rk) == (cr, ck):
            current_ok += 1
        if (tr, tk) == (cr, ck):
            typed_shim_ok += 1
        tm = w["typed_kind"] == ck
        cm = (rr, rk) == (cr, ck)
        tsm = (tr, tk) == (cr, ck)
        abi_ok = abi_ok and tm and tsm and (w["result"] == cr)
        lines.append(
            "\t".join(
                [
                    name,
                    domain,
                    str(len(spk)),
                    str(cr),
                    str(ck),
                    str(rr),
                    str(rk),
                    str(w["typed_kind"]),
                    str(tk),
                    "yes" if tm else "NO",
                    "yes" if cm else "NO",
                    "yes" if tsm else "NO",
                    w["message"],
                ]
            )
        )

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text("\n".join(lines) + "\n")

    print("\t".join(header))
    for line in lines[1:]:
        f = line.split("\t")
        print(
            f"{f[0]:22s} {f[1]:6s} spk={f[2]:>5s} "
            f"C=({f[3]},{f[4]}) R=({f[5]},{f[6]}) "
            f"typed={f[7]:>2s} typed_shim={f[8]:>2s} "
            f"typed_ok={f[9]:3s} current_ok={f[10]:3s} "
            f"typed_shim_ok={f[11]:3s} msg={f[12][:60]}"
        )
    print()
    print(
        f"typed classifier vs Core: {typed_ok}/{typed_total} exact (result+kind)"
    )
    print(
        f"current pinned R shim vs Core: {current_ok}/{current_total} exact"
    )
    print(
        f"proposed typed shim (entry-typed.diff) vs Core: "
        f"{typed_shim_ok}/{current_total} exact"
    )
    print(f"wrote {args.out}")
    if not abi_ok:
        print("WITNESS_TYPED_MISMATCH")
        return 1
    if typed_ok != typed_total:
        print("WITNESS_TYPED_MISMATCH")
        return 1
    print("WITNESS_TYPED_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
