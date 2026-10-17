#!/usr/bin/env python3
"""Extract the BIP32 test vectors into a JSONL corpus.

Sources
-------
* ``spec/vectors/bips/bip-0032.mediawiki`` — the official BIP32 text,
  fetched from the BIPs repository.  Vectors 1-4 are valid derivation
  chains; vector 5 is a list of extended keys that must be rejected.
* ``<core>/src/src/test/bip32_tests.cpp`` — Core @ cce32b168.  Tests 1-4
  contain the same valid chains and TEST5 the same invalid keys, so every
  row records the exact Core line as a cross-reference.

The extractor is deliberately strict: it refuses to emit a corpus when the
BIP32 text and the Core test file disagree, when an xpub does not decode,
or when a valid row's public key is not the one carried by its xpub.

Usage
-----
    python3 bip32_extract.py --emit
    python3 bip32_extract.py --emit --output /tmp/bip32.jsonl
    python3 bip32_extract.py --check
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

SPEC_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SPEC = SPEC_ROOT / "vectors" / "bips" / "bip-0032.mediawiki"
DEFAULT_CORE = Path("build/scratch/core-build/src/src/test/bip32_tests.cpp")
DEFAULT_OUTPUT = SPEC_ROOT / "data" / "wallet" / "bip32.jsonl"
CORE_SOURCE_NAME = "src/test/bip32_tests.cpp"

B58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
XPUB_VERSION = bytes.fromhex("0488b21e")
XPRV_VERSION = bytes.fromhex("0488ade4")


class ExtractError(RuntimeError):
    """Raised when a source does not have the expected shape."""


def sha256d(data: bytes) -> bytes:
    return hashlib.sha256(hashlib.sha256(data).digest()).digest()


def b58decode(text: str) -> bytes:
    number = 0
    for char in text:
        try:
            number = number * 58 + B58_ALPHABET.index(char)
        except ValueError as exc:
            raise ExtractError(f"invalid Base58 character {char!r} in {text!r}") from exc
    body = number.to_bytes((number.bit_length() + 7) // 8, "big")
    return b"\x00" * (len(text) - len(text.lstrip("1"))) + body


def b58check_decode(text: str) -> bytes:
    raw = b58decode(text)
    if len(raw) < 5:
        raise ExtractError(f"Base58Check value too short: {text!r}")
    payload, checksum = raw[:-4], raw[-4:]
    if sha256d(payload)[:4] != checksum:
        raise ExtractError(f"bad Base58Check checksum: {text!r}")
    return payload


def ext_key_fields(text: str) -> dict[str, Any]:
    """Decode an extended key and return the fields the corpus needs."""
    payload = b58check_decode(text)
    if len(payload) != 78:
        raise ExtractError(f"extended key is {len(payload)} bytes, expected 78: {text!r}")
    return {
        "version": payload[:4].hex(),
        "depth": payload[4],
        "parent_fingerprint": payload[5:9].hex(),
        "child_number": int.from_bytes(payload[9:13], "big"),
        "chain_code": payload[13:45].hex(),
        "key_data": payload[45:78],
    }


def slug(path: str) -> str:
    if path == "m":
        return "m"
    if not path.startswith("m/"):
        raise ExtractError(f"bad BIP32 path: {path!r}")
    return path[2:].replace("/", "-").replace("'", "h")


def normalize_path(raw: str) -> str:
    """Turn the mediawiki spelling ``m/0<sub>H</sub>`` into ``m/0'``."""
    return raw.replace("<sub>H</sub>", "'")


