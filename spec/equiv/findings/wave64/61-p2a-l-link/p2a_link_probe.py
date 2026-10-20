#!/usr/bin/env python3
"""SCR-055 L-link probe: twin contract entry vs Core-derived P2A verdicts.

Runs only against a twin that has the hook filed in
`findings/handoffs/CELLS-to-TWIN-002-p2a-anchor-hook.md` applied:

    twin/runtime.inc
      is_pay_to_anchor(version, program, plen)          Defs.lean:523-526
      pay_to_anchor_branch(version, program, plen, is_p2sh)
                                                       Defs.lean:1319
      decode_witness_program(b, n, out)                Defs.lean:510-521

and the branch wired into `verify_script_full`'s bare-witness arm
(`twin/runtime.inc:806-810` in the pre-hook tree).

It builds `libtwin.so` from `<twin>/build/twin.cpp`, then calls the normative
`equiv_entry` on a small tape table.  Expected values come from the pinned
Core source:

  script.cpp:207-222         IsPayToAnchor (script and (version, program) forms)
  interpreter.cpp:2000       P2A branch, guarded by `!is_p2sh`
  interpreter.cpp:2047-2056  bare witness call site: WITNESS_MALLEATED first
  interpreter.cpp:2089-2102  P2SH witness call site, is_p2sh = true
  interpreter.cpp:2001-2007  DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM after P2A

Cases that reach the unimplemented witness engine (v0/v1 non-P2A, P2SH-wrapped
P2A) must return 3 (`TWIN_INVALID_UNSUPPORTED`); they are the E4 boundary, not
verdicts, and are reported but not counted.

Usage:
  python3 p2a_link_probe.py [--twin DIR] [--contract DIR] [--out DIR]

Exit: 0 if every in-scope case matches; 1 otherwise; 2 if the hook is absent.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
EQUIV = HERE.parents[2]           # spec/equiv
DEFAULT_TWIN = EQUIV / "twin"
DEFAULT_CONTRACT = EQUIV / "contract"

F_P2SH = 0x000001
F_WITNESS = 0x000800
F_DUWP = 0x001000
F_CLEANSTACK = 0x000100

ERR_OK = 0
ERR_DUWP = 34
ERR_WP_MISMATCH = 40
ERR_MALLEATED = 41


def cs(n: int) -> bytes:
    if n < 0xFD:
        return bytes([n])
    if n <= 0xFFFF:
        return b"\xfd" + n.to_bytes(2, "little")
    if n <= 0xFFFFFFFF:
        return b"\xfe" + n.to_bytes(4, "little")
    return b"\xff" + n.to_bytes(8, "little")


def make_tx(ss: bytes, witness_items: list[bytes] | None = None) -> bytes:
    """Canonical TX_WITH_WITNESS, one input (same shape as twin/corpus_probe)."""
    out = (2).to_bytes(4, "little", signed=True)
    if witness_items is not None:
        out += b"\x00\x01"
    out += cs(1)
    out += b"\x00" * 32 + b"\xff" * 4
    out += cs(len(ss)) + ss + b"\xff" * 4
    out += cs(1) + (0).to_bytes(8, "little", signed=True) + cs(0)
    if witness_items is not None:
        out += cs(len(witness_items))
        for item in witness_items:
            out += cs(len(item)) + item
    out += (0).to_bytes(4, "little")
    return out


def pushb(data: bytes) -> bytes:
    assert len(data) <= 75
    return bytes([len(data)]) + data


def hash160(data: bytes) -> bytes:
    return hashlib.new("ripemd160", hashlib.sha256(data).digest()).digest()


P2A = bytes([0x51, 0x02, 0x4E, 0x73])          # OP_1 PUSH2 4e73
P2A_BAD = bytes([0x51, 0x02, 0x4E, 0x74])      # v1 program 4e74: not P2A
P2WPKH = bytes([0x00, 0x14]) + bytes([0x11]) * 20


def p2sh_wrap(redeem: bytes) -> bytes:
    return bytes([0xA9, 0x14]) + hash160(redeem) + bytes([0x87])


CASES = [
    # id, spk, scriptSig, witness, flags, expected result, expected error
    ("bare-p2a-no-witness", P2A, b"", None, F_P2SH | F_WITNESS, 1, ERR_OK),
    ("bare-p2a-empty-witness", P2A, b"", [], F_P2SH | F_WITNESS, 1, ERR_OK),
    ("bare-p2a-one-item-witness", P2A, b"", [b"\x01"],
     F_P2SH | F_WITNESS, 1, ERR_OK),
    ("bare-p2a-discourage-uwp", P2A, b"", None,
     F_P2SH | F_WITNESS | F_DUWP, 1, ERR_OK),
    ("bare-p2a-cleanstack", P2A, b"", None,
     F_P2SH | F_WITNESS | F_CLEANSTACK, 1, ERR_OK),
    ("bare-p2a-malleated-scriptSig", P2A, b"\x00", None,
     F_P2SH | F_WITNESS, 0, ERR_MALLEATED),
    ("p2sh-wrapped-p2a", p2sh_wrap(P2A), pushb(P2A), None,
     F_P2SH | F_WITNESS, 1, ERR_OK),
    ("p2sh-wrapped-p2a-discourage", p2sh_wrap(P2A), pushb(P2A), None,
     F_P2SH | F_WITNESS | F_DUWP, 0, ERR_DUWP),
    ("bare-v1-2byte-not-p2a", P2A_BAD, b"", None, F_P2SH | F_WITNESS, 1, ERR_OK),
    ("bare-v0-20byte", P2WPKH, b"", [], F_P2SH | F_WITNESS, 0, ERR_WP_MISMATCH),
]
# Cases whose Core verdict needs the (unimplemented) witness engine: the twin
# must stay at result 3, and the row/cell makes no claim about them.
E4_BOUNDARY = {"bare-v1-2byte-not-p2a", "bare-v0-20byte"}


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--twin", default=str(DEFAULT_TWIN))
    ap.add_argument("--contract", default=str(DEFAULT_CONTRACT))
    ap.add_argument("--out", default=None, help="build dir (default <twin>/build)")
    args = ap.parse_args(argv)

    twin = Path(args.twin)
    build = Path(args.out) if args.out else twin / "build"
    src = build / "twin.cpp"
    if not src.is_file():
        print(f"missing {src}; run twin/gen.py first", file=sys.stderr)
        return 2
    text = src.read_text(encoding="utf-8")
    for sym in ("is_pay_to_anchor", "pay_to_anchor_branch",
                "decode_witness_program"):
        if sym not in text:
            print(f"hook absent: {sym} not in {src}\n"
                  f"apply findings/handoffs/CELLS-to-TWIN-002-p2a-anchor-hook.md",
                  file=sys.stderr)
            return 2

    lib = build / "libtwin_p2a_probe.so"
    subprocess.run(
        ["/usr/bin/clang++-20", "-std=c++17", "-O2", "-fno-strict-aliasing",
         "-shared", "-fPIC", "-I", args.contract, "-o", str(lib), str(src)],
        check=True,
    )

    fn = ctypes.CDLL(str(lib))
    fn.equiv_entry.restype = ctypes.c_int
    fn.equiv_entry.argtypes = [
        ctypes.POINTER(ctypes.c_uint8), ctypes.c_uint64,
        ctypes.POINTER(ctypes.c_uint8), ctypes.c_uint64,
        ctypes.c_int64, ctypes.c_uint32, ctypes.c_uint64,
        ctypes.POINTER(ctypes.c_int32),
    ]

    ok = 0
    failed = 0
    print(f"{'case':32} {'rc':>3} {'err':>4} {'expect':>8}  verdict")
    for cid, spk, ss, wit, flags, exp_rc, exp_err in CASES:
        tx = make_tx(ss, wit)
        txb = (ctypes.c_uint8 * len(tx)).from_buffer_copy(tx)
        spkb = (ctypes.c_uint8 * len(spk)).from_buffer_copy(spk)
        err = ctypes.c_int32(-1)
        rc = fn.equiv_entry(txb, len(tx), spkb, len(spk), 0, 0, flags,
                            ctypes.byref(err))
        exp = f"{exp_rc}/{exp_err}"
        if cid in E4_BOUNDARY:
            good = rc == 3
            mark = "E4 boundary (result 3)" if good else "MISMATCH"
        else:
            good = (rc, err.value) == (exp_rc, exp_err)
            mark = "match" if good else "MISMATCH"
        ok += 1 if good else 0
        failed += 0 if good else 1
        print(f"{cid:32} {rc:>3} {err.value:>4} {exp:>8}  {mark}")

    print(f"\n{ok}/{len(CASES)} cases match "
          f"({len(CASES) - len(E4_BOUNDARY)} Core verdicts, "
          f"{len(E4_BOUNDARY)} E4 boundaries)")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
