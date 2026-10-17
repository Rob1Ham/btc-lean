#!/usr/bin/env python3
"""BIP32 differential cross-check: corpus, regtest Core, optional Lean dump.

What it checks
--------------
1. ``bip32.jsonl`` is internally consistent: every valid row is recomputed
   from its seed and path (master key, CKDpriv, xprv/xpub serialization,
   compressed public key).  Every vector-5 row must be rejected by an
   independent extended-key decoder.
2. With ``--core`` a disposable regtest ``bitcoind`` is started.  For each
   corpus row, three fixed descriptors (``wpkh``, ``pkh``, ``sh(wpkh)``)
   are expanded with ``deriveaddresses`` and imported into a watch-only
   descriptor wallet.  ``getaddressinfo`` supplies the public key Core
   actually parsed from the regtest re-encoding of the corpus xpub.
   Addresses are compared with locally computed ones.
3. Range descriptors rooted at selected corpus xpubs are expanded over
   ``[0,4]`` and the resulting child public keys/addresses are compared
   with local CKDpub.  This is the only place where public child derivation
   is exercised.
4. With ``--lean-dump PATH`` a JSONL dump produced by the Lean side is
   compared against the same corpus.  ``--write-lean-template PATH`` emits
   the documented input shape for that dump (see below).

Regtest key-version note
------------------------
BIP32 vectors carry mainnet ``xpub``/``xprv``.  Core's descriptor parser is
chain-aware: on regtest it rejects mainnet versions (``DecodeExtPubKey``
checks ``chainparams``).  The harness therefore re-encodes the same 78-byte
payload with the regtest version bytes (``tpub`` 0x043587cf, ``tprv``
0x04358394).  Only the four version bytes and the Base58Check checksum
change; depth, fingerprint, child number, chain code and key data are
identical.  This is recorded in every ``bip32_core.jsonl`` row.

Lean dump format (JSONL)
------------------------
One object per line, no wrapper::

    {"id":"bip32-1-m",
     "path":"m",
     "pubkey_hex":"0339a360...85c2",
     "addresses":{"wpkh":"bcrt1q...","pkh":"m...","sh_wpkh":"2..."}}

``id`` is required and must match a valid corpus row.  ``pubkey_hex`` and
each address field are optional; present values are compared, absent ones
are skipped.  ``--write-lean-template PATH`` writes one line per valid
corpus row with empty ``pubkey_hex`` and empty address strings, plus the
seed and official xpub so the Lean runner knows what to derive.  Comparison
ignores the template's input-only fields (``seed_hex``,
``expected_xpub``) and only reads the four output fields above.

Usage
-----
    python3 bip32_check.py --check-corpus
    python3 bip32_check.py --core --out ../../data/wallet/bip32_core.jsonl
    python3 bip32_check.py --core --smoke
    python3 bip32_check.py --write-lean-template /tmp/bip32-lean-template.jsonl
    python3 bip32_check.py --lean-dump /tmp/bip32-lean.jsonl

Only the Python 3 standard library is used.
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

from bitcoind import Bitcoind, RPCError

SPEC_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CORPUS = SPEC_ROOT / "data" / "wallet" / "bip32.jsonl"
DEFAULT_OUTPUT = SPEC_ROOT / "data" / "wallet" / "bip32_core.jsonl"
DEFAULT_MANIFEST = SPEC_ROOT / "data" / "wallet" / "bip32_core.manifest.json"
DEFAULT_BITCOIND = "build/scratch/core-build/build/bin/bitcoind"
CORE_COMMIT = "cce32b16874e"

B58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
XPUB_VERSION = bytes.fromhex("0488b21e")
XPRV_VERSION = bytes.fromhex("0488ade4")
TPUB_VERSION = bytes.fromhex("043587cf")
TPRV_VERSION = bytes.fromhex("04358394")
BECH32_CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

# secp256k1
P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
GX = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
GY = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8
G = (GX, GY)

ADDRESS_TYPES = ("wpkh", "pkh", "sh_wpkh")


class CheckError(RuntimeError):
    """Raised when a corpus or Core observation disagrees."""


# ---------------------------------------------------------------------------
# Encodings and curve arithmetic
# ---------------------------------------------------------------------------


def sha256d(data: bytes) -> bytes:
    return hashlib.sha256(hashlib.sha256(data).digest()).digest()


def hash160(data: bytes) -> bytes:
    return hashlib.new("ripemd160", hashlib.sha256(data).digest()).digest()


def b58decode(text: str) -> bytes:
    number = 0
    for char in text:
        try:
            number = number * 58 + B58_ALPHABET.index(char)
        except ValueError as exc:
            raise CheckError(f"invalid Base58 character {char!r}") from exc
    body = number.to_bytes((number.bit_length() + 7) // 8, "big")
    return b"\x00" * (len(text) - len(text.lstrip("1"))) + body


def b58encode(data: bytes) -> str:
    number = int.from_bytes(data, "big")
    out = ""
    while number:
        number, digit = divmod(number, 58)
        out = B58_ALPHABET[digit] + out
    return "1" * (len(data) - len(data.lstrip(b"\x00"))) + out


def b58check_encode(payload: bytes) -> str:
    return b58encode(payload + sha256d(payload)[:4])


def b58check_decode(text: str) -> bytes:
    raw = b58decode(text)
    if len(raw) < 5:
        raise CheckError(f"Base58Check value too short: {text!r}")
    payload, checksum = raw[:-4], raw[-4:]
    if sha256d(payload)[:4] != checksum:
        raise CheckError(f"bad Base58Check checksum: {text!r}")
    return payload


def bech32_polymod(values: Iterable[int]) -> int:
    generators = (0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3)
    chk = 1
    for value in values:
        top = chk >> 25
        chk = ((chk & 0x1FFFFFF) << 5) ^ value
        for index in range(5):
            if (top >> index) & 1:
                chk ^= generators[index]
    return chk


def bech32_hrp_expand(hrp: str) -> list[int]:
    return [ord(char) >> 5 for char in hrp] + [0] + [ord(char) & 31 for char in hrp]


def convertbits(data: Iterable[int], from_bits: int, to_bits: int, pad: bool = True) -> list[int]:
    acc = 0
    bits = 0
    ret: list[int] = []
    maxv = (1 << to_bits) - 1
    for value in data:
        if value < 0 or value >> from_bits:
            raise CheckError("invalid value for convertbits")
        acc = (acc << from_bits) | value
        bits += from_bits
        while bits >= to_bits:
            bits -= to_bits
            ret.append((acc >> bits) & maxv)
    if pad:
        if bits:
            ret.append((acc << (to_bits - bits)) & maxv)
    elif bits >= from_bits or ((acc << (to_bits - bits)) & maxv):
        raise CheckError("invalid padding in convertbits")
    return ret


def segwit_v0_address(program: bytes, hrp: str = "bcrt") -> str:
    data = [0] + convertbits(program, 8, 5)
    values = bech32_hrp_expand(hrp) + data + [0] * 6
    polymod = bech32_polymod(values) ^ 1
    checksum = [(polymod >> 5 * (5 - index)) & 31 for index in range(6)]
    return hrp + "1" + "".join(BECH32_CHARSET[value] for value in data + checksum)


def p2pkh_address(pubkey: bytes, version: int = 0x6F) -> str:
    return b58check_encode(bytes([version]) + hash160(pubkey))


def p2sh_address(script: bytes, version: int = 0xC4) -> str:
    return b58check_encode(bytes([version]) + hash160(script))


def point_add(a: tuple[int, int] | None, b: tuple[int, int] | None) -> tuple[int, int] | None:
    if a is None:
        return b
    if b is None:
        return a
    ax, ay = a
    bx, by = b
    if ax == bx and (ay + by) % P == 0:
        return None
    if a == b:
        lam = (3 * ax * ax) * pow(2 * ay, P - 2, P) % P
    else:
        lam = (by - ay) * pow(bx - ax, P - 2, P) % P
    x = (lam * lam - ax - bx) % P
    y = (lam * (ax - x) - ay) % P
    return x, y


def point_mul(k: int, point: tuple[int, int] = G) -> tuple[int, int] | None:
    k %= N
    result: tuple[int, int] | None = None
    addend: tuple[int, int] | None = point
    while k:
        if k & 1:
            result = point_add(result, addend)
        addend = point_add(addend, addend)
        k >>= 1
    return result


def lift_x(x: int) -> tuple[int, int] | None:
    if x >= P:
        return None
    y_sq = (pow(x, 3, P) + 7) % P
    y = pow(y_sq, (P + 1) // 4, P)
    if pow(y, 2, P) != y_sq:
        return None
    return x, y if y % 2 == 0 else P - y


def ser_pub(point: tuple[int, int]) -> bytes:
    x, y = point
    return bytes([2 + (y & 1)]) + x.to_bytes(32, "big")


def parse_pub(data: bytes) -> tuple[int, int]:
    if len(data) != 33 or data[0] not in (2, 3):
        raise CheckError(f"not a compressed public key: {data.hex()}")
    point = lift_x(int.from_bytes(data[1:], "big"))
    if point is None:
        raise CheckError(f"public key is not on the curve: {data.hex()}")
    if (point[1] & 1) != (data[0] & 1):
        point = (point[0], P - point[1])
    return point


def secp_add_tweak(point: tuple[int, int], tweak: int) -> tuple[int, int] | None:
    return point_add(point, point_mul(tweak))


# ---------------------------------------------------------------------------
# BIP32
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class ExtKey:
    depth: int
    parent_fingerprint: bytes
    child_number: int
    chain_code: bytes
    key: bytes  # 32-byte private scalar, or 33-byte compressed public key
    private: bool

    def public_key(self) -> bytes:
        if self.private:
            point = point_mul(int.from_bytes(self.key, "big"))
            if point is None:
                raise CheckError("private key maps to infinity")
            return ser_pub(point)
        return self.key

    def serialize(self) -> str:
        version = XPRV_VERSION if self.private else XPUB_VERSION
        key_data = (b"\x00" + self.key) if self.private else self.key
        payload = (
            version
            + bytes([self.depth])
            + self.parent_fingerprint
            + self.child_number.to_bytes(4, "big")
            + self.chain_code
            + key_data
        )
        return b58check_encode(payload)


def parse_ext_key(text: str) -> ExtKey:
    payload = b58check_decode(text)
    if len(payload) != 78:
        raise CheckError(f"extended key is {len(payload)} bytes: {text!r}")
    version = payload[:4]
    if version == XPUB_VERSION:
        private = False
    elif version == XPRV_VERSION:
        private = True
    else:
        raise CheckError(f"unexpected extended-key version {version.hex()}: {text!r}")
    depth = payload[4]
    parent = payload[5:9]
    child = int.from_bytes(payload[9:13], "big")
    chain = payload[13:45]
    data = payload[45:78]
    if depth == 0 and (parent != b"\x00" * 4 or child != 0):
        raise CheckError(f"depth 0 with non-zero parent/index: {text!r}")
    if private:
        if data[0] != 0:
            raise CheckError(f"private key data does not start with 0x00: {text!r}")
        scalar = int.from_bytes(data[1:], "big")
        if not 0 < scalar < N:
            raise CheckError(f"private scalar outside 1..n-1: {text!r}")
        key = data[1:]
    else:
        parse_pub(data)
        key = data
    return ExtKey(depth, parent, child, chain, key, private)


def serialize_ext_key(text: str, version: bytes) -> str:
    payload = b58check_decode(text)
    return b58check_encode(version + payload[4:])


def ckd_priv(parent: ExtKey, index: int) -> ExtKey:
    if not parent.private:
        raise CheckError("CKDpriv on an extended public key")
    if index >= 0x80000000:
        data = b"\x00" + parent.key + index.to_bytes(4, "big")
    else:
        data = parent.public_key() + index.to_bytes(4, "big")
    digest = hmac.new(parent.chain_code, data, hashlib.sha512).digest()
    tweak = int.from_bytes(digest[:32], "big")
    scalar = int.from_bytes(parent.key, "big")
    if tweak >= N:
        raise CheckError("invalid child: I_L >= n")
    child = (tweak + scalar) % N
    if child == 0:
        raise CheckError("invalid child: k_i = 0")
    fingerprint = hash160(parent.public_key())[:4]
    return ExtKey(
        parent.depth + 1,
        fingerprint,
        index,
        digest[32:],
        child.to_bytes(32, "big"),
        True,
    )


def ckd_pub(parent: ExtKey, index: int) -> ExtKey:
    if parent.private:
        raise CheckError("CKDpub on an extended private key")
    if index >= 0x80000000:
        raise CheckError("hardened public derivation")
    data = parent.key + index.to_bytes(4, "big")
    digest = hmac.new(parent.chain_code, data, hashlib.sha512).digest()
    tweak = int.from_bytes(digest[:32], "big")
    if tweak >= N:
        raise CheckError("invalid child: I_L >= n")
    child_point = secp_add_tweak(parse_pub(parent.key), tweak)
    if child_point is None:
        raise CheckError("invalid child: point at infinity")
    fingerprint = hash160(parent.key)[:4]
    return ExtKey(
        parent.depth + 1,
        fingerprint,
        index,
        digest[32:],
        ser_pub(child_point),
        False,
    )


def parse_path(path: str) -> list[int]:
    if path == "m":
        return []
    if not path.startswith("m/"):
        raise CheckError(f"bad BIP32 path: {path!r}")
    out: list[int] = []
    for part in path[2:].split("/"):
        hardened = part.endswith("'") or part.lower().endswith("h")
        digits = part[:-1] if hardened else part
        if not digits.isdigit():
            raise CheckError(f"bad path component {part!r}")
        value = int(digits)
        if value >= 0x80000000:
            raise CheckError(f"path index out of range: {part!r}")
        out.append(value | (0x80000000 if hardened else 0))
    return out


def master_from_seed(seed: bytes) -> ExtKey:
    digest = hmac.new(b"Bitcoin seed", seed, hashlib.sha512).digest()
    scalar = int.from_bytes(digest[:32], "big")
    if not 0 < scalar < N:
        raise CheckError("invalid master key")
    return ExtKey(0, b"\x00" * 4, 0, digest[32:], digest[:32], True)


def derive_private(seed: bytes, path: str) -> ExtKey:
    key = master_from_seed(seed)
    for index in parse_path(path):
        key = ckd_priv(key, index)
    return key


def derive_public(xpub: str, path: str) -> ExtKey:
    key = parse_ext_key(xpub)
    if key.private:
        raise CheckError("expected an extended public key")
    for index in parse_path(path):
        key = ckd_pub(key, index)
    return key


# ---------------------------------------------------------------------------
# Addresses
# ---------------------------------------------------------------------------


def address_for(pubkey: bytes, kind: str) -> str:
    if kind == "wpkh":
        return segwit_v0_address(hash160(pubkey))
    if kind == "pkh":
        return p2pkh_address(pubkey)
    if kind == "sh_wpkh":
        return p2sh_address(b"\x00\x14" + hash160(pubkey))
    raise CheckError(f"unknown address type {kind!r}")


def descriptor_for(xpub: str, kind: str, suffix: str = "") -> str:
    if kind == "wpkh":
        return f"wpkh({xpub}{suffix})"
    if kind == "pkh":
        return f"pkh({xpub}{suffix})"
    if kind == "sh_wpkh":
        return f"sh(wpkh({xpub}{suffix}))"
    raise CheckError(f"unknown descriptor type {kind!r}")


# ---------------------------------------------------------------------------
# Corpus loading and self-check
# ---------------------------------------------------------------------------


def canonical(row: dict[str, Any]) -> str:
    return json.dumps(row, sort_keys=True, separators=(",", ":"))


def load_corpus(path: Path = DEFAULT_CORPUS) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    seen: set[str] = set()
    with path.open(encoding="utf-8") as handle:
        for lineno, line in enumerate(handle, 1):
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as exc:
                raise CheckError(f"{path}:{lineno}: invalid JSON: {exc}") from exc
            if "id" not in row:
                raise CheckError(f"{path}:{lineno}: missing id")
            if row["id"] in seen:
                raise CheckError(f"{path}:{lineno}: duplicate id {row['id']!r}")
            seen.add(row["id"])
            rows.append(row)
    if not rows:
        raise CheckError(f"{path}: empty corpus")
    return rows


def check_invalid_key(text: str) -> str:
    """Return a rejection category for an invalid extended key.

    The categories are deliberately coarse; the corpus reason strings are
    prose from BIP32 and are not parsed.
    """
    try:
        payload = b58check_decode(text)
    except CheckError:
        return "checksum"
    if len(payload) != 78:
        return "length"
    version = payload[:4]
    if version not in (XPUB_VERSION, XPRV_VERSION):
        return "version"
    depth = payload[4]
    if depth == 0 and payload[5:9] != b"\x00" * 4:
        return "depth-fingerprint"
    if depth == 0 and payload[9:13] != b"\x00" * 4:
        return "depth-index"
    data = payload[45:78]
    if version == XPUB_VERSION:
        if data[0] not in (2, 3):
            return "pubkey-prefix"
        try:
            parse_pub(data)
        except CheckError:
            return "pubkey-curve"
    else:
        if data[0] != 0:
            return "prvkey-prefix"
        scalar = int.from_bytes(data[1:], "big")
        if not 0 < scalar < N:
            return "prvkey-range"
    return ""


def check_corpus(rows: list[dict[str, Any]], verbose: bool = True) -> dict[str, Any]:
    valid = [row for row in rows if row.get("valid", True)]
    invalid = [row for row in rows if not row.get("valid", True)]
    if len(valid) != 17:
        raise CheckError(f"expected 17 valid rows, found {len(valid)}")
    if len(invalid) != 16:
        raise CheckError(f"expected 16 invalid rows, found {len(invalid)}")

    for row in valid:
        required = ("id", "seed_hex", "path", "expected_xprv", "expected_xpub", "expected_pubkey_hex", "source")
        missing = [field for field in required if field not in row]
        if missing:
            raise CheckError(f"{row['id']}: missing fields {missing}")
        seed = bytes.fromhex(row["seed_hex"])
        derived = derive_private(seed, row["path"])
        if derived.serialize() != row["expected_xprv"]:
            raise CheckError(f"{row['id']}: xprv does not derive from seed/path")
        if not derived.private:
            raise CheckError(f"{row['id']}: derived key is not private")
        pub = derive_private(seed, row["path"]).public_key()
        if pub.hex() != row["expected_pubkey_hex"]:
            raise CheckError(f"{row['id']}: public key mismatch from seed")
        xpub = parse_ext_key(row["expected_xpub"])
        if xpub.private:
            raise CheckError(f"{row['id']}: expected_xpub is private")
        if xpub.public_key().hex() != pub.hex():
            raise CheckError(f"{row['id']}: xpub does not carry the derived public key")
        if xpub.serialize() != row["expected_xpub"]:
            raise CheckError(f"{row['id']}: xpub round-trip failed")
        # xprv and xpub metadata must agree.
        if (derived.depth, derived.parent_fingerprint, derived.child_number, derived.chain_code) != (
            xpub.depth,
            xpub.parent_fingerprint,
            xpub.child_number,
            xpub.chain_code,
        ):
            raise CheckError(f"{row['id']}: xprv/xpub metadata disagree")
        if row["source"] != "BIP32":
            raise CheckError(f"{row['id']}: unexpected source {row['source']!r}")

    for row in invalid:
        if row.get("valid", True):
            raise CheckError(f"{row['id']}: invalid row marked valid")
        candidate = row["expected_xprv"] or row["expected_xpub"]
        if not candidate:
            raise CheckError(f"{row['id']}: no candidate key")
        category = check_invalid_key(candidate)
        if not category:
            raise CheckError(f"{row['id']}: decoder accepted an invalid key")
        row["_rejection"] = category

    if verbose:
        print(f"corpus: {len(valid)} valid rows recomputed from seed; {len(invalid)} invalid rows rejected")
    return {"valid": len(valid), "invalid": len(invalid)}


# ---------------------------------------------------------------------------
# Core regtest observations
# ---------------------------------------------------------------------------


def core_meta(node: Bitcoind) -> dict[str, Any]:
    version = str(node.rpc("getnetworkinfo")["subversion"]).strip("/")
    if version.startswith("Satoshi:"):
        version = "v" + version[len("Satoshi:") :]
    try:
        banner = subprocess.run(
            [node.binary, "--version"], capture_output=True, text=True, timeout=30, check=False
        ).stdout.splitlines()[0]
        match = re.search(r"\b(v\d+\.\d+\.\d+(?:-[0-9A-Za-z]+)?)\b", banner)
        if match:
            version = match.group(1)
    except (OSError, IndexError, subprocess.SubprocessError):
        pass
    return {
        "bitcoind_version": version,
        "core_commit": CORE_COMMIT,
        "chain": "regtest",
    }


def add_checksum(node: Bitcoind, descriptor: str) -> str:
    info = node.rpc("getdescriptorinfo", descriptor)
    return info["descriptor"]


def import_descriptor(node: Bitcoind, wallet: str, descriptor: str, value_range: list[int] | None = None) -> None:
    item: dict[str, Any] = {"desc": descriptor, "timestamp": "now", "active": False}
    if value_range is not None:
        item["range"] = value_range
    try:
        result = node.rpc("importdescriptors", [item], wallet=wallet)
    except RPCError as exc:
        raise CheckError(f"importdescriptors failed for {descriptor}: {exc}") from exc
    if not result or not result[0].get("success"):
        raise CheckError(f"importdescriptors rejected {descriptor}: {result}")


PUBKEY_RE = re.compile(r"([0-9a-f]{66})")


def observed_pubkey(node: Bitcoind, wallet: str, address: str) -> str:
    info = node.rpc("getaddressinfo", address, wallet=wallet)
    keys = info.get("pubkeys") or []
    if keys:
        return str(keys[0]).lower()
    desc = str(info.get("desc") or "")
    match = PUBKEY_RE.search(desc)
    if not match:
        raise CheckError(f"getaddressinfo returned no public key for {address}: {info}")
    return match.group(1).lower()


def fixed_cases(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    cases = []
    for row in rows:
        if not row.get("valid", True):
            continue
        tpub = serialize_ext_key(row["expected_xpub"], TPUB_VERSION)
        cases.append(
            {
                "id": row["id"],
                "kind": "fixed",
                "seed_hex": row["seed_hex"],
                "path": row["path"],
                "xpub": row["expected_xpub"],
                "regtest_xpub": tpub,
                "pubkey_hex": row["expected_pubkey_hex"],
                "source_row": row["id"],
            }
        )
    return cases


RANGE_ROOTS = [
    # Exercise two non-hardened CKDpub steps from the master xpub.  The
    # suffix 1/2 does not occur in the official vectors, so no fixed
    # descriptor collides with these children.
    ("bip32-1-m", "1/2"),
    ("bip32-2-m", "1/2"),
    ("bip32-3-m", "1/2"),
    ("bip32-4-m", "1/2"),
    # Extend four leaf xpubs by one unhardened step.
    ("bip32-1-0h-1-2h-2-1000000000", "0"),
    ("bip32-2-0-2147483647h-1-2147483646h-2", "0"),
    ("bip32-3-0h", "0"),
    ("bip32-4-0h-1h", "0"),
]


def range_cases(rows: list[dict[str, Any]], count: int = 5) -> list[dict[str, Any]]:
    by_id = {row["id"]: row for row in rows}
    cases: list[dict[str, Any]] = []
    for parent_id, suffix in RANGE_ROOTS:
        row = by_id[parent_id]
        if not row.get("valid", True):
            raise CheckError(f"range root {parent_id} is not valid")
        tpub = serialize_ext_key(row["expected_xpub"], TPUB_VERSION)
        for index in range(count):
            if row["path"] == "m":
                child_path = f"m/{suffix}/{index}"
            else:
                child_path = f"{row['path']}/{suffix}/{index}"
            cases.append(
                {
                    "id": f"bip32-range-{parent_id[6:]}-{suffix.replace('/', '-')}-{index}",
                    "kind": "range",
                    "parent_id": parent_id,
                    "parent_path": row["path"],
                    "path": child_path,
                    "xpub": row["expected_xpub"],
                    "regtest_xpub": tpub,
                    "range_suffix": suffix,
                    "index": index,
                }
            )
    return cases


def run_core(
    rows: list[dict[str, Any]],
    bitcoind_path: str,
    keep: bool = False,
    smoke: bool = False,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    node = Bitcoind(binary=bitcoind_path)
    cases: list[dict[str, Any]] = []
    try:
        node.start()
        meta = core_meta(node)
        wallet = "bip32_diff"
        node.rpc("createwallet", wallet, True, True, "", False, True)

        fixed = fixed_cases(rows)
        ranges = range_cases(rows)
        if smoke:
            fixed = fixed[:3]
            ranges = ranges[:2]

        # Fixed descriptors: three address types per corpus row.
        for case in fixed:
            expected_pub = bytes.fromhex(case["pubkey_hex"])
            addresses: dict[str, str] = {}
            observed: dict[str, str] = {}
            descriptors: dict[str, str] = {}
            for kind in ADDRESS_TYPES:
                descriptor = add_checksum(node, descriptor_for(case["regtest_xpub"], kind))
                result = node.rpc("deriveaddresses", descriptor)
                if len(result) != 1:
                    raise CheckError(f"deriveaddresses returned {len(result)} addresses for {case['id']} {kind}")
                want = address_for(expected_pub, kind)
                if result[0] != want:
                    raise CheckError(
                        f"{case['id']} {kind}: Core address {result[0]} != local {want}"
                    )
                import_descriptor(node, wallet, descriptor)
                seen = observed_pubkey(node, wallet, result[0])
                if seen != case["pubkey_hex"]:
                    raise CheckError(
                        f"{case['id']} {kind}: Core pubkey {seen} != corpus {case['pubkey_hex']}"
                    )
                addresses[kind] = result[0]
                observed[kind] = seen
                descriptors[kind] = descriptor
            record = {
                **meta,
                "id": case["id"],
                "kind": "fixed",
                "seed_hex": case["seed_hex"],
                "path": case["path"],
                "xpub": case["xpub"],
                "regtest_xpub": case["regtest_xpub"],
                "pubkey_hex": observed["wpkh"],
                "addresses": addresses,
                "descriptors": descriptors,
                "rpc": ["getdescriptorinfo", "deriveaddresses", "importdescriptors", "getaddressinfo"],
            }
            cases.append(record)

        # Ranged descriptors: Core CKDpub against local CKDpub.  One
        # import per root covers all five indices, so wallets never see the
        # same range descriptor twice.
        groups: dict[tuple[str, str], list[dict[str, Any]]] = {}
        for case in ranges:
            groups.setdefault((case["parent_id"], case["range_suffix"]), []).append(case)
        for (parent_id, suffix), group in groups.items():
            first = group[0]
            range_descriptor = add_checksum(
                node, descriptor_for(first["regtest_xpub"], "wpkh", f"/{suffix}/*")
            )
            last = max(case["index"] for case in group)
            # Core's deriveaddresses range argument is inclusive.
            result = node.rpc("deriveaddresses", range_descriptor, [0, last])
            if len(result) != last + 1:
                raise CheckError(
                    f"{parent_id}/{suffix}: deriveaddresses returned {len(result)} of {last + 1} addresses"
                )
            import_descriptor(node, wallet, range_descriptor, [0, last])
            parent = parse_ext_key(first["xpub"])
            base = parent
            for step in parse_path("m/" + suffix):
                base = ckd_pub(base, step)
            for case in group:
                child = ckd_pub(base, case["index"])
                want_pub = child.public_key().hex()
                want_address = address_for(bytes.fromhex(want_pub), "wpkh")
                if result[case["index"]] != want_address:
                    raise CheckError(
                        f"{case['id']}: Core address {result[case['index']]} != local {want_address}"
                    )
                seen = observed_pubkey(node, wallet, result[case["index"]])
                if seen != want_pub:
                    raise CheckError(f"{case['id']}: Core pubkey {seen} != local {want_pub}")
                cases.append(
                    {
                        **meta,
                        "id": case["id"],
                        "kind": "range",
                        "parent_id": case["parent_id"],
                        "parent_path": case["parent_path"],
                        "path": case["path"],
                        "xpub": case["xpub"],
                        "regtest_xpub": case["regtest_xpub"],
                        "range_descriptor": range_descriptor,
                        "index": case["index"],
                        "pubkey_hex": seen,
                        "addresses": {"wpkh": result[case["index"]]},
                        "rpc": ["getdescriptorinfo", "deriveaddresses", "importdescriptors", "getaddressinfo"],
                    }
                )

        # Vector 5: every invalid extended key must be rejected by Core's
        # descriptor parser.  Mainnet versions are re-encoded to regtest
        # versions first (same payload); the bad-checksum and unknown-version
        # rows are passed through unchanged.
        for row in rows:
            if row.get("valid", True):
                continue
            original = row["expected_xprv"] or row["expected_xpub"]
            if row["reason"] == "invalid checksum" or original.startswith("DMwo"):
                candidate = original
                encoding = "raw"
            elif original.startswith("xprv"):
                candidate = serialize_ext_key(original, TPRV_VERSION)
                encoding = "tprv"
            elif original.startswith("xpub"):
                candidate = serialize_ext_key(original, TPUB_VERSION)
                encoding = "tpub"
            else:
                raise CheckError(f"{row['id']}: unrecognised invalid key prefix")
            try:
                node.rpc("getdescriptorinfo", f"wpkh({candidate})")
            except RPCError as exc:
                if exc.code != -5:
                    raise CheckError(
                        f"{row['id']}: expected descriptor rejection (-5), got {exc.code}: {exc.message}"
                    ) from exc
                cases.append(
                    {
                        **meta,
                        "id": row["id"],
                        "kind": "invalid",
                        "seed_hex": "",
                        "path": "",
                        "candidate": candidate,
                        "candidate_encoding": encoding,
                        "bip32_reason": row["reason"],
                        "error": exc.as_dict(),
                        "rpc": ["getdescriptorinfo"],
                    }
                )
            else:
                raise CheckError(f"{row['id']}: Core accepted an invalid BIP32 key")
        return cases, meta
    finally:
        node.cleanup(keep=keep)


# ---------------------------------------------------------------------------
# Lean dump
# ---------------------------------------------------------------------------


def write_lean_template(rows: list[dict[str, Any]], path: Path) -> None:
    out: list[str] = []
    for row in rows:
        if not row.get("valid", True):
            continue
        template = {
            "id": row["id"],
            "seed_hex": row["seed_hex"],
            "path": row["path"],
            "expected_xpub": row["expected_xpub"],
            "pubkey_hex": "",
            "addresses": {kind: "" for kind in ADDRESS_TYPES},
        }
        out.append(canonical(template))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(line + "\n" for line in out), encoding="utf-8")
    print(f"wrote Lean BIP32 dump template with {len(out)} rows to {path}")


def compare_lean_dump(rows: list[dict[str, Any]], path: Path, allow_partial: bool = False) -> int:
    valid = {row["id"]: row for row in rows if row.get("valid", True)}
    seen: set[str] = set()
    mismatches = 0
    with path.open(encoding="utf-8") as handle:
        for lineno, line in enumerate(handle, 1):
            line = line.strip()
            if not line:
                continue
            try:
                got = json.loads(line)
            except json.JSONDecodeError as exc:
                raise CheckError(f"{path}:{lineno}: invalid JSON: {exc}") from exc
            cid = got.get("id")
            if cid not in valid:
                mismatches += 1
                print(f"mismatch: {cid}: not a valid corpus id")
                continue
            seen.add(cid)
            row = valid[cid]
            pub = got.get("pubkey_hex")
            if pub and str(pub).lower() != row["expected_pubkey_hex"]:
                mismatches += 1
                print(f"mismatch: {cid}: pubkey {pub} != {row['expected_pubkey_hex']}")
            addresses = got.get("addresses") or {}
            for kind in ADDRESS_TYPES:
                value = addresses.get(kind)
                if not value:
                    continue
                want = address_for(bytes.fromhex(row["expected_pubkey_hex"]), kind)
                if value != want:
                    mismatches += 1
                    print(f"mismatch: {cid}: {kind} {value} != {want}")
    missing = set(valid) - seen
    if missing and not allow_partial:
        mismatches += len(missing)
        print(f"missing: {len(missing)} valid corpus ids, e.g. {sorted(missing)[:3]}")
    elif missing:
        print(f"coverage: {len(seen)}/{len(valid)} valid ids compared (partial allowed)")
    return mismatches


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def write_output(cases: list[dict[str, Any]], path: Path, manifest_path: Path) -> str:
    payload = "".join(canonical(case) + "\n" for case in cases)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(payload, encoding="utf-8")
    digest = hashlib.sha256(payload.encode("utf-8")).hexdigest()
    meta = cases[0]
    manifest = {
        "bitcoind_version": meta["bitcoind_version"],
        "core_commit": meta["core_commit"],
        "chain": meta["chain"],
        "format": "bip32-core-jsonl-v1",
        "generator": "spec/runners/wallet_diff/bip32_check.py --core",
        "row_count": len(cases),
        "fixed_count": sum(1 for case in cases if case["kind"] == "fixed"),
        "range_count": sum(1 for case in cases if case["kind"] == "range"),
        "invalid_count": sum(1 for case in cases if case["kind"] == "invalid"),
        "sha256_cases": digest,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return digest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--corpus", type=Path, default=DEFAULT_CORPUS)
    parser.add_argument("--check-corpus", action="store_true", help="recompute all rows from their seeds")
    parser.add_argument("--core", action="store_true", help="start regtest bitcoind and observe Core")
    parser.add_argument("--bitcoind", default=DEFAULT_BITCOIND)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUTPUT, help="observation JSONL destination")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--lean-dump", type=Path, help="JSONL dump produced by the Lean side")
    parser.add_argument("--write-lean-template", type=Path, help="write the documented Lean input shape")
    parser.add_argument("--allow-partial", action="store_true", help="Lean dump may omit valid ids")
    parser.add_argument("--smoke", action="store_true", help="run only five Core cases")
    parser.add_argument("--keep", action="store_true", help="keep the regtest datadir")
    args = parser.parse_args(argv)

    try:
        rows = load_corpus(args.corpus)
        check_corpus(rows)

        if args.write_lean_template:
            write_lean_template(rows, args.write_lean_template)

        if args.lean_dump:
            mismatches = compare_lean_dump(rows, args.lean_dump, args.allow_partial)
            if mismatches:
                raise CheckError(f"Lean dump {args.lean_dump}: {mismatches} mismatches")
            print(f"Lean dump {args.lean_dump}: all present values agree")

        if args.core:
            cases, meta = run_core(rows, args.bitcoind, keep=args.keep, smoke=args.smoke)
            digest = write_output(cases, args.out, args.manifest)
            print(
                f"core: {len(cases)} rows from {meta['bitcoind_version']} "
                f"({meta['core_commit']}) -> {args.out} (sha256 {digest})"
            )

        if not (args.check_corpus or args.core or args.lean_dump or args.write_lean_template):
            print("nothing to do: pass --check-corpus, --core, --lean-dump or --write-lean-template")
    except (CheckError, RPCError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