def parse_valid_vectors(text: str) -> list[dict[str, Any]]:
    """Parse test vectors 1-4 from the BIP32 mediawiki text."""
    rows: list[dict[str, Any]] = []
    for number in range(1, 5):
        match = re.search(
            rf"===Test vector {number}===(.*?)(?=\n===Test vector |\n==Acknowledgements==)",
            text,
            re.DOTALL,
        )
        if not match:
            raise ExtractError(f"test vector {number} not found in the BIP32 text")
        block = match.group(1)
        seed_match = re.search(r"Seed \(hex\): ([0-9a-fA-F]+)", block)
        if not seed_match:
            raise ExtractError(f"test vector {number} has no seed")
        seed = seed_match.group(1).lower()
        if len(seed) % 2 or len(bytes.fromhex(seed)) < 16:
            raise ExtractError(f"test vector {number} has an invalid seed length")

        chain_matches = list(
            re.finditer(r"^\* Chain (m\S*)$", block, re.MULTILINE)
        )
        if not chain_matches:
            raise ExtractError(f"test vector {number} has no chains")
        for index, chain in enumerate(chain_matches):
            path = normalize_path(chain.group(1))
            end = chain_matches[index + 1].start() if index + 1 < len(chain_matches) else len(block)
            body = block[chain.end() : end]
            pub_match = re.search(r"^\*\* ext pub: (\S+)$", body, re.MULTILINE)
            prv_match = re.search(r"^\*\* ext prv: (\S+)$", body, re.MULTILINE)
            if not pub_match or not prv_match:
                raise ExtractError(f"test vector {number} chain {path} lacks ext pub/prv")
            rows.append(
                {
                    "id": f"bip32-{number}-{slug(path)}",
                    "seed_hex": seed,
                    "path": path,
                    "expected_xprv": prv_match.group(1),
                    "expected_xpub": pub_match.group(1),
                    "source": "BIP32",
                    "valid": True,
                }
            )
    return rows


def parse_invalid_vector(text: str) -> list[dict[str, Any]]:
    """Parse BIP32 test vector 5 (invalid extended keys)."""
    match = re.search(
        r"===Test vector 5===(.*?)(?=\n==Acknowledgements==)",
        text,
        re.DOTALL,
    )
    if not match:
        raise ExtractError("test vector 5 not found in the BIP32 text")
    rows: list[dict[str, Any]] = []
    pattern = re.compile(r"^\* ([1-9A-HJ-NP-Za-km-z]+) \(([^)]+)\)$", re.MULTILINE)
    for index, entry in enumerate(pattern.finditer(match.group(1)), start=1):
        key, reason = entry.group(1), entry.group(2).strip()
        if key.startswith("xprv"):
            xprv, xpub = key, ""
        elif key.startswith("xpub") or key.startswith("DMwo"):
            xprv, xpub = "", key
        else:
            raise ExtractError(f"unrecognised invalid-key prefix in {key!r}")
        rows.append(
            {
                "id": f"bip32-5-{index:02d}",
                "seed_hex": "",
                "path": "",
                "expected_xprv": xprv,
                "expected_xpub": xpub,
                "source": "BIP32",
                "valid": False,
                "reason": reason,
            }
        )
    if len(rows) != 16:
        raise ExtractError(f"expected 16 invalid keys in vector 5, found {len(rows)}")
    return rows


def annotate_core(rows: list[dict[str, Any]], core_text: str) -> None:
    """Attach the exact Core test-file line to every row.

    The two sources must agree on the serialized key strings.  Duplicate
    keys (the two ``DMwo`` entries are distinct) are matched in order.
    """
    core_lines = core_text.splitlines()
    lookup: dict[str, int] = {}
    for lineno, line in enumerate(core_lines, start=1):
        for token in re.findall(r"[1-9A-HJ-NP-Za-km-z]{100,}", line):
            lookup.setdefault(token, lineno)
    missing: list[str] = []
    for row in rows:
        candidate = row["expected_xprv"] or row["expected_xpub"]
        if candidate in lookup:
            row["core_source"] = f"core:{CORE_SOURCE_NAME}:{lookup[candidate]}"
        else:
            missing.append(candidate)
    if missing:
        raise ExtractError(
            "BIP32 keys absent from the Core test file:\n  " + "\n  ".join(missing)
        )

    # Confirm the Core vectors are exactly the BIP32 vectors, not a subset
    # with the same spelling in a different order.
    core_block = core_text[core_text.index("TestVector test1") : core_text.index("const std::vector<std::string> TEST5")]
    core_keys = set(re.findall(r"[1-9A-HJ-NP-Za-km-z]{100,}", core_block))
    bip32_keys = {
        key for row in rows[:17] for key in (row["expected_xprv"], row["expected_xpub"]) if key
    }
    if core_keys != bip32_keys:
        only_core = sorted(core_keys - bip32_keys)
        only_bip32 = sorted(bip32_keys - core_keys)
        raise ExtractError(
            "Core tests 1-4 and BIP32 vectors 1-4 differ: "
            f"only-core={only_core} only-bip32={only_bip32}"
        )

    core_test5 = core_text[core_text.index("TEST5") : core_text.index("void RunTest")]
    core_invalid = re.findall(r"[1-9A-HJ-NP-Za-km-z]{100,}", core_test5)
    bip32_invalid = [
        row["expected_xprv"] or row["expected_xpub"]
        for row in rows
        if not row["valid"]
    ]
    if core_invalid != bip32_invalid:
        raise ExtractError("Core TEST5 and BIP32 test vector 5 differ")


