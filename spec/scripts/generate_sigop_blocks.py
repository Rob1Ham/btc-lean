#!/usr/bin/env python3
"""Reproduce the mined mainnet difficulty-one sigop boundary fixtures.

The recorded nonces were found by local SHA256d search. No weakened PoW
parameter or validator override is needed to check the resulting blocks.
Both are independent synthetic height-one forks of the real genesis block.
The zero-valued coinbase output has 1,000 CHECKMULTISIG opcodes, costing
80,000 legacy units. Appending one CHECKSIG raises that to 80,004.
"""

import argparse
import hashlib
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "spec/data/review/sigop-budget"
PARENT_HASH = "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f"
NONCES = {"at-limit": 2773634077, "over-limit": 955046782}


def sha256d(data):
    return hashlib.sha256(hashlib.sha256(data).digest()).digest()


def fixture(name, nonce):
    script = b"\xae" * 1000 + (b"\xac" if name == "over-limit" else b"")
    # v1, one null-prevout input, scriptSig 01 01, final sequence,
    # one zero-valued output, CompactSize script length, nLockTime=0.
    tx = (struct.pack("<I", 1) + b"\x01" + bytes(32) + b"\xff" * 4 +
          b"\x02\x01\x01" + b"\xff" * 4 + b"\x01" + bytes(8) +
          b"\xfd" + struct.pack("<H", len(script)) + script + bytes(4))
    header = (struct.pack("<i", 1) + bytes.fromhex(PARENT_HASH)[::-1] +
              sha256d(tx) + struct.pack("<III", 1231006506, 0x1d00ffff, nonce))
    target = 0xffff << (8 * (0x1d - 3))
    if len(header) != 80 or int.from_bytes(sha256d(header), "little") > target:
        raise ValueError(f"invalid mined header: {name}")
    return header + b"\x01" + tx


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if not args.check:
        DEST.mkdir(parents=True, exist_ok=True)
    for name, nonce in NONCES.items():
        data = fixture(name, nonce)
        path = DEST / f"{name}.raw"
        if args.check:
            if path.read_bytes() != data:
                raise ValueError(f"fixture drift: {path}")
        else:
            path.write_bytes(data)
        print(f"{name}: bytes={len(data)} hash={sha256d(data[:80])[::-1].hex()} "
              f"sha256={hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    main()
