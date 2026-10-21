#!/usr/bin/env python3
"""SCR-043 observability corpus: tapscript script-path spends carrying
`multi_a`-shaped scripts, encoded as the normative ABI tape
(tx_bytes, spk, amount, input_index, flags).

Self-contained: pure-Python secp256k1 point arithmetic is used only to build
a *valid* BIP341 taproot commitment, so the Core shim actually reaches
EvalScript.  No signature is produced; every `multi_a` slot is the empty
vector, which BIP342 treats as "not signed" (success=false) and which does
not abort execution, so the whole script is traversed and the stack-limit
path is reached.

Output is deterministic JSON: a list of {name, tx, spk, amount, index, flags}.
Byte strings are lowercase hex.

Usage: python3 tapegen.py [--out corpus.json]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct

# ---------------------------------------------------------------- secp256k1
P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
G = (0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
     0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8)


def _inv(a: int) -> int:
    return pow(a, P - 2, P)


def _add(p, q):
    if p is None:
        return q
    if q is None:
        return p
    if p[0] == q[0]:
        if (p[1] + q[1]) % P == 0:
            return None
        lam = (3 * p[0] * p[0]) * _inv(2 * p[1]) % P
    else:
        lam = (q[1] - p[1]) * _inv(q[0] - p[0]) % P
    x = (lam * lam - p[0] - q[0]) % P
    return (x, (lam * (p[0] - x) - p[1]) % P)


def _mul(k: int, p):
    r = None
    while k:
        if k & 1:
            r = _add(r, p)
        p = _add(p, p)
        k >>= 1
    return r


def _lift_x(x: int):
    y2 = (pow(x, 3, P) + 7) % P
    y = pow(y2, (P + 1) // 4, P)
    if (y * y) % P != y2:
        raise ValueError("x is not on the curve")
    return (x, y if y % 2 == 0 else P - y)


def tagged_hash(tag: str, msg: bytes) -> bytes:
    th = hashlib.sha256(tag.encode()).digest()
    return hashlib.sha256(th + th + msg).digest()


def compact_size(n: int) -> bytes:
    if n < 0xFD:
        return bytes([n])
    if n <= 0xFFFF:
        return b"\xfd" + struct.pack("<H", n)
    if n <= 0xFFFFFFFF:
        return b"\xfe" + struct.pack("<I", n)
    return b"\xff" + struct.pack("<Q", n)


def pushnum(k: int) -> bytes:
    """Minimal CScriptNum push (CScript << int64_t)."""
    if k == 0:
        return b"\x00"
    if 1 <= k <= 16:
        return bytes([0x50 + k])
    neg = k < 0
    a = -k if neg else k
    out = bytearray()
    while a:
        out.append(a & 0xFF)
        a >>= 8
    if out[-1] & 0x80:
        out.append(0x80 if neg else 0x00)
    elif neg:
        out[-1] |= 0x80
    return bytes([len(out)]) + bytes(out)


def push_bytes(b: bytes) -> bytes:
    assert len(b) < 0x4C
    return bytes([len(b)]) + b


# ---------------------------------------------------------------- taproot
def key_pairs(count: int):
    """count distinct x-only keys (x-coordinates of G, 2G, 3G, ...)."""
    out = []
    pt = G
    for _ in range(count):
        out.append(pt[0].to_bytes(32, "big"))
        pt = _add(pt, G)
    return out


def taproot_spk_and_witness(script: bytes, args: list[bytes], internal_x: bytes):
    """Return (spk, witness stack) for a single-leaf script-path spend."""
    p = _lift_x(int.from_bytes(internal_x, "big"))
    leaf_version = 0xC0
    leaf_hash = tagged_hash(
        "TapLeaf", bytes([leaf_version]) + compact_size(len(script)) + script
    )
    merkle_root = leaf_hash
    tweak = int.from_bytes(
        tagged_hash("TapTweak", internal_x + merkle_root), "big"
    )
    q = _add(p, _mul(tweak, G))
    if q is None:
        raise ValueError("tweak produced the point at infinity")
    control = bytes([leaf_version | (q[1] & 1)]) + internal_x
    spk = b"\x51\x20" + q[0].to_bytes(32, "big")
    return spk, list(args) + [script, control]


def witness_tx(stack: list[bytes], flags_version: int = 2) -> bytes:
    """1-input, 1-output tx carrying `stack` for input 0.

    An all-empty witness stack cannot be encoded in TX_WITH_WITNESS (Core
    throws "Superfluous witness record"), so that case uses the legacy
    (non-extended) serialization.
    """
    out = struct.pack("<i", flags_version)
    if stack:
        out += b"\x00\x01"                   # marker + witness flag
    out += compact_size(1)                   # vin count
    out += b"\x00" * 32 + struct.pack("<I", 0xFFFFFFFF)
    out += compact_size(0)                   # empty scriptSig
    out += struct.pack("<I", 0xFFFFFFFF)     # nSequence
    out += compact_size(1)                   # vout count
    out += struct.pack("<q", 0) + compact_size(0)
    if stack:
        out += compact_size(len(stack))
        for item in stack:
            out += compact_size(len(item)) + item
    out += struct.pack("<I", 0)              # nLockTime
    return out


def multi_a_script(n_keys: int, threshold: int, keys: list[bytes]) -> bytes:
    s = push_bytes(keys[0]) + b"\xac"        # <key0> OP_CHECKSIG
    for k in keys[1:n_keys]:
        s += push_bytes(k) + b"\xba"         # <keyi> OP_CHECKSIGADD
    return s + pushnum(threshold) + b"\x9c"  # <k> OP_NUMEQUAL


FLAGS = 0x000001 | 0x000800 | 0x020000       # P2SH | WITNESS | TAPROOT


def build_corpus() -> list[dict]:
    internal_x = G[0].to_bytes(32, "big")
    keys = key_pairs(1005)
    cases = []

    def add(name, script, args, spk=None, witness=None, flags=FLAGS):
        if spk is None:
            spk, witness = taproot_spk_and_witness(script, args, internal_x)
        cases.append({
            "name": name,
            "tx": witness_tx(witness).hex(),
            "spk": spk.hex(),
            "amount": 0,
            "index": 0,
            "flags": flags,
        })

    # Control cases: legacy verdicts and a taproot script that must pass.
    add("legacy-OP_1", b"", [], spk=b"\x51", witness=[], flags=0)
    add("legacy-OP_0", b"", [], spk=b"\x00", witness=[], flags=0)
    add("tap-trivial-OP_1", b"\x51", [])

    for n in (1, 2, 20, 21, 998, 999, 1000, 1001, 1005):
        script = multi_a_script(n, 1, keys)
        add(f"multi_a-n{n}-k1", script, [b""] * n)

    script = multi_a_script(999, 999, keys)
    add("multi_a-n999-k999", script, [b""] * 999)

    # Sanity: a tampered control-block parity must fail the commitment check.
    script = multi_a_script(2, 1, keys)
    spk, witness = taproot_spk_and_witness(script, [b"", b""], internal_x)
    witness = list(witness)
    witness[-1] = bytes([witness[-1][0] ^ 1]) + witness[-1][1:]
    add("control-parity-flipped", script, None, spk=spk, witness=witness)

    return cases


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="corpus.json")
    args = ap.parse_args()
    corpus = build_corpus()
    with open(args.out, "w") as f:
        json.dump(corpus, f, indent=1, sort_keys=True)
        f.write("\n")
    print(f"wrote {len(corpus)} cases to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
