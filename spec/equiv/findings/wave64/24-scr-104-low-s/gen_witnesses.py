#!/usr/bin/env python3
"""Generate the SCR-104 LOW_S seam witnesses and run probe_lows on each.

Usage: PROBE=/path/to/probe_lows python3 gen_witnesses.py > probe_witnesses.txt

The probe prints Core's pinned-libsecp CheckLowS result.  The Defs/Der columns
are computed here from the same raw magnitudes:
  Defs.checkLowS          = s <= floor(n/2)          (raw compare)
  Der.isLowDERSignature   = (s % n) <= floor(n/2)    (mod-n compare)
"""
import os
import subprocess
import sys

PROBE = os.environ.get("PROBE", "./probe_lows")
n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
half = n // 2
M = 1 << 256


def der_int(x: int) -> bytes:
    if x == 0:
        return b"\x00"
    b = x.to_bytes((x.bit_length() + 7) // 8, "big")
    if b[0] & 0x80:
        b = b"\x00" + b
    return b


def sig(r: int, s: int) -> bytes:
    R, S = der_int(r), der_int(s)
    body = b"\x02" + bytes([len(R)]) + R + b"\x02" + bytes([len(S)]) + S
    # Core's IsValidSignatureEncoding requires sig[1] == size - 3; the trailing
    # hashtype byte is outside the DER sequence.
    return bytes([0x30, len(body)]) + body + b"\x01"


CASES = [
    ("control_low", 1, half),
    ("control_high", 1, half + 1),
    ("s_eq_n", 1, n),
    ("s_eq_n_plus_1", 1, n + 1),
    ("s_max", 1, M - 1),
    ("s_n_minus_1", 1, n - 1),
    ("r_eq_n_s_high", n, half + 1),
    ("r_max_s_high", M - 1, half + 1),
    ("s_len33_2p256", 1, M),
    ("r_len33_s_high", M, half + 1),
]


def main() -> int:
    for name, r, s in CASES:
        h = sig(r, s).hex()
        out = subprocess.check_output([PROBE, h], text=True).strip()
        defs = int(s <= half)
        der = int((s % n) <= half)
        print(f"{name:18s} r_len={len(der_int(r)):2d} s_len={len(der_int(s)):2d} "
              f"defs_raw={defs} der_mod={der} | {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
