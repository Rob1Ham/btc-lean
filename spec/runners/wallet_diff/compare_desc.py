#!/usr/bin/env python3
"""Differential comparison of the Lean descriptor expander with Core's corpus.

The corpus (`spec/data/wallet/cases.jsonl`) records Bitcoin Core's answers
for `deriveaddresses`, `getdescriptorinfo` and wallet import/list calls.  The
Lean side is `DescDump`, which expands a descriptor to scriptPubKey hex under
the policies documented in `DescDump.lean`.

This script:

1. selects every corpus case that carries a descriptor input (including the
   descriptor echoed back by `getaddressinfo`/`validateaddress` results);
2. classifies which descriptor constructs the committed expander claims to
   model, and why the others are skipped;
3. decodes the addresses Core returned into scriptPubKeys, using only the
   address rules anchored in Core (`src/key_io.cpp`, `src/addresstype.cpp`);
4. joins the two sides and compares bytes, or compares the error family;
5. prints a summary, a mismatch table, and the skipped-case reasons.

The address decoder is itself checked against every address/scriptPubKey pair
present in the corpus before it is used for the join.  That makes the join
auditable: a decoder bug shows up as a self-check failure, not as a fake
descriptor agreement.

Usage (from the repository root):

    python3 spec/runners/wallet_diff/compare_desc.py

    # after rebuilding the runner:
    cd spec/runners/wallet_diff && lake build descDump

`--json PATH` writes the full machine-readable report alongside the summary.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[3]
DEFAULT_CASES = REPO / "spec" / "data" / "wallet" / "cases.jsonl"
DEFAULT_DUMP = (
    REPO / "spec" / "runners" / "wallet_diff" / ".lake" / "build" / "bin" / "descDump"
)

# ---------------------------------------------------------------------------
# Address -> scriptPubKey (the join oracle)
# ---------------------------------------------------------------------------

BECH32 = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
B58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


def _bech32_polymod(values: list[int]) -> int:
    gen = [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3]
    chk = 1
    for value in values:
        top = chk >> 25
        chk = ((chk & 0x1FFFFFF) << 5) ^ value
        for i in range(5):
            if (top >> i) & 1:
                chk ^= gen[i]
    return chk


def _hrp_expand(hrp: str) -> list[int]:
    return [ord(c) >> 5 for c in hrp] + [0] + [ord(c) & 31 for c in hrp]


def _convertbits(data: list[int], frombits: int, tobits: int, pad: bool) -> list[int]:
    acc = 0
    bits = 0
    ret: list[int] = []
    maxv = (1 << tobits) - 1
    for value in data:
        if value < 0 or value >> frombits:
            raise ValueError("invalid data range")
        acc = (acc << frombits) | value
        bits += frombits
        while bits >= tobits:
            bits -= tobits
            ret.append((acc >> bits) & maxv)
    if pad:
        if bits:
            ret.append((acc << (tobits - bits)) & maxv)
    elif bits >= frombits or ((acc << (tobits - bits)) & maxv):
        raise ValueError("invalid padding")
    return ret


def _bech32_decode(addr: str) -> tuple[str, list[int], int]:
    if addr.lower() != addr and addr.upper() != addr:
        raise ValueError("mixed case")
    addr = addr.lower()
    pos = addr.rfind("1")
    if pos < 1 or pos + 7 > len(addr):
        raise ValueError("bad separator")
    hrp = addr[:pos]
    data = [BECH32.index(c) for c in addr[pos + 1 :]]
    const = _bech32_polymod(_hrp_expand(hrp) + data)
    if const not in (1, 0x2BC830A3):
        raise ValueError("bad checksum")
    return hrp, data, const


def _base58check_decode(text: str) -> bytes:
    value = 0
    for char in text:
        value = value * 58 + B58.index(char)
    body = value.to_bytes((value.bit_length() + 7) // 8, "big")
    zeros = len(text) - len(text.lstrip("1"))
    raw = b"\x00" * zeros + body
    if len(raw) < 4:
        raise ValueError("too short")
    payload, checksum = raw[:-4], raw[-4:]
    import hashlib

    expected = hashlib.sha256(hashlib.sha256(payload).digest()).digest()[:4]
    if checksum != expected:
        raise ValueError("bad base58 checksum")
    return payload


def address_to_script(addr: str) -> str:
    """Decode a Bitcoin address to scriptPubKey hex.

    Anchors: `DecodeDestination` (`src/key_io.cpp:382-410`) and
    `GetScriptForDestination` (`src/addresstype.cpp:116-142`).  Bech32 v0
    uses the bech32 constant, v1+ uses bech32m (BIP350); the witness program
    becomes `OP_n <program>`.
    """
    try:
        hrp, data, const = _bech32_decode(addr)
    except (ValueError, KeyError):
        payload = _base58check_decode(addr)
        version, h160 = payload[0], payload[1:]
        if len(h160) != 20:
            raise ValueError("base58 payload is not a 20-byte hash")
        if version in (0x6F, 0x00):  # testnet/mainnet P2PKH
            return "76a914" + h160.hex() + "88ac"
        if version in (0xC4, 0x05):  # testnet/mainnet P2SH
            return "a914" + h160.hex() + "87"
        raise ValueError(f"unsupported base58 version {version:#x}")

    if not data:
        raise ValueError("empty bech32 data")
    version = data[0]
    program = bytes(_convertbits(data[1:-6], 5, 8, False))
    if version == 0:
        if len(program) not in (20, 32):
            raise ValueError("invalid v0 program length")
        if const != 1:
            raise ValueError("v0 address is not bech32")
        opcode = 0x00
    else:
        if const != 0x2BC830A3:
            raise ValueError("v1+ address is not bech32m")
        opcode = 0x50 + version
    if not 2 <= len(program) <= 40:
        raise ValueError("invalid witness program length")
    return bytes([opcode, len(program)]).hex() + program.hex()


def decoder_self_check(cases: list[dict[str, Any]]) -> tuple[int, list[str]]:
    """Check the address decoder against every address/script pair in the corpus."""
    pairs: set[tuple[str, str]] = set()
    for case in cases:
        expect = case.get("expect")
        if not isinstance(expect, dict):
            continue
        result = expect.get("result")
        if isinstance(result, dict):
            if "address" in result and "scriptPubKey" in result:
                pairs.add((result["address"], result["scriptPubKey"]))
            embedded = result.get("embedded")
            if isinstance(embedded, dict):
                if "address" in embedded and "scriptPubKey" in embedded:
                    pairs.add((embedded["address"], embedded["scriptPubKey"]))
            segwit = result.get("segwit")
            if isinstance(segwit, dict):
                if "address" in segwit and "hex" in segwit:
                    pairs.add((segwit["address"], segwit["hex"]))
        if case.get("method") == "decodescript" and isinstance(result, dict):
            if "address" in result and isinstance(case.get("params"), list):
                pairs.add((result["address"], case["params"][0]))
    failures = []
    for address, script in sorted(pairs):
        try:
            got = address_to_script(address)
        except Exception as exc:  # noqa: BLE001 - report any decoder failure
            failures.append(f"{address}: {exc}")
            continue
        if got != script:
            failures.append(f"{address}: expected {script}, decoded {got}")
    return len(pairs), failures


# ---------------------------------------------------------------------------
# Error classes
# ---------------------------------------------------------------------------

CHECKSUM_CLASSES = {
    "checksum-multiple",
    "checksum-missing",
    "checksum-length",
    "checksum-mismatch",
}

CLASS_FAMILY = {
    **{name: name for name in CHECKSUM_CLASSES},
    "invalid-character": "syntax",
    "invalid-function": "syntax",
    "syntax": "syntax",
    "context": "syntax",
    "key-missing": "key",
    "invalid-key": "key",
    "uncompressed-witness": "key",
    "key-path": "key",
    "threshold": "multisig",
    "hardened-from-public": "derivation",
    "rpc-range": "rpc-range",
    "no-address": "no-address",
    "raw-not-hex": "unsupported",
    "unsupported": "unsupported",
    "other": "other",
}


def core_error_class(message: str) -> str:
    text = message.lower()
    if "multiple '#'" in text:
        return "checksum-multiple"
    if text == "missing checksum" or text.endswith("missing checksum"):
        return "checksum-missing"
    if text.startswith("expected 8 character checksum"):
        return "checksum-length"
    if text.startswith("provided checksum") and "does not match" in text:
        return "checksum-mismatch"
    if "invalid characters in payload" in text:
        return "invalid-character"
    if "is not a valid descriptor function" in text:
        return "invalid-function"
    if "no key provided" in text:
        return "key-missing"
    if "uncompressed keys are not allowed" in text:
        return "uncompressed-witness"
    if "a function is needed within p2sh" in text:
        return "context"
    if "cannot derive script without private keys" in text:
        return "hardened-from-public"
    if text.startswith("range should not be specified") or text.startswith(
        "range must be specified"
    ):
        return "rpc-range"
    if "begin after end" in text:
        return "rpc-range"
    if "does not have a corresponding address" in text:
        return "no-address"
    if "raw script is not hex" in text:
        return "raw-not-hex"
    if "key '" in text and "is not valid" in text:
        return "invalid-key"
    return "other"


def lean_error_class(message: str) -> str:
    text = message.lower()
    if "multiple '#'" in text:
        return "checksum-multiple"
    if "missing checksum" in text:
        return "checksum-missing"
    if text.startswith("expected 8 character checksum"):
        return "checksum-length"
    if "does not match computed checksum" in text:
        return "checksum-mismatch"
    if "invalid characters in payload" in text:
        return "invalid-character"
    if "hardenedfrompublic" in text or "public derivation failed" in text:
        return "hardened-from-public"
    if "supported descriptor function" in text or "valid descriptor function" in text:
        return "invalid-function"
    if "no key provided" in text:
        return "key-missing"
    if "uncompressed" in text:
        return "uncompressed-witness"
    if "key path" in text:
        return "key-path"
    if "multisig error" in text:
        return "threshold"
    if "context error" in text:
        return "context"
    if "closing sh(wpkh" in text:
        return "context"
    if text.startswith("expected") or "expected" in text:
        return "syntax"
    if text.startswith("invalid key"):
        return "invalid-key"
    return "other"


def same_error_family(expected: str, actual: str) -> bool:
    return CLASS_FAMILY.get(expected, expected) == CLASS_FAMILY.get(actual, actual)


# ---------------------------------------------------------------------------
# Modelled fragment
# ---------------------------------------------------------------------------


def strip_checksum(descriptor: str) -> str:
    return descriptor.split("#", 1)[0]


def _top_level_comma(text: str, depth: int = 0) -> bool:
    depth = depth
    for char in text:
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char == "," and depth == 1:
            return True
    return False


def descriptor_support(descriptor: str) -> tuple[bool, str]:
    """Return whether the committed fragment claims to model this descriptor.

    The fragment is: `pk`, `pkh`, `wpkh`, `sh(wpkh)`, bare `multi` /
    `sortedmulti`, and key-path-only `tr`.  Keys may be literal public keys or
    xpub/tpub with an origin, a non-multipath path and one wildcard.
    Anything outside that is reported rather than silently expanded.
    """
    payload = strip_checksum(descriptor)
    if "xprv" in payload or "tprv" in payload:
        return False, "private extended key (xprv/tprv) not modelled"
    if re.search(r"<[^>]*;", payload):
        return False, "multipath <a;b> key specifier not modelled"
    match = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\(", payload)
    if not match:
        return True, ""
    function = match.group(1)
    if function in {"wsh", "raw", "addr", "combo"}:
        return False, f"{function}() not modelled"
    if function == "sh":
        inner = payload[3:]
        if not inner.startswith("wpkh("):
            return False, "sh() other than sh(wpkh()) not modelled"
    if function == "tr":
        inner = payload[3:]
        if _top_level_comma(inner, 1):
            return False, "taproot script tree tr(key,tree) not modelled"
    return True, ""


def descriptor_function(descriptor: str) -> str:
    match = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\(", strip_checksum(descriptor))
    return match.group(1) if match else "?"
def commitment_spec(descriptor: str) -> tuple[str, str] | None:
    """Return (wrapper, inner_descriptor) for wsh(multi(...)) / sh(multi(...)).

    The outer `wsh`/`sh` wrapper is outside the committed fragment, but Core's
    address commits to the inner bare-multisig script via SHA256 (wsh) or
    HASH160 (sh).  Comparing that commitment exercises the modelled `multi`
    construction without claiming the wrapper itself is modelled.
    """
    payload = strip_checksum(descriptor)
    match = re.match(r"^(wsh|sh)\((multi|sortedmulti)\(", payload)
    if not match:
        return None
    wrapper = match.group(1)
    inner = payload[len(wrapper) + 1 : -1]
    return wrapper, inner




def anchor_for(descriptor: str, expected_error: str | None = None) -> str:
    if expected_error == "checksum-missing":
        return "src/script/descriptor.cpp:2979-2982; src/rpc/output_script.cpp:325"
    if expected_error == "checksum-length":
        return "src/script/descriptor.cpp:2983-2987"
    if expected_error == "checksum-mismatch":
        return "src/script/descriptor.cpp:2993-2998"
    if expected_error == "hardened-from-public":
        return "src/rpc/output_script.cpp:241; src/key.cpp:361-367"
    function = descriptor_function(descriptor)
    if function in {"pk", "pkh", "wpkh"}:
        return "src/addresstype.cpp:116-134; src/script/solver.cpp:213-216"
    if function == "sh":
        return "src/addresstype.cpp:126-130; src/script/descriptor.cpp:1069-1071"
    if function in {"multi", "sortedmulti"}:
        return "src/script/solver.cpp:218-227; src/script/descriptor.cpp:1373-1378"
    if function == "tr":
        return "src/script/signingprovider.cpp:462-470; src/addresstype.cpp:141-144"
    return "src/script/descriptor.cpp:1069-1071"


# ---------------------------------------------------------------------------
# Case extraction
# ---------------------------------------------------------------------------


def _nested_import_error(expect: dict[str, Any]) -> str | None:
    result = expect.get("result")
    if isinstance(result, list):
        for item in result:
            if isinstance(item, dict) and isinstance(item.get("error"), dict):
                return item["error"].get("message")
    return None


def _nested_import_success(expect: dict[str, Any]) -> bool:
    result = expect.get("result")
    if isinstance(result, list) and result:
        return all(
            isinstance(item, dict) and item.get("success") is True for item in result
        )
    return False


def build_checks(cases: list[dict[str, Any]]) -> list[dict[str, Any]]:
    checks: list[dict[str, Any]] = []
    for case in cases:
        method = case.get("method")
        expect = case.get("expect", {})
        case_id = case["id"]

        if method == "deriveaddresses":
            descriptor = case["params"][0]
            commitment = commitment_spec(descriptor)
            checks.append(
                {
                    "id": case_id,
                    "input": descriptor,
                    "mode": "required",
                    "source": "deriveaddresses",
                    "expect": expect,
                    "commitment": commitment,
                    "anchor": anchor_for(
                        descriptor,
                        core_error_class(expect["error"]["message"])
                        if isinstance(expect.get("error"), dict)
                        else None,
                    ),
                }
            )
        elif method == "getdescriptorinfo":
            descriptor = case["params"][0]
            checks.append(
                {
                    "id": case_id,
                    "input": descriptor,
                    "mode": "optional",
                    "source": "getdescriptorinfo",
                    "expect": expect,
                    "anchor": anchor_for(
                        descriptor,
                        core_error_class(expect["error"]["message"])
                        if isinstance(expect.get("error"), dict)
                        else None,
                    ),
                }
            )
        elif method == "importdescriptors":
            batch = case.get("params", [[]])[0]
            if isinstance(batch, list):
                for index, item in enumerate(batch):
                    if isinstance(item, dict) and "desc" in item:
                        suffix = f"#{index}" if len(batch) > 1 else ""
                        checks.append(
                            {
                                "id": case_id + suffix,
                                "input": item["desc"],
                                "mode": "required",
                                "source": "importdescriptors",
                                "expect": expect,
                                "anchor": "src/wallet/rpc/backup.cpp:175; :193-197",
                            }
                        )

        # Descriptors echoed back by address RPC results are direct
        # scriptPubKey observations: no address decoding is involved.
        if case.get("kind") == "rpc":
            result = expect.get("result") if isinstance(expect, dict) else None
            if isinstance(result, dict):
                if (
                    isinstance(result.get("desc"), str)
                    and isinstance(result.get("scriptPubKey"), str)
                ):
                    checks.append(
                        {
                            "id": case_id + ".desc_join",
                            "input": result["desc"],
                            "mode": "required",
                            "source": "getaddressinfo",
                            "expect": {"scriptPubKey": result["scriptPubKey"]},
                            "prefix": True,
                            "anchor": "src/wallet/rpc/addresses.cpp:426; src/addresstype.cpp:116-142",
                        }
                    )
                if (
                    isinstance(result.get("parent_desc"), str)
                    and isinstance(result.get("scriptPubKey"), str)
                ):
                    checks.append(
                        {
                            "id": case_id + ".parent_desc_join",
                            "input": result["parent_desc"],
                            "mode": "required",
                            "source": "getaddressinfo parent_desc",
                            "expect": {"scriptPubKey": result["scriptPubKey"]},
                            "prefix": True,
                            "anchor": "src/wallet/rpc/addresses.cpp:426; src/wallet/scriptpubkeyman.cpp:1131-1178",
                        }
                    )
    return checks


# ---------------------------------------------------------------------------
# Compare
# ---------------------------------------------------------------------------


def run_dump(dump: Path, inputs: list[str], optional: bool) -> dict[str, dict[str, Any]]:
    unique = sorted(set(inputs))
    if not unique:
        return {}
    env = os.environ.copy()
    env["DESC_CHECKSUM"] = "optional" if optional else "required"
    proc = subprocess.run(
        [str(dump)],
        input="\n".join(unique) + "\n",
        text=True,
        capture_output=True,
        env=env,
        check=False,
    )
    if proc.returncode != 0:
        raise SystemExit(
            f"DescDump failed with status {proc.returncode}\n{proc.stderr}"
        )
    result: dict[str, dict[str, Any]] = {}
    for line in proc.stdout.splitlines():
        if not line.strip():
            continue
        obj = json.loads(line)
        result[obj["input"]] = obj
    return result


def classify_check(check: dict[str, Any]) -> tuple[str, str]:
    """Return (disposition, reason) where disposition is compare/skip."""
    descriptor = check["input"]
    commitment = check.get("commitment")
    if commitment is not None:
        wrapper, inner = commitment
        if wrapper not in {"wsh", "sh"}:
            return "skip", f"{wrapper} commitment not modelled"
        supported, reason = descriptor_support(inner)
        if not supported:
            return "skip", reason
        return "compare-commitment", ""
    supported, reason = descriptor_support(descriptor)
    if not supported:
        return "skip", reason

    expect = check["expect"]
    if "scriptPubKey" in expect:
        return "compare-script", ""
    if isinstance(expect.get("error"), dict):
        core_class = core_error_class(expect["error"].get("message", ""))
        if core_class == "rpc-range":
            return "skip", "deriveaddresses range-argument policy, not descriptor expansion"
        if core_class == "no-address":
            return "skip", "deriveaddresses addressability (pk has no address), not expansion"
        if core_class == "raw-not-hex":
            return "skip", "raw() not modelled"
        return "compare-error", ""
    if check["source"] == "deriveaddresses":
        result = expect.get("result")
        if isinstance(result, list):
            return "compare-script", ""
        return "skip", "deriveaddresses result is not a flat address list"
    if check["source"] == "importdescriptors":
        message = _nested_import_error(expect)
        if message is not None:
            core_class = core_error_class(message)
            if core_class == "checksum-missing":
                return "compare-error", ""
            return "skip", "wallet-level import error, not descriptor parse/expansion"
        if _nested_import_success(expect):
            return "compare-parse", ""
        return "skip", "wallet-level import result, no script or parse expectation"
    if check["source"] == "getdescriptorinfo":
        return "compare-parse", ""
    return "skip", "no script or error expectation"


def expected_scripts(check: dict[str, Any]) -> list[str] | None:
    expect = check["expect"]
    if "scriptPubKey" in expect:
        return [expect["scriptPubKey"]]
    result = expect.get("result")
    if check["source"] != "deriveaddresses" or not isinstance(result, list):
        return None
    addresses: list[str] = []
    for item in result:
        if isinstance(item, str):
            addresses.append(item)
        elif isinstance(item, list):
            # Multipath results are nested; unsupported and skipped earlier.
            return None
        else:
            return None
    return [address_to_script(address) for address in addresses]


def compare_checks(
    checks: list[dict[str, Any]], dump: Path
) -> dict[str, Any]:
    classified: list[tuple[dict[str, Any], str, str]] = []
    for check in checks:
        disposition, reason = classify_check(check)
        classified.append((check, disposition, reason))

    required = [
        c["input"]
        for c, disposition, _ in classified
        if disposition.startswith("compare") and c["mode"] == "required"
    ]
    optional = [
        c["input"]
        for c, disposition, _ in classified
        if disposition.startswith("compare") and c["mode"] == "optional"
    ]
    optional += [
        c["commitment"][1]
        for c, disposition, _ in classified
        if disposition == "compare-commitment"
    ]
    lean_required = run_dump(dump, required, optional=False)
    lean_optional = run_dump(dump, optional, optional=True)

    rows: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    mismatches: list[dict[str, Any]] = []
    class_notes: list[dict[str, Any]] = []
    counts = {
        "compare-script": 0,
        "compare-error": 0,
        "compare-parse": 0,
        "compare-commitment": 0,
        "skip": 0,
    }

    for check, disposition, reason in classified:
        counts[disposition] += 1
        if disposition == "skip":
            skipped.append(
                {
                    "id": check["id"],
                    "input": check["input"],
                    "source": check["source"],
                    "reason": reason,
                }
            )
            continue

        lean_map = lean_optional if check["mode"] == "optional" else lean_required
        lean = lean_map.get(check["input"])
        if lean is None:
            mismatches.append(
                {
                    "id": check["id"],
                    "mode": disposition,
                    "input": check["input"],
                    "expected": "a DescDump line",
                    "actual": "missing",
                    "anchor": check["anchor"],
                }
            )
            continue

        if disposition == "compare-script":
            scripts = expected_scripts(check)
            if scripts is None:
                skipped.append(
                    {
                        "id": check["id"],
                        "input": check["input"],
                        "source": check["source"],
                        "reason": "result is not a flat address list",
                    }
                )
                counts[disposition] -= 1
                counts["skip"] += 1
                continue
            if not lean.get("ok"):
                mismatches.append(
                    {
                        "id": check["id"],
                        "mode": disposition,
                        "input": check["input"],
                        "expected": f"scripts {scripts}",
                        "actual": f"error: {lean.get('error')}",
                        "anchor": check["anchor"],
                    }
                )
                continue
            actual = lean.get("scripts", [])
            comparable = actual[: len(scripts)] if check.get("prefix") else actual
            if comparable != scripts:
                mismatches.append(
                    {
                        "id": check["id"],
                        "mode": disposition,
                        "input": check["input"],
                        "expected": scripts,
                        "actual": actual,
                        "anchor": check["anchor"],
                    }
                )
                continue
            rows.append(
                {
                    "id": check["id"],
                    "mode": disposition,
                    "input": check["input"],
                    "expected": scripts,
                    "actual": comparable,
                    "anchor": check["anchor"],
                }
            )
        elif disposition == "compare-error":
            expect = check["expect"]
            if isinstance(expect.get("error"), dict):
                expected_message = expect["error"].get("message", "")
            else:
                expected_message = _nested_import_error(expect) or ""
            expected_class = core_error_class(expected_message)
            if lean.get("ok"):
                mismatches.append(
                    {
                        "id": check["id"],
                        "mode": disposition,
                        "input": check["input"],
                        "expected": f"error class {expected_class}: {expected_message}",
                        "actual": f"expanded to {lean.get('scripts')}",
                        "anchor": check["anchor"],
                    }
                )
                continue
            actual_message = lean.get("error") or ""
            actual_class = lean_error_class(actual_message)
            if not same_error_family(expected_class, actual_class):
                mismatches.append(
                    {
                        "id": check["id"],
                        "mode": disposition,
                        "input": check["input"],
                        "expected": f"error class {expected_class}: {expected_message}",
                        "actual": f"error class {actual_class}: {actual_message}",
                        "anchor": check["anchor"],
                    }
                )
                continue
            if expected_class != actual_class:
                class_notes.append(
                    {
                        "id": check["id"],
                        "expected_class": expected_class,
                        "actual_class": actual_class,
                        "expected_message": expected_message,
                        "actual_message": actual_message,
                        "anchor": check["anchor"],
                    }
                )
            rows.append(
                {
                    "id": check["id"],
                    "mode": disposition,
                    "input": check["input"],
                    "expected": expected_class,
                    "actual": actual_class,
                    "anchor": check["anchor"],
                }
            )
        elif disposition == "compare-commitment":
            wrapper, inner = check["commitment"]
            lean = lean_optional.get(inner)
            if lean is None or not lean.get("ok"):
                mismatches.append(
                    {
                        "id": check["id"],
                        "mode": disposition,
                        "input": check["input"],
                        "expected": f"{wrapper} commitment from Core address",
                        "actual": "inner expansion failed: "
                        + str(None if lean is None else lean.get("error")),
                        "anchor": check["anchor"],
                    }
                )
                continue
            scripts = lean.get("scripts", [])
            result = check["expect"].get("result")
            if not scripts or not isinstance(result, list) or not result:
                mismatches.append(
                    {
                        "id": check["id"],
                        "mode": disposition,
                        "input": check["input"],
                        "expected": "one inner script and one Core address",
                        "actual": f"scripts={scripts}, result={result}",
                        "anchor": check["anchor"],
                    }
                )
                continue
            script_bytes = bytes.fromhex(scripts[0])
            expected_script = address_to_script(result[0])
            if wrapper == "wsh":
                import hashlib

                expected = expected_script[4:]  # OP_0 PUSH32 <program>
                actual = hashlib.sha256(script_bytes).hexdigest()
            else:
                import hashlib

                expected = expected_script[4:44]  # OP_HASH160 <20> OP_EQUAL
                actual = hashlib.new(
                    "ripemd160", hashlib.sha256(script_bytes).digest()
                ).hexdigest()
            if actual != expected:
                mismatches.append(
                    {
                        "id": check["id"],
                        "mode": disposition,
                        "input": check["input"],
                        "expected": f"{wrapper} commitment {expected}",
                        "actual": f"{wrapper} commitment {actual} "
                        f"(inner {inner} -> {scripts[0]})",
                        "anchor": check["anchor"],
                    }
                )
                continue
            rows.append(
                {
                    "id": check["id"],
                    "mode": disposition,
                    "input": check["input"],
                    "expected": f"{wrapper} commitment {expected}",
                    "actual": f"{wrapper} commitment {actual}",
                    "anchor": check["anchor"],
                }
            )
        elif disposition == "compare-parse":
            if not lean.get("ok"):
                mismatches.append(
                    {
                        "id": check["id"],
                        "mode": disposition,
                        "input": check["input"],
                        "expected": "parse/expand success",
                        "actual": f"error: {lean.get('error')}",
                        "anchor": check["anchor"],
                    }
                )
                continue
            rows.append(
                {
                    "id": check["id"],
                    "mode": disposition,
                    "input": check["input"],
                    "expected": "parse/expand success",
                    "actual": "parse/expand success",
                    "anchor": check["anchor"],
                }
            )

    compared = (
        counts["compare-script"]
        + counts["compare-error"]
        + counts["compare-parse"]
        + counts["compare-commitment"]
    )
    agreed = compared - len(mismatches)
    return {
        "counts": counts,
        "compared": compared,
        "agreed": agreed,
        "agreement_rate": (agreed / compared) if compared else 0.0,
        "rows": rows,
        "mismatches": mismatches,
        "class_notes": class_notes,
        "skipped": skipped,
    }


def markdown_summary(report: dict[str, Any]) -> str:
    counts = report["counts"]
    lines = [
        "## Summary",
        "",
        f"- Corpus cases: {report['corpus_cases']}",
        f"- Descriptor-bearing inputs: {report['descriptor_bearing']}",
        f"- Compared: {report['compared']} "
        f"({counts['compare-script']} script, {counts['compare-error']} error, "
        f"{counts['compare-commitment']} wrapped-script commitment, "
        f"{counts['compare-parse']} parse-only)",
        f"- Agreed: {report['agreed']}/{report['compared']} "
        f"({report['agreement_rate'] * 100:.1f}%)",
        f"- Skipped: {counts['skip']}",
        f"- Address-decoder self-check: {report['decoder_pairs']} pairs, "
        f"{len(report['decoder_failures'])} failures",
        "",
        "## Mismatches",
        "",
    ]
    if not report["mismatches"]:
        lines.append("None.")
    else:
        lines.append("| Case | Mode | Expected | Actual | Core anchor |")
        lines.append("|---|---|---|---|---|")
        for row in report["mismatches"]:
            lines.append(
                f"| `{row['id']}` | {row['mode']} | `{row['expected']}` | "
                f"`{row['actual']}` | `{row['anchor']}` |"
            )
    lines.extend(["", "## Class-detail notes", ""])
    if not report["class_notes"]:
        lines.append("None: every error class matched exactly within its family.")
    else:
        lines.append("| Case | Core class | Lean class | Core message | Lean message |")
        lines.append("|---|---|---|---|---|")
        for row in report["class_notes"]:
            lines.append(
                f"| `{row['id']}` | `{row['expected_class']}` | "
                f"`{row['actual_class']}` | {row['expected_message']!r} | "
                f"{row['actual_message']!r} |"
            )
    lines.extend(["", "## Skipped cases and why", ""])
    by_reason: dict[str, list[str]] = {}
    for row in report["skipped"]:
        by_reason.setdefault(row["reason"], []).append(row["id"])
    for reason in sorted(by_reason):
        ids = by_reason[reason]
        lines.append(f"- **{reason}** ({len(ids)}): " + ", ".join(f"`{i}`" for i in ids))
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cases", type=Path, default=DEFAULT_CASES)
    parser.add_argument("--desc-dump", type=Path, default=DEFAULT_DUMP)
    parser.add_argument("--json", type=Path, help="write the full report as JSON")
    parser.add_argument(
        "--markdown", action="store_true", help="print a Markdown report body"
    )
    args = parser.parse_args(argv)

    if not args.desc_dump.exists():
        raise SystemExit(
            f"DescDump not found at {args.desc_dump}\n"
            "Build it with: cd spec/runners/wallet_diff && lake build descDump"
        )
    cases = [json.loads(line) for line in args.cases.read_text().splitlines() if line]
    checks = build_checks(cases)
    descriptor_bearing = len(checks)

    decoder_pairs, decoder_failures = decoder_self_check(cases)
    if decoder_failures:
        raise SystemExit(
            "address decoder self-check failed; refusing to join:\n"
            + "\n".join(decoder_failures)
        )

    result = compare_checks(checks, args.desc_dump)
    report = {
        "cases_file": str(args.cases),
        "desc_dump": str(args.desc_dump),
        "corpus_cases": len(cases),
        "descriptor_bearing": descriptor_bearing,
        "decoder_pairs": decoder_pairs,
        "decoder_failures": decoder_failures,
        **result,
    }

    if args.markdown:
        print(markdown_summary(report))
    else:
        print(
            f"corpus={len(cases)} descriptor-bearing={descriptor_bearing} "
            f"compared={report['compared']} agreed={report['agreed']} "
            f"rate={report['agreement_rate'] * 100:.1f}% "
            f"skipped={report['counts']['skip']} "
            f"decoder-self-check={decoder_pairs}/{decoder_pairs}"
        )
        print(
            "  script={compare-script} error={compare-error} "
            "commitment={compare-commitment} parse={compare-parse}".format(
                **report["counts"]
            )
        )
        if report["mismatches"]:
            print("\nMISMATCHES")
            for row in report["mismatches"]:
                print(f"  {row['id']} [{row['mode']}]")
                print(f"    input:    {row['input']}")
                print(f"    expected: {row['expected']}")
                print(f"    actual:   {row['actual']}")
                print(f"    anchor:   {row['anchor']}")
        else:
            print("\nNo byte/error-family mismatches.")
        if report["class_notes"]:
            print("\nCLASS-DETAIL NOTES (same family, different label)")
            for row in report["class_notes"]:
                print(
                    f"  {row['id']}: core={row['expected_class']} "
                    f"lean={row['actual_class']}"
                )
        print("\nSKIPPED")
        by_reason: dict[str, list[str]] = {}
        for row in report["skipped"]:
            by_reason.setdefault(row["reason"], []).append(row["id"])
        for reason in sorted(by_reason):
            print(f"  {reason} ({len(by_reason[reason])}):")
            print("    " + ", ".join(by_reason[reason]))

    if args.json:
        args.json.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    return 0 if not report["mismatches"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
