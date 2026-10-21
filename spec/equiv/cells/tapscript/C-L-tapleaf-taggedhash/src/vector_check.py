#!/usr/bin/env python3
"""Published-vector corroboration for the TapLeaf preimage cell.

THIS IS NOT A PROOF.  It is an independent executable check that the byte
stream described by this cell, when fed to a real SHA-256 implementation,
reproduces the leaf hashes published in Bitcoin Core's
`src/test/data/bip341_wallet_vectors.json` at commit cce32b168.  The proofs in
this cell are the Alive2/SAW artifacts; this script only shows that the
specified construction is the one BIP341 vectors expect.

Vectors are embedded verbatim (script hex, leaf version) so the check is
reproducible without the Core checkout; the expected hashes are copied from
the same file's `intermediary.leafHashes`.

Usage: python3 src/vector_check.py
"""
from __future__ import annotations

import hashlib

TAG = b"TapLeaf"


def compact_size(n: int) -> bytes:
    if n < 0xFD:
        return bytes([n])
    if n <= 0xFFFF:
        return b"\xfd" + n.to_bytes(2, "little")
    if n <= 0xFFFFFFFF:
        return b"\xfe" + n.to_bytes(4, "little")
    return b"\xff" + n.to_bytes(8, "little")


def tapleaf_preimage(control0: int, script: bytes) -> bytes:
    # hash.cpp:85-91: one SHA256("TapLeaf"), written twice (64 bytes), then
    # interpreter.cpp:1882-1884: serU8(control[0] & 0xfe), CompactSize, script.
    taghash = hashlib.sha256(TAG).digest()
    return taghash + taghash + bytes([control0 & 0xFE]) + compact_size(len(script)) + script


def tapleaf_digest(control0: int, script: bytes) -> str:
    return hashlib.sha256(tapleaf_preimage(control0, script)).hexdigest()


# (label, leafVersion from the vector, script hex, expected leafHash)
VECTORS = [
    (
        "bip341 wallet vector 1 (single leaf)",
        192,
        "20d85a959b0290bf19bb89ed43c916be835475d013da4b362117393e25a48229b8ac",
        "5b75adecf53548f3ec6ad7d78383bf84cc57b55a3127c72b9a2481752dd88b21",
    ),
    (
        "bip341 wallet vector 3 leaf 0 (version 0xc0)",
        192,
        "20387671353e273264c495656e27e39ba899ea8fee3bb69fb2a680e22093447d48ac",
        "8ad69ec7cf41c2a4001fd1f738bf1e505ce2277acdcaa63fe4765192497f47a7",
    ),
    (
        "bip341 wallet vector 3 leaf 1 (version 0xfa)",
        250,
        "06424950333431",
        "f224a923cd0021ab202ab139cc56802ddb92dcfc172b9212261a539df79a112a",
    ),
    (
        "bip341 wallet vector 4 leaf 1 (OP_RETURN leaf)",
        192,
        "07546170726f6f74",
        "2cb2b90daa543b544161530c925f285b06196940d6085ca9474d41dc3822c5cb",
    ),
]

# Negative controls: each must NOT reproduce the published digest, otherwise
# the vector check would not distinguish the specified construction from a
# plausible mistake.
def wrong_single_prefix(control0: int, script: bytes) -> str:
    t = hashlib.sha256(TAG).digest()
    return hashlib.sha256(t + bytes([control0 & 0xFE]) + compact_size(len(script)) + script).hexdigest()


def wrong_nul_terminated_tag(control0: int, script: bytes) -> str:
    t = hashlib.sha256(TAG + b"\x00").digest()
    return hashlib.sha256(t + t + bytes([control0 & 0xFE]) + compact_size(len(script)) + script).hexdigest()


def wrong_version_before_prefix(control0: int, script: bytes) -> str:
    t = hashlib.sha256(TAG).digest()
    return hashlib.sha256(bytes([control0 & 0xFE]) + t + t + compact_size(len(script)) + script).hexdigest()


def wrong_unmasked_control(control0: int, script: bytes) -> str:
    t = hashlib.sha256(TAG).digest()
    return hashlib.sha256(t + t + bytes([control0 | 1]) + compact_size(len(script)) + script).hexdigest()


def main() -> int:
    print("# TapLeaf preimage: published BIP341 wallet-vector corroboration (NOT a proof)")
    print("# source: bitcoin/bitcoin cce32b168 src/test/data/bip341_wallet_vectors.json")
    print("# taghash = sha256(b'TapLeaf') =", hashlib.sha256(TAG).hexdigest())
    print()
    failures = 0
    for label, version, script_hex, expected in VECTORS:
        script = bytes.fromhex(script_hex)
        # The control block byte carries the parity bit; exercise both
        # parities and confirm the mask makes them identical.
        d0 = tapleaf_digest(version, script)
        d1 = tapleaf_digest(version | 1, script)
        ok = d0 == expected and d1 == expected
        failures += 0 if ok else 1
        print(f"{'PASS' if ok else 'FAIL'} {label}")
        print(f"  script({len(script)} B) = {script_hex}")
        print(f"  leafVersion = 0x{version:02x}; control bytes 0x{version:02x}/0x{version | 1:02x}")
        print(f"  computed = {d0}")
        print(f"  expected = {expected}")
        print(f"  control[0]&0xfe parity check: {d1}")
        # Negative controls (must differ).
        for name, fn in (
            ("single tag prefix", wrong_single_prefix),
            ("NUL-terminated tag", wrong_nul_terminated_tag),
            ("version before prefix", wrong_version_before_prefix),
            ("unmasked control byte", wrong_unmasked_control),
        ):
            bad = fn(version, script)
            if bad == expected:
                print(f"  NEGATIVE-CONTROL FAILURE: {name} reproduced the vector")
                failures += 1
        print()
    print("VECTOR_CHECK=" + ("PASS" if failures == 0 else f"FAIL({failures})"))
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
