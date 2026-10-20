#!/usr/bin/env python3
"""F-HARNESS-002 ABI-domain probes (advisory / off-pin).

The typed-error map is only half of F-HARNESS-002. The other half is the
shim's *domain*: several inputs that the normative tape.md allows are
rejected by the R shim as BAD_INPUT, or reach the engine where Core would
reject them. These probes record those divergences against the real Core
shim. They are not typed-error cases and do not affect the witness verdict.

Usage:
  python3 tools/abi_domain.py --core-so ... --rust-so ...
"""
from __future__ import annotations

import argparse
import ctypes
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE.parents[2] / "tools" / "tests"))
from e0_triple import legacy_tx, load  # noqa: E402

MAX_MONEY = 21_000_000 * 100_000_000


def call(fn, tx: bytes, spk: bytes, amount: int, index: int, flags: int):
    tb = (ctypes.c_uint8 * len(tx)).from_buffer_copy(tx) if tx else None
    sb = (ctypes.c_uint8 * len(spk)).from_buffer_copy(spk) if spk else None
    kind = ctypes.c_int32(1)
    rc = fn(tb, len(tx), sb, len(spk), amount, index, flags, ctypes.byref(kind))
    return rc, kind.value


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--core-so", default="/tmp/opencode/cbuild/libequiv-core.so")
    ap.add_argument("--rust-so", default=str(HERE / "build" / "libequiv-rust-pinned.so"))
    ap.add_argument("--out", default=str(HERE / "logs" / "abi-domain.tsv"))
    args = ap.parse_args()

    core = load(Path(args.core_so))
    rust = load(Path(args.rust_so))
    one = legacy_tx()
    two = legacy_tx(n_in=2)
    zero = legacy_tx(n_in=0)

    cases = [
        # name, tx, spk, amount, index, flags, expectation note
        ("amount_negative", one, b"\x51", -1, 0, 0, "contract: amount<0 is 2; both legs agree"),
        ("amount_over_max", one, b"\x51", MAX_MONEY + 1, 0, 0,
         "contract: amount>MAX_MONEY is 2; R has no upper-bound check"),
        ("flags_p2sh", one, b"\x51", 0, 0, 0x1,
         "flags=0x1 allowed by tape.md; R rejects every nonzero flag"),
        ("flags_taproot", one, b"\x51", 0, 0, 0x20000,
         "flags=0x20000 allowed by tape.md; R rejects every nonzero flag"),
        ("spk_over_10k", one, b"\x51" * 10001, 0, 0, 0,
         "tape.md: any spk length; Core hits SCRIPT_SIZE(5); R caps at 10000"),
        ("two_inputs_idx0", two, b"\x51", 0, 0, 0,
         "Core verifies input_index only; R rejects multi-input"),
        ("two_inputs_idx1", two, b"\x51", 0, 1, 0,
         "same tape, input_index=1; R rejects input_index!=0"),
        ("zero_inputs", zero, b"\x51", 0, 0, 0,
         "vin empty is 2 in both legs (control)"),
    ]

    lines = [
        "name\tcore_result\tcore_kind\tr_result\tr_kind\tagree\tnote"
    ]
    diverged = 0
    for name, tx, spk, amount, index, flags, note in cases:
        cr, ck = call(core, tx, spk, amount, index, flags)
        rr, rk = call(rust, tx, spk, amount, index, flags)
        agree = (cr, ck) == (rr, rk)
        if not agree:
            diverged += 1
        lines.append(
            f"{name}\t{cr}\t{ck}\t{rr}\t{rk}\t{'yes' if agree else 'NO'}\t{note}"
        )
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text("\n".join(lines) + "\n")

    for line in lines:
        print(line)
    print()
    print(f"domain divergences: {diverged}/{len(cases)}")
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
