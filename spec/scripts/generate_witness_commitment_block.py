#!/usr/bin/env python3
"""Reproduce the R05 nonzero-valued witness commitment fixture.

The header has real difficulty-one PoW. Height 481824 is encoded in the
coinbase to exercise active SegWit; its parent is real genesis, so this is
a conditional validator fixture, not a reachable mainnet-chain claim.
"""

import argparse
import hashlib
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "spec/data/review/witness-commitment/nonzero.raw"
NONCE = 2125207511


def sha256d(data):
    return hashlib.sha256(hashlib.sha256(data).digest()).digest()


def fixture():
    def commitment(reserved):
        return bytes.fromhex("6a24aa21a9ed")+sha256d(bytes(32)+reserved)

    script_sig = b"\x03"+(481824).to_bytes(3, "little")
    scripts = [commitment(bytes(32)), commitment(bytes([1])*32)+b"\x51"]
    # Exactly 12.5 BTC, split across two nonzero commitment outputs. The last
    # matching output binds the nonzero reserved value; its trailing byte is legal.
    outputs = b"".join(struct.pack("<q", value)+bytes([len(script)])+script
                       for value, script in zip([1, 1249999999], scripts))
    base = (struct.pack("<I", 1)+b"\x01"+bytes(32)+b"\xff"*4+
            bytes([len(script_sig)])+script_sig+b"\xff"*4+b"\x02"+outputs+bytes(4))
    witness = base[:4]+b"\x00\x01"+base[4:-4]+b"\x01\x20"+bytes([1])*32+base[-4:]
    parent = bytes.fromhex("000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f")[::-1]
    header = struct.pack("<I", 4)+parent+sha256d(base)+struct.pack("<III", 1231006506, 0x1d00ffff, NONCE)
    if len(header) != 80 or int.from_bytes(sha256d(header), "little") > 0xffff << (8*26):
        raise ValueError("invalid mined proof of work")
    return header+b"\x01"+witness


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = fixture()
    if args.check:
        if DEST.read_bytes() != data:
            raise ValueError("fixture drift")
    else:
        DEST.parent.mkdir(parents=True, exist_ok=True)
        DEST.write_bytes(data)
    print(f"witness-commitment: bytes={len(data)} hash={sha256d(data[:80])[::-1].hex()} "
          f"sha256={hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    main()