def add_pubkeys(rows: list[dict[str, Any]]) -> None:
    seen_xpub: dict[str, str] = {}
    for row in rows:
        if not row["valid"]:
            row["expected_pubkey_hex"] = ""
            continue
        fields = ext_key_fields(row["expected_xpub"])
        if fields["version"] != XPUB_VERSION.hex():
            raise ExtractError(f"{row['id']}: xpub has version {fields['version']}")
        prv_fields = ext_key_fields(row["expected_xprv"])
        if prv_fields["version"] != XPRV_VERSION.hex():
            raise ExtractError(f"{row['id']}: xprv has version {prv_fields['version']}")
        for field in ("depth", "parent_fingerprint", "child_number", "chain_code"):
            if fields[field] != prv_fields[field]:
                raise ExtractError(f"{row['id']}: xprv/xpub disagree on {field}")
        key_data = fields["key_data"]
        if len(key_data) != 33 or key_data[0] not in (2, 3):
            raise ExtractError(f"{row['id']}: xpub does not hold a compressed key")
        pubkey = key_data.hex()
        row["expected_pubkey_hex"] = pubkey
        seen_xpub.setdefault(row["expected_xpub"], pubkey)
        if seen_xpub[row["expected_xpub"]] != pubkey:
            raise ExtractError(f"{row['id']}: one xpub maps to two public keys")


def load_core_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ExtractError(f"cannot read Core test file {path}: {exc}") from exc


def build_rows(spec_path: Path, core_path: Path) -> list[dict[str, Any]]:
    text = spec_path.read_text(encoding="utf-8")
    rows = parse_valid_vectors(text) + parse_invalid_vector(text)
    annotate_core(rows, load_core_text(core_path))
    add_pubkeys(rows)
    for row in rows:
        if row["valid"]:
            row.pop("reason", None)
    return rows


def canonical(row: dict[str, Any]) -> str:
    return json.dumps(row, sort_keys=True, separators=(",", ":"))


def write_corpus(path: Path, rows: list[dict[str, Any]]) -> str:
    payload = "".join(canonical(row) + "\n" for row in rows)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(payload, encoding="utf-8")
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def check_corpus(path: Path, expected: list[dict[str, Any]]) -> None:
    actual = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]
    if actual != expected:
        raise ExtractError(f"{path} is not the corpus this extractor produces")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, default=DEFAULT_SPEC)
    parser.add_argument("--core", type=Path, default=DEFAULT_CORE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--emit", action="store_true", help="rewrite the JSONL corpus")
    parser.add_argument("--check", action="store_true", help="verify the corpus is current")
    args = parser.parse_args(argv)
    if not args.emit and not args.check:
        parser.error("choose --emit or --check")
    try:
        rows = build_rows(args.spec, args.core)
        if args.emit:
            digest = write_corpus(args.output, rows)
            print(f"wrote {len(rows)} rows to {args.output} (sha256 {digest})")
        if args.check:
            check_corpus(args.output, rows)
            print(f"{args.output}: {len(rows)} rows match the sources")
    except ExtractError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
