#!/usr/bin/env python3
"""Deterministic behavioral differential harness for the C and L legs.

This harness is deliberately independent of the per-cell / IR machinery.  It
replays every case-like row of the pinned Core ``script_tests.json`` through
the C leg (``equiv_entry``, ABI v2) and the generated C++ twin
(``spec/equiv/twin/build/libtwin.so``, also ABI v2) and compares the observed
``(result, error_kind)`` with

  * the vector's ``expected`` value (Core's own test expectation),
  * the twin verdict (the L leg; the primary comparison), and
  * the Lean interpreter model's verdict in
    ``spec/data/l2/scr/results/tierC.l2r`` as an oracle cross-check.

``tierC.l2r`` is **not** the L leg (see F-HARNESS-001); every record labels it
``lean-model-not-twin``.  It does **not** prove anything at the LLVM IR level.
A behavioral agreement is evidence about these builds on this corpus, nothing
more.

Encoding rules (all copied from the pinned Core test framework, never
invented):

  * A crediting transaction is built exactly as
    ``src/test/util/transaction_utils.cpp::BuildCreditingTransaction`` does
    (version 1, null prevout, scriptSig = OP_0 OP_0, one output).
  * The spending transaction is built exactly as ``BuildSpendingTransaction``
    does (version 1, one input spending vout 0, one empty output, locktime 0).
  * ``prevout.hash`` is the double-SHA256 of the crediting transaction.
  * Witness rows carry their witness stack in ``tx_bytes`` (TX_WITH_WITNESS).
  * ``CLEANSTACK`` implies ``P2SH|WITNESS`` exactly as
    ``src/test/script_tests.cpp::DoTest`` does before calling VerifyScript.
  * The seven taproot rows use Core's ``#SCRIPT#`` / ``#CONTROLBLOCK#`` /
    ``#TAPROOTOUTPUT#`` auto-generation with ``keys.key0`` (private key 1,
    i.e. internal x-only key = G.x), one tapscript leaf at depth 0.
  * ``NULLFAIL`` in the JSON is Core's test-framework name for
    ``SCRIPT_ERR_SIG_NULLFAIL`` (``script_errors[]`` in
    ``src/test/script_tests.cpp``).  It is the only such alias.

Usage:
    python3 spec/equiv/differential/run.py [--core-lib PATH]
        [--twin-lib PATH] [--out-dir DIR]

Exit codes: 0 = ran, no C/L_twin disagreement and no encode failure;
            1 = a C/L disagreement, an out-of-domain row, or an encode
                failure (details are still written);
            2 = the C library is missing/unloadable.
"""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
import struct
import sys

# --------------------------------------------------------------------------
# Pins and paths (verified and recorded, never guessed)
# --------------------------------------------------------------------------
HERE = os.path.dirname(os.path.abspath(__file__))
EQUIV = os.path.dirname(HERE)                 # spec/equiv
ROOT = os.path.dirname(os.path.dirname(EQUIV))  # repo root

DEFAULT_CORE_LIB = "/tmp/opencode/cbuild/libequiv-core.so"
DEFAULT_TWIN_LIB = os.path.join(EQUIV, "twin/build/libtwin.so")
CORPUS = os.path.join(ROOT, "spec/data/core/script_tests.json")
SELECTIONS = os.path.join(EQUIV, "corpus/selections")
L_VERDICTS = os.path.join(ROOT, "spec/data/l2/scr/results/tierC.l2r")
ERROR_HEADER = os.path.join(EQUIV, "contract/error_kind.h")

PINNED_SCRIPT_TESTS_SHA256 = (
    "7fb93dea245f68b627d214e0d51969c4f29fefaae1ac94ca1eba5fe8322f864c"
)
PINNED_L_VERDICTS_SHA256 = (
    "88624ebfb4c772be5f353feea4ea3972923e7dcca1ed0cc57805d6361d7df1b6"
)

# INVENTORY.md counts.  A mismatch is corpus drift, not something to paper
# over: fail loudly.
FAMILY_ORDER = [
    "stack", "flow", "numeric", "hash", "checksig",
    "cms", "locktime", "disabled", "witness", "taproot",
]
FAMILY_COUNTS = {
    "stack": 316, "flow": 297, "numeric": 335, "hash": 115,
    "checksig": 90, "cms": 117, "locktime": 21, "disabled": 24,
    "witness": 134, "taproot": 7,
}

# JSON test name -> shared enum name.  Only NULLFAIL differs (script_errors[]
# in src/test/script_tests.cpp).
EXPECTED_ALIAS = {"NULLFAIL": "SIG_NULLFAIL"}

# The R leg is deliberately not run in this pass.  The fact is recorded on
# every row rather than leaving a silent third-leg hole.
R_BLOCK_REASON = (
    "R leg not run in this differential pass: the official clean R ABI shim "
    "exists (spec/equiv/shims/rust/entry.rs, source sha256 1fd706b8...; "
    "built .so 73e3d2d9...; E0 green), but its public differential entry "
    "supports one input, input_index 0, flags 0 only and exposes no typed "
    "ScriptError. Multi-input/flags rows and error-kind parity are blocked "
    "by F-HARNESS-002 / R-GAP-01, not by a stub. C-vs-L only."
)

# F-HARNESS-001: `tierC.l2r` is the Lean *model* runner's output, not the
# generated C++ twin.  Both lanes are recorded; only the twin lane may be
# called C-L.
LEAN_MODEL_IDENTITY = "lean-model-not-twin"
TWIN_IDENTITY = "twin-libtwin"
LEAN_MODEL_NOTE = (
    "tierC.l2r was produced by L2ScrRunner.lean (the Lean interpreter "
    "model), not by the generated C++ twin.  It is recorded as an oracle "
    "cross-check, never as the L leg.  See "
    "findings/cross/F-HARNESS-001-lean-verdicts-labelled-L.md."
)


def canonical_error_name(name: str) -> str:
    return EXPECTED_ALIAS.get(name, name)


def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def contract_hash() -> str:
    """contract/tape.md section 10 recipe, byte-for-byte concatenation."""
    h = hashlib.sha256()
    for rel in ("contract/ABI.md", "contract/tape.md",
                "contract/error_kind.h", "contract/corpus_schema.md"):
        with open(os.path.join(EQUIV, rel), "rb") as fh:
            h.update(fh.read())
    return h.hexdigest()


# --------------------------------------------------------------------------
# Core opcode names.  Extracted from GetOpName() at the pin and encoded
# statically; ParseScript accepts both "OP_ADD" and "ADD".
# --------------------------------------------------------------------------
OPS = {
    "OP_0": 0x00, "OP_FALSE": 0x00, "OP_PUSHDATA1": 0x4c,
    "OP_PUSHDATA2": 0x4d, "OP_PUSHDATA4": 0x4e, "OP_1NEGATE": 0x4f,
    "OP_RESERVED": 0x50,
    "OP_1": 0x51, "OP_2": 0x52, "OP_3": 0x53, "OP_4": 0x54,
    "OP_5": 0x55, "OP_6": 0x56, "OP_7": 0x57, "OP_8": 0x58,
    "OP_9": 0x59, "OP_10": 0x5a, "OP_11": 0x5b, "OP_12": 0x5c,
    "OP_13": 0x5d, "OP_14": 0x5e, "OP_15": 0x5f, "OP_16": 0x60,
    "OP_NOP": 0x61, "OP_VER": 0x62, "OP_IF": 0x63, "OP_NOTIF": 0x64,
    "OP_VERIF": 0x65, "OP_VERNOTIF": 0x66, "OP_ELSE": 0x67,
    "OP_ENDIF": 0x68, "OP_VERIFY": 0x69, "OP_RETURN": 0x6a,
    "OP_TOALTSTACK": 0x6b, "OP_FROMALTSTACK": 0x6c, "OP_2DROP": 0x6d,
    "OP_2DUP": 0x6e, "OP_3DUP": 0x6f, "OP_2OVER": 0x70,
    "OP_2ROT": 0x71, "OP_2SWAP": 0x72, "OP_IFDUP": 0x73,
    "OP_DEPTH": 0x74, "OP_DROP": 0x75, "OP_DUP": 0x76, "OP_NIP": 0x77,
    "OP_OVER": 0x78, "OP_PICK": 0x79, "OP_ROLL": 0x7a, "OP_ROT": 0x7b,
    "OP_SWAP": 0x7c, "OP_TUCK": 0x7d,
    "OP_CAT": 0x7e, "OP_SUBSTR": 0x7f, "OP_LEFT": 0x80,
    "OP_RIGHT": 0x81, "OP_SIZE": 0x82,
    "OP_INVERT": 0x83, "OP_AND": 0x84, "OP_OR": 0x85, "OP_XOR": 0x86,
    "OP_EQUAL": 0x87, "OP_EQUALVERIFY": 0x88, "OP_RESERVED1": 0x89,
    "OP_RESERVED2": 0x8a,
    "OP_1ADD": 0x8b, "OP_1SUB": 0x8c, "OP_2MUL": 0x8d,
    "OP_2DIV": 0x8e, "OP_NEGATE": 0x8f, "OP_ABS": 0x90, "OP_NOT": 0x91,
    "OP_0NOTEQUAL": 0x92,
    "OP_ADD": 0x93, "OP_SUB": 0x94, "OP_MUL": 0x95, "OP_DIV": 0x96,
    "OP_MOD": 0x97, "OP_LSHIFT": 0x98, "OP_RSHIFT": 0x99,
    "OP_BOOLAND": 0x9a, "OP_BOOLOR": 0x9b, "OP_NUMEQUAL": 0x9c,
    "OP_NUMEQUALVERIFY": 0x9d, "OP_NUMNOTEQUAL": 0x9e,
    "OP_LESSTHAN": 0x9f, "OP_GREATERTHAN": 0xa0,
    "OP_LESSTHANOREQUAL": 0xa1, "OP_GREATERTHANOREQUAL": 0xa2,
    "OP_MIN": 0xa3, "OP_MAX": 0xa4, "OP_WITHIN": 0xa5,
    "OP_RIPEMD160": 0xa6, "OP_SHA1": 0xa7, "OP_SHA256": 0xa8,
    "OP_HASH160": 0xa9, "OP_HASH256": 0xaa, "OP_CODESEPARATOR": 0xab,
    "OP_CHECKSIG": 0xac, "OP_CHECKSIGVERIFY": 0xad,
    "OP_CHECKMULTISIG": 0xae, "OP_CHECKMULTISIGVERIFY": 0xaf,
    "OP_NOP1": 0xb0, "OP_CHECKLOCKTIMEVERIFY": 0xb1, "OP_NOP2": 0xb1,
    "OP_CHECKSEQUENCEVERIFY": 0xb2, "OP_NOP3": 0xb2, "OP_NOP4": 0xb3,
    "OP_NOP5": 0xb4, "OP_NOP6": 0xb5, "OP_NOP7": 0xb6,
    "OP_NOP8": 0xb7, "OP_NOP9": 0xb8, "OP_NOP10": 0xb9,
    "OP_CHECKSIGADD": 0xba, "OP_INVALIDOPCODE": 0xff,
}
ALIASES = {
    name[3:]: value
    for name, value in OPS.items()
    if name.startswith("OP_") and name not in (
        "OP_TRUE", "OP_FALSE", "OP_NOP2", "OP_NOP3"
    )
}


def _compact_size(n: int) -> bytes:
    if n < 0xFD:
        return bytes([n])
    if n <= 0xFFFF:
        return b"\xfd" + struct.pack("<H", n)
    if n <= 0xFFFFFFFF:
        return b"\xfe" + struct.pack("<I", n)
    return b"\xff" + struct.pack("<Q", n)


def _push_data(data: bytes) -> bytes:
    n = len(data)
    if n < 0x4C:
        return bytes([n]) + data
    if n <= 0xFF:
        return b"\x4c" + bytes([n]) + data
    if n <= 0xFFFF:
        return b"\x4d" + struct.pack("<H", n) + data
    return b"\x4e" + struct.pack("<I", n) + data


def _push_int(n: int) -> bytes:
    """CScript::operator<<(int64_t) / push_int64, at the pin."""
    if n == -1 or 1 <= n <= 16:
        return bytes([n + (0x51 - 1)])
    if n == 0:
        return b"\x00"
    neg = n < 0
    a = -n if neg else n
    out = bytearray()
    while a:
        out.append(a & 0xFF)
        a >>= 8
    if out[-1] & 0x80:
        out.append(0x80 if neg else 0x00)
    elif neg:
        out[-1] |= 0x80
    return _push_data(bytes(out))


def parse_script(text: str) -> bytes:
    """CScript ParseScript() at the pin (src/core_io.cpp)."""
    out = bytearray()
    for word in text.replace("\t", " ").replace("\n", " ").split(" "):
        if not word:
            continue
        if word.isdigit() or (
            word[0] == "-" and len(word) > 1 and word[1:].isdigit()
        ):
            n = int(word)
            if n > 0xFFFFFFFF or n < -0xFFFFFFFF:
                raise ValueError(f"decimal out of ParseScript range: {word}")
            out += _push_int(n)
        elif (
            word.startswith("0x")
            and len(word) > 2
            and len(word[2:]) % 2 == 0
            and all(c in "0123456789abcdefABCDEF" for c in word[2:])
        ):
            out += bytes.fromhex(word[2:])
        elif len(word) >= 2 and word[0] == "'" and word[-1] == "'":
            out += _push_data(word[1:-1].encode())
        else:
            name = word if word in OPS else (
                "OP_" + word if "OP_" + word in OPS else None
            )
            if name is None:
                raise ValueError(f"unknown opcode: {word!r}")
            out.append(OPS[name])
    return bytes(out)


# --------------------------------------------------------------------------
# BIP341 taproot auto-generation for the 7 corpus rows.  Core uses
# keys.key0 (private key 1): internal x-only key = G.x, one leaf at depth 0.
# --------------------------------------------------------------------------
FIELD_P = 2**256 - 2**32 - 977
CURVE_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
GX = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
GY = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8


def _padd(p, q):
    if p is None:
        return q
    if q is None:
        return p
    if p[0] == q[0]:
        if (p[1] + q[1]) % FIELD_P == 0:
            return None
        lam = (3 * p[0] * p[0]) * pow(2 * p[1], FIELD_P - 2, FIELD_P) % FIELD_P
    else:
        lam = (q[1] - p[1]) * pow(q[0] - p[0], FIELD_P - 2, FIELD_P) % FIELD_P
    x = (lam * lam - p[0] - q[0]) % FIELD_P
    return (x, (lam * (p[0] - x) - p[1]) % FIELD_P)


def _pmul(k, p):
    r = None
    while k:
        if k & 1:
            r = _padd(r, p)
        p = _padd(p, p)
        k >>= 1
    return r


def _lift_x(x):
    y2 = (pow(x, 3, FIELD_P) + 7) % FIELD_P
    y = pow(y2, (FIELD_P + 1) // 4, FIELD_P)
    if y * y % FIELD_P != y2:
        raise ValueError("taproot internal key is not on the curve")
    return (x, y if y % 2 == 0 else FIELD_P - y)


def _tagged_hash(tag: str, msg: bytes) -> bytes:
    t = hashlib.sha256(tag.encode()).digest()
    return hashlib.sha256(t + t + msg).digest()


def taproot_output_and_control(leaf_script: bytes):
    """Return (32-byte output key, 33-byte control block) for key0/one leaf."""
    leaf_hash = _tagged_hash(
        "TapLeaf", bytes([0xC0]) + _compact_size(len(leaf_script)) + leaf_script
    )
    internal = GX
    tweak = int.from_bytes(
        _tagged_hash("TapTweak", internal.to_bytes(32, "big") + leaf_hash),
        "big",
    )
    # BIP341 uses lift_x(internal), i.e. the even-Y point.
    q = _padd(_lift_x(internal), _pmul(tweak, (GX, GY)))
    if q is None:
        raise ValueError("taproot tweak produced the point at infinity")
    parity = q[1] & 1
    control = bytes([0xC0 | parity]) + internal.to_bytes(32, "big")
    return q[0].to_bytes(32, "big"), control


# --------------------------------------------------------------------------
# Transaction encoding (Core TX_WITH_WITNESS / TX_NO_WITNESS at the pin)
# --------------------------------------------------------------------------
def serialize_credit(spk: bytes, amount: int) -> bytes:
    """BuildCreditingTransaction(); serialized TX_NO_WITNESS."""
    s = struct.pack("<i", 1)                 # version
    s += _compact_size(1)                    # vin count
    s += b"\x00" * 32 + struct.pack("<I", 0xFFFFFFFF)  # null prevout
    s += _compact_size(2) + b"\x00\x00"      # CScript() << CScriptNum(0) << CScriptNum(0)
    s += struct.pack("<I", 0xFFFFFFFF)       # SEQUENCE_FINAL
    s += _compact_size(1)                    # vout count
    s += struct.pack("<q", amount) + _compact_size(len(spk)) + spk
    s += struct.pack("<I", 0)                # nLockTime
    return s


def serialize_spend(prev_hash: bytes, script_sig: bytes,
                    witness: list[bytes], amount: int) -> bytes:
    """BuildSpendingTransaction(); serialized TX_WITH_WITNESS."""
    s = struct.pack("<i", 1)                 # version
    has_witness = len(witness) > 0           # CScriptWitness::IsNull() == stack.empty()
    if has_witness:
        s += b"\x00\x01"                     # marker + witness flag
    s += _compact_size(1)                    # vin count
    s += prev_hash + struct.pack("<I", 0)    # prevout (txid, vout 0)
    s += _compact_size(len(script_sig)) + script_sig
    s += struct.pack("<I", 0xFFFFFFFF)       # SEQUENCE_FINAL
    s += _compact_size(1)                    # vout count
    s += struct.pack("<q", amount) + _compact_size(0)  # empty CScript()
    if has_witness:
        s += _compact_size(len(witness))
        for item in witness:
            s += _compact_size(len(item)) + item
    s += struct.pack("<I", 0)                # nLockTime
    return s


def build_tape(spk: bytes, script_sig: bytes,
               witness: list[bytes], amount: int) -> bytes:
    credit = serialize_credit(spk, amount)
    prev_hash = hashlib.sha256(hashlib.sha256(credit).digest()).digest()
    return serialize_spend(prev_hash, script_sig, witness, amount)


# --------------------------------------------------------------------------
# Flags (contract/tape.md section 5)
# --------------------------------------------------------------------------
FLAG_BITS = {
    "P2SH": 0x000001, "STRICTENC": 0x000002, "DERSIG": 0x000004,
    "LOW_S": 0x000008, "NULLDUMMY": 0x000010, "SIGPUSHONLY": 0x000020,
    "MINIMALDATA": 0x000040, "DISCOURAGE_UPGRADABLE_NOPS": 0x000080,
    "CLEANSTACK": 0x000100, "CHECKLOCKTIMEVERIFY": 0x000200,
    "CHECKSEQUENCEVERIFY": 0x000400, "WITNESS": 0x000800,
    "DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM": 0x001000,
    "MINIMALIF": 0x002000, "NULLFAIL": 0x004000,
    "WITNESS_PUBKEYTYPE": 0x008000, "CONST_SCRIPTCODE": 0x010000,
    "TAPROOT": 0x020000, "DISCOURAGE_UPGRADABLE_TAPROOT_VERSION": 0x040000,
    "DISCOURAGE_OP_SUCCESS": 0x080000,
    "DISCOURAGE_UPGRADABLE_PUBKEYTYPE": 0x100000,
}
MAX_SCRIPT_VERIFY_FLAGS = 0x1FFFFF
MAX_MONEY = 21_000_000 * 100_000_000


def parse_flags(text: str) -> int:
    flags = 0
    if text and text != "NONE":
        for word in text.split(","):
            if word not in FLAG_BITS:
                raise ValueError(f"unknown script-verify flag: {word!r}")
            flags |= FLAG_BITS[word]
    # src/test/script_tests.cpp::DoTest, before VerifyScript.
    if flags & FLAG_BITS["CLEANSTACK"]:
        flags |= FLAG_BITS["P2SH"] | FLAG_BITS["WITNESS"]
    return flags


# --------------------------------------------------------------------------
# Corpus / L verdict joining
# --------------------------------------------------------------------------
def load_error_names(path: str) -> tuple[dict[str, int], dict[int, str]]:
    name_to_value: dict[str, int] = {}
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line.startswith("EQUIV_ERR_") or "=" not in line:
                continue
            name, rest = line.split("=", 1)
            name = name.strip()
            value = int(rest.split(",")[0].strip().rstrip("}").strip(), 0)
            name_to_value[name.replace("EQUIV_ERR_", "")] = value
    if not name_to_value:
        raise RuntimeError(f"no enum values parsed from {path}")
    value_to_name = {v: k for k, v in name_to_value.items()}
    return name_to_value, value_to_name


def is_case(entry) -> bool:
    return (
        isinstance(entry, list)
        and len(entry) >= 3
        and not (len(entry) == 1 and isinstance(entry[0], str))
    )


def split_entry(entry):
    if isinstance(entry[0], list):
        return True, entry[1], entry[2], entry[3], entry[4]
    return False, entry[0], entry[1], entry[2], entry[3]


def load_corpus():
    with open(CORPUS, "rb") as fh:
        raw = fh.read()
    digest = sha256_bytes(raw)
    if digest != PINNED_SCRIPT_TESTS_SHA256:
        raise RuntimeError(
            f"script_tests.json sha256 drift: {digest} != "
            f"{PINNED_SCRIPT_TESTS_SHA256}"
        )
    data = json.loads(raw)
    rows = [(idx, entry) for idx, entry in enumerate(data) if is_case(entry)]
    return data, rows, digest


def load_families(data, rows):
    """Return source_index -> ordered family tuple, plus integrity metadata."""
    by_source = {idx: entry for idx, entry in rows}
    memberships: dict[int, set[str]] = {}
    file_hashes: dict[str, str] = {}
    per_file: dict[str, int] = {}
    checked = 0
    for family in FAMILY_ORDER:
        path = os.path.join(SELECTIONS, f"{family}.jsonl")
        file_hashes[family] = sha256_file(path)
        count = 0
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                rec = json.loads(line)
                count += 1
                idx = rec["source_index"]
                if idx not in by_source:
                    raise RuntimeError(
                        f"{family}: source_index {idx} is not a case-like row"
                    )
                entry = by_source[idx]
                wit, ss, spk, flags, expected = split_entry(entry)
                for field, left, right in (
                    ("witness_form", rec.get("witness_form"), wit),
                    ("script_sig", rec.get("script_sig"), ss),
                    ("script_pubkey", rec.get("script_pubkey"), spk),
                    ("flags", rec.get("flags"), flags),
                    ("expected", rec.get("expected"), expected),
                ):
                    if left != right:
                        raise RuntimeError(
                            f"{family}: selection {idx} field {field} "
                            f"differs from script_tests.json"
                        )
                raw = json.dumps(entry, sort_keys=True,
                                 separators=(",", ":")).encode()
                if rec.get("row_sha256") != sha256_bytes(raw):
                    raise RuntimeError(
                        f"{family}: selection {idx} row_sha256 does not match "
                        f"the source entry"
                    )
                memberships.setdefault(idx, set()).add(family)
                checked += 1
        per_file[family] = count
        if count != FAMILY_COUNTS[family]:
            raise RuntimeError(
                f"{family}: selection has {count} rows, INVENTORY says "
                f"{FAMILY_COUNTS[family]}"
            )
    ordered = {
        idx: tuple(f for f in FAMILY_ORDER if f in fams)
        for idx, fams in memberships.items()
    }
    return ordered, {
        "selection_files_sha256": file_hashes,
        "selection_rows": per_file,
        "selection_rows_joined": checked,
        "selection_hash_mismatches": 0,
    }


def load_l_verdicts(rows):
    """Join tierC.l2r by ordinal id AND verify want == vector expected.

    The file has no source-index column.  We therefore only join a row when
    its id is the expected ordinal id *and* its `want` column equals the
    vector's expected name.  Any row failing either check is left unjoined
    (blocked) rather than guessed.
    """
    digest = sha256_file(L_VERDICTS)
    if digest != PINNED_L_VERDICTS_SHA256:
        raise RuntimeError(
            f"tierC.l2r sha256 drift: {digest} != {PINNED_L_VERDICTS_SHA256}"
        )
    by_id: dict[str, dict] = {}
    with open(L_VERDICTS, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if not line:
                continue
            parts = line.split("|")
            if len(parts) != 6:
                raise RuntimeError(f"malformed tierC.l2r line: {line!r}")
            row_id, verdict, err, our_bool, want, agree = parts
            by_id[row_id] = {
                "id": row_id, "verdict": verdict, "error_name": err,
                "our_bool": our_bool == "true", "want": want, "agree": agree,
            }
    joined = 0
    id_ok = 0
    want_ok = 0
    failures = []
    for ordinal, (idx, entry) in enumerate(rows):
        row_id = f"sc-{ordinal:04d}"
        _, _, _, _, expected = split_entry(entry)
        rec = by_id.get(row_id)
        if rec is None:
            failures.append((row_id, "no L verdict line for id"))
            continue
        joined += 1
        if rec["id"] == row_id:
            id_ok += 1
        if canonical_error_name(rec["want"]) == canonical_error_name(expected):
            want_ok += 1
        else:
            failures.append((
                row_id,
                f"L want={rec['want']!r} != vector expected={expected!r}",
            ))
    meta = {
        "path": os.path.relpath(L_VERDICTS, ROOT),
        "sha256": digest,
        "lines": len(by_id),
        "joined_by_id": joined,
        "id_matches": id_ok,
        "want_matches_vector_expected": want_ok,
        "join_failures": failures,
        # Provenance note: the L2-SCR lane's oracle was read at c50817fe,
        # while the vendored corpus is cce32b168.  See README/report.
        "source_pin_note": (
            "L verdicts were produced by the Lean L2-SCR runner whose oracle "
            "was read at c50817fe; the vendored corpus is pinned at "
            "cce32b168. The want column was independently checked against "
            "the corpus expected value for every row before joining."
        ),
    }
    return by_id, meta


def twin_metadata(path: str, leg: "CLeg") -> dict:
    """Describe the generated-twin lane without overclaiming its coverage."""
    meta = {
        "leg_identity": TWIN_IDENTITY,
        "status": "available",
        "path": os.path.abspath(path),
        "sha256": leg.sha256,
        "symbol": "equiv_entry",
        "abi": 2,
        "boundary_note": (
            "Result 3 is the twin's declared 'outside subset / unjudged' "
            "boundary (twin/README.md), not a script verdict.  Rows that hit "
            "it are blocked, never counted as disagreements."
        ),
    }
    ir_path = os.path.join(EQUIV, "twin/build/twin.ir.json")
    if os.path.isfile(ir_path):
        try:
            with open(ir_path, encoding="utf-8") as fh:
                ir = json.load(fh)
            meta["generator"] = ir.get("generator")
            meta["subset"] = ir.get("subset")
            meta["ir_path"] = os.path.relpath(ir_path, ROOT)
            meta["ir_sha256"] = sha256_file(ir_path)
        except (OSError, ValueError):
            pass
    return meta


# --------------------------------------------------------------------------
# C leg
# --------------------------------------------------------------------------
class CLeg:
    def __init__(self, path: str):
        if not os.path.isfile(path):
            raise FileNotFoundError(f"C leg library not found: {path}")
        self.path = path
        self.sha256 = sha256_file(path)
        self.lib = ctypes.CDLL(path)
        self.fn = self.lib.equiv_entry
        self.fn.argtypes = [
            ctypes.c_void_p, ctypes.c_uint64,
            ctypes.c_void_p, ctypes.c_uint64,
            ctypes.c_int64, ctypes.c_uint32, ctypes.c_uint64,
            ctypes.POINTER(ctypes.c_int),
        ]
        self.fn.restype = ctypes.c_int

    def call(self, tx: bytes, spk: bytes, amount: int, flags: int):
        tx_arr = (ctypes.c_uint8 * len(tx)).from_buffer_copy(tx) if tx else None
        spk_arr = (ctypes.c_uint8 * len(spk)).from_buffer_copy(spk) if spk else None
        kind = ctypes.c_int(-1)
        result = self.fn(
            ctypes.cast(tx_arr, ctypes.c_void_p) if tx_arr is not None else None,
            len(tx),
            ctypes.cast(spk_arr, ctypes.c_void_p) if spk_arr is not None else None,
            len(spk),
            amount, 0, flags, ctypes.byref(kind),
        )
        return result, kind.value


# --------------------------------------------------------------------------
# One vector -> encoded call inputs
# --------------------------------------------------------------------------
def decode_vector(entry):
    """Return (script_sig, spk, flags, expected, witness, amount, raw)."""
    witness_form, ss_text, spk_text, flags_text, expected = split_entry(entry)
    if witness_form:
        wit: list[bytes | None] = []
        for item in entry[0][:-1]:
            if item.startswith("#SCRIPT#"):
                wit.append(parse_script(item[len("#SCRIPT#"):]))
            elif item == "#CONTROLBLOCK#":
                wit.append(None)
            else:
                wit.append(bytes.fromhex(item))
        amount = round(entry[0][-1] * 100_000_000)
    else:
        wit = []
        amount = 0
    script_sig = parse_script(ss_text)
    if spk_text == "0x51 0x20 #TAPROOTOUTPUT#":
        if len(wit) < 2 or not isinstance(wit[-2], bytes) or wit[-1] is not None:
            raise ValueError("taproot witness is not [..., #SCRIPT#, #CONTROLBLOCK#]")
        leaf_script = wit[-2]
        output_key, control = taproot_output_and_control(leaf_script)
        wit = wit[:-1] + [control]
        spk = b"\x51\x20" + output_key
    else:
        if any(item is None for item in wit):
            raise ValueError("#CONTROLBLOCK# outside a taproot output vector")
        spk = parse_script(spk_text)
    flags = parse_flags(flags_text)
    witness = [w for w in wit if w is not None]
    raw = {
        "witness_form": witness_form,
        "script_sig_text": ss_text,
        "script_pubkey_text": spk_text,
        "flags_text": flags_text,
        "expected_text": expected,
        "witness_form_items": entry[0][:-1] if witness_form else [],
        "amount_btc": entry[0][-1] if witness_form else None,
    }
    return script_sig, spk, flags, expected, witness, amount, raw


def family_names(families):
    return list(families) if families else ["unassigned"]


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
def tally(recs):
    return {
        "rows": len(recs),
        "attempted": sum(1 for r in recs if r["C"] is not None),
        "in_domain": sum(1 for r in recs if r["domain"] == "in"),
        "agree": sum(1 for r in recs if r["status"] == "agree"),
        "disagree": sum(1 for r in recs if r["status"] == "disagree"),
        "blocked": sum(1 for r in recs if r["status"] == "blocked"),
        "c_vs_expected_agree": sum(
            1 for r in recs if r["c_vs_expected"] == "agree"
        ),
        "c_vs_expected_disagree": sum(
            1 for r in recs if r["c_vs_expected"] == "disagree"
        ),
        "lean_model_agree": sum(
            1 for r in recs if r["c_vs_lean_model"] == "agree"
        ),
        "lean_model_disagree": sum(
            1 for r in recs if r["c_vs_lean_model"] == "disagree"
        ),
        "lean_model_blocked": sum(
            1 for r in recs if r["lean_model_status"] == "blocked"
        ),
        "twin_agree": sum(1 for r in recs if r["c_vs_l_twin"] == "agree"),
        "twin_disagree": sum(
            1 for r in recs if r["c_vs_l_twin"] == "disagree"
        ),
        "twin_blocked": sum(
            1 for r in recs if r["c_vs_l_twin"] == "blocked"
        ),
        "twin_unsupported": sum(
            1 for r in recs
            if r["L_twin"] is not None and r["L_twin"]["result"] == 3
        ),
        "out_of_domain": sum(1 for r in recs if r["domain"] == "out"),
        "internal": sum(1 for r in recs if r["domain"] == "internal"),
        "encode_failures": sum(1 for r in recs if r["encode_failed"]),
        "c_call_failures": sum(1 for r in recs if r["c_call_failed"]),
        "twin_call_failures": sum(1 for r in recs if r["twin_call_failed"]),
        "r_blocked": sum(1 for r in recs if r["R"]["status"] == "blocked"),
    }


def _wrap_ids(ids, width=108):
    out, line = [], ""
    for item in ids:
        piece = (item if not line else " " + item)
        if len(line) + len(piece) > width:
            out.append(line)
            line = item
        else:
            line += piece
    if line:
        out.append(line)
    return "\n".join(out)


def render_disagreements(records, totals, encode_failures, run_failures,
                         determinism):
    """Build results/disagreements.md from the records.  No timestamps."""
    filed_twin = {
        "sc-0365": ("findings/differential/"
                    "F-DIV-002-twin-equal-false-encoding.md"),
    }
    lines = []
    add = lines.append
    add("# Differential disagreements")
    add("")
    add("Generated deterministically by `spec/equiv/differential/run.py`. "
        "Every case-like row of the pinned corpus is represented in "
        "`c-l.jsonl`; nothing is dropped.")
    add("")
    add("**Leg identities (F-HARNESS-001).** `L_twin` is the generated C++ "
        "twin (`twin/build/libtwin.so`), the actual L leg. `L` (and the "
        "lean-model columns) is `tierC.l2r`, produced by the Lean "
        "*interpreter model* at oracle pin `c50817fe`; it is an oracle "
        "cross-check, never the L leg.")
    add("")
    add("A behavioral agreement is evidence about these builds on this "
        "corpus, **not** an LLVM IR proof.")
    add("")
    add("## Counts")
    add("")
    add("| Metric | Count |")
    add("|---|---:|")
    add(f"| Rows in corpus | {totals['rows']} |")
    add(f"| C calls attempted | {totals['attempted']} |")
    add(f"| C vs L_twin (twin) agree | {totals['twin_agree']} |")
    add(f"| C vs L_twin (twin) disagree | {totals['twin_disagree']} |")
    add(f"| C vs L_twin blocked (twin result 3, declared boundary) | "
        f"{totals['twin_blocked']} |")
    add(f"| C vs Lean-model oracle agree | {totals['lean_model_agree']} |")
    add(f"| C vs Lean-model oracle disagree | "
        f"{totals['lean_model_disagree']} |")
    add(f"| C vs Lean-model blocked (UNJUDGED) | "
        f"{totals['lean_model_blocked']} |")
    add(f"| C vs expected agree | {totals['c_vs_expected_agree']} |")
    add(f"| C vs expected disagree | {totals['c_vs_expected_disagree']} |")
    add(f"| Out of contract domain (C result 2) | {totals['out_of_domain']} |")
    add(f"| C internal errors (result 3) | {totals['internal']} |")
    add(f"| Encode failures | {totals['encode_failures']} |")
    add(f"| C-call failures | {totals['c_call_failures']} |")
    add(f"| Twin-call failures | {totals['twin_call_failures']} |")
    add(f"| Determinism re-run | {determinism} |")
    add("")

    add("## C vs L (twin) disagreements")
    add("")
    twin_dis = [r for r in records if r["c_vs_l_twin"] == "disagree"]
    if not twin_dis:
        add("None.")
        add("")
    else:
        for rec in twin_dis:
            add(f"### `{rec['row_id']}` ({', '.join(rec['families'])})")
            add("")
            add("Raw vector (`script_tests.json` entry):")
            add("")
            add("```json")
            add(json.dumps(rec["vector"], indent=2, sort_keys=True))
            add("```")
            add("")
            add("| Leg | Result | Error |")
            add("|---|---|---|")
            add(f"| expected | {rec['expected']['result']} | "
                f"`{rec['expected']['name']}` |")
            add(f"| C | {rec['C']['result']} | `{rec['C']['name']}` |")
            lt = rec["L_twin"]
            add(f"| L_twin | {lt['result']} | `{lt['name']}` |")
            if rec["L"] is not None:
                add(f"| Lean model | "
                    f"{'pass' if rec['L']['bool'] else 'fail'} | "
                    f"`{rec['L']['error_name']}` |")
            add("")
            if rec["c_vs_expected"] == "agree":
                disp = ("twin-bug candidate: C reproduces Core's expected "
                        "verdict")
                if rec["c_vs_lean_model"] == "agree":
                    disp += " and the Lean-model oracle does as well"
                disp += "; the twin does not"
            else:
                disp = ("C-leg/harness bug candidate: C differs from Core's "
                        "expected verdict; adjudicate before acceptance")
            if rec["row_id"] in filed_twin:
                disp += f"; filed as `{filed_twin[rec['row_id']]}`"
            add(f"**Disposition:** {disp}.")
            add("")

    add("## C vs Lean-model oracle disagreements")
    add("")
    lean_dis = [r for r in records if r["c_vs_lean_model"] == "disagree"]
    if not lean_dis:
        add("None.")
        add("")
    else:
        for rec in lean_dis:
            add(f"- `{rec['row_id']}`: expected "
                f"`{rec['expected']['name']}`, C "
                f"`{rec['C']['name']}`, Lean model "
                f"`{rec['L']['error_name'] if rec['L'] else '-'}`.")
        add("")

    add("## C vs expected disagreements")
    add("")
    cexp = [r for r in records if r["c_vs_expected"] == "disagree"]
    if not cexp:
        add("None. (The C leg reproduces Core's own test expectation on every "
            "row it judged.)")
        add("")
    else:
        for rec in cexp:
            add(f"- `{rec['row_id']}`: expected "
                f"`{rec['expected']['name']}` ({rec['expected']['kind']}), "
                f"C returned `{rec['C']['name']}` ({rec['C']['kind']}).")
        add("")

    add("## Blocked rows (explicit, not hidden)")
    add("")
    twin_blocked = [r for r in records if r["c_vs_l_twin"] == "blocked"]
    add(f"### C vs L_twin: {len(twin_blocked)} rows")
    add("")
    if not twin_blocked:
        add("None.")
        add("")
    else:
        by_reason = {}
        for rec in twin_blocked:
            by_reason.setdefault(rec["skip_reason"], []).append(rec)
        for reason, recs in sorted(by_reason.items()):
            fams = sorted({f for r in recs for f in r["families"]})
            add(f"**{len(recs)} rows** — {reason}")
            add("")
            add(f"Families: {', '.join(fams)}")
            add("")
            add("```")
            add(_wrap_ids([r["row_id"] for r in recs]))
            add("```")
            add("")
        add("These rows have **no twin verdict**; they are not counted as "
            "disagreements.")
        add("")

    lean_blocked = [r for r in records
                    if r["lean_model_status"] == "blocked"]
    add(f"### C vs Lean-model oracle: {len(lean_blocked)} rows")
    add("")
    if not lean_blocked:
        add("None.")
        add("")
    else:
        by_reason = {}
        for rec in lean_blocked:
            key = rec.get("lean_model_reason", "no Lean-model verdict")
            by_reason.setdefault(key, []).append(rec)
        for reason, recs in sorted(by_reason.items()):
            add(f"**{len(recs)} rows** — {reason}")
            add("")
            add("```")
            add(_wrap_ids([r["row_id"] for r in recs]))
            add("```")
            add("")

    add("## Out-of-domain rows")
    add("")
    out = [r for r in records if r["domain"] == "out"]
    if not out:
        add("None. Every vector encoded to a tape in the ABI v2 domain.")
        add("")
    else:
        for rec in out:
            add(f"- `{rec['row_id']}`: C returned 2; {rec['skip_reason']}")
        add("")
        add("These are **not** counted as script disagreements.")
        add("")

    add("## Encode / call failures")
    add("")
    if not encode_failures and not run_failures:
        add("None. Every vector was encoded and every C/L_twin call "
            "returned.")
        add("")
    else:
        for row_id, msg in encode_failures:
            add(f"- encode `{row_id}`: {msg}")
        for row_id, msg in run_failures:
            add(f"- call `{row_id}`: {msg}")
        add("")
    return "\n".join(lines) + "\n"


def render_summary(summary):
    """Human-readable family summary (summary.json is the machine form)."""
    t = summary["totals"]
    lt = summary["l_twin"]
    lm = summary["lean_model"]
    lines = []
    add = lines.append
    add("# Differential summary — C vs L (twin), with Lean-model cross-check")
    add("")
    add("Behavioral replay of the pinned `script_tests.json` through the C leg "
        "(`equiv_entry`, ABI v2), the generated C++ twin (`libtwin.so`, the L "
        "leg), and the Lean-model verdict file (`tierC.l2r`, an oracle "
        "cross-check). This is **behavioral evidence, not an LLVM IR proof**.")
    add("")
    add("**Label note (F-HARNESS-001).** `tierC.l2r` is the Lean *interpreter "
        "model*, not the generated twin. Only the `C vs L_twin` lane may be "
        "called C-L.")
    add("")
    add("## Totals")
    add("")
    add("| Metric | Count |")
    add("|---|---:|")
    add(f"| Case-like rows | {t['rows']} |")
    add(f"| C calls attempted | {t['attempted']} |")
    add(f"| **C vs L_twin agree** | **{t['twin_agree']}** |")
    add(f"| **C vs L_twin disagree** | **{t['twin_disagree']}** |")
    add(f"| C vs L_twin blocked (twin result 3, declared boundary) | "
        f"{t['twin_blocked']} |")
    add(f"| C vs Lean-model oracle agree | {t['lean_model_agree']} |")
    add(f"| C vs Lean-model oracle disagree | {t['lean_model_disagree']} |")
    add(f"| C vs Lean-model blocked (UNJUDGED) | {t['lean_model_blocked']} |")
    add(f"| C vs expected agree | {t['c_vs_expected_agree']} |")
    add(f"| C vs expected disagree | {t['c_vs_expected_disagree']} |")
    add(f"| Out of contract domain | {t['out_of_domain']} |")
    add(f"| C internal (result 3) | {t['internal']} |")
    add(f"| Encode failures | {t['encode_failures']} |")
    add(f"| R rows blocked | {t['r_blocked']} |")
    add(f"| Determinism re-run | {summary['determinism']} |")
    add("")
    add("## By family")
    add("")
    add("Rows may belong to several families (`families` in `c-l.jsonl`), so "
        "family counts overlap. `unassigned` are case-like rows that match no "
        "derived selection (pure pushes and similar), replayed anyway so that "
        "no vector is hidden.")
    add("")
    add("| Family | Rows | Attempted | Twin agree | Twin disagree | "
        "Twin blocked | Lean agree | Lean disagree | Lean blocked | "
        "C~expected agree | Out of domain |")
    add("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for fam in FAMILY_ORDER + ["unassigned"]:
        f = summary["families"][fam]
        add(f"| {fam} | {f['rows']} | {f['attempted']} | "
            f"{f['twin_agree']} | {f['twin_disagree']} | {f['twin_blocked']} | "
            f"{f['lean_model_agree']} | {f['lean_model_disagree']} | "
            f"{f['lean_model_blocked']} | {f['c_vs_expected_agree']} | "
            f"{f['out_of_domain']} |")
    add("")
    add("## Legs")
    add("")
    add(f"- **C**: `{summary['c_leg']['symbol']}` from "
        f"`{summary['c_leg']['path']}`, sha256 "
        f"`{summary['c_leg']['sha256']}`.")
    add(f"- **L_twin**: `{lt['path']}`, sha256 `{lt['sha256']}`, "
        f"{lt['calls']} calls; {t['twin_agree']} agree, "
        f"{t['twin_disagree']} disagree, {t['twin_blocked']} blocked "
        f"(result 3).")
    if lt.get("subset"):
        add(f"  Declared subset: {lt['subset']}.")
    add(f"- **Lean-model oracle** (not L): `{lm['path']}`, sha256 "
        f"`{lm['sha256']}`; joined by id and `want`, "
        f"{lm['want_matches_vector_expected']}/{lm['lines']} rows verified; "
        f"{t['lean_model_agree']} agree, {t['lean_model_disagree']} "
        f"disagree, {t['lean_model_blocked']} blocked.")
    add(f"- **R**: blocked — {summary['r_leg']['reason']}")
    add("")
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Behavioral differential replay of the pinned script corpus"
    )
    ap.add_argument("--core-lib", default=DEFAULT_CORE_LIB,
                    help=f"C leg shared library (default: {DEFAULT_CORE_LIB})")
    ap.add_argument("--twin-lib", default=DEFAULT_TWIN_LIB,
                    help=f"L (twin) shared library (default: {DEFAULT_TWIN_LIB})")
    ap.add_argument("--out-dir", default=os.path.join(HERE, "results"))
    ap.add_argument("--skip-repeat", action="store_true",
                    help="skip the in-process determinism re-run")
    args = ap.parse_args()

    out_dir = os.path.abspath(args.out_dir)
    os.makedirs(out_dir, exist_ok=True)

    # Capture C-level stderr (fd 2) for the whole run.  The L2 files and the
    # C library are both read-only here.
    stderr_path = os.path.join(out_dir, "stderr.log")
    saved_fd = os.dup(2)
    stderr_log = open(stderr_path, "wb")
    os.dup2(stderr_log.fileno(), 2)

    exit_code = 1
    try:
        try:
            name_to_value, value_to_name = load_error_names(ERROR_HEADER)
            data, rows, corpus_sha = load_corpus()
            families, selection_meta = load_families(data, rows)
            l_by_id, l_meta = load_l_verdicts(rows)
            c_leg = CLeg(args.core_lib)
            twin_leg = None
            if os.path.isfile(args.twin_lib):
                try:
                    twin_leg = CLeg(args.twin_lib)
                    twin_meta = twin_metadata(args.twin_lib, twin_leg)
                except Exception as exc:
                    twin_meta = {
                        "leg_identity": TWIN_IDENTITY,
                        "status": "blocked",
                        "path": os.path.abspath(args.twin_lib),
                        "reason": f"twin library failed to load: {exc}",
                    }
            else:
                twin_meta = {
                    "leg_identity": TWIN_IDENTITY,
                    "status": "blocked",
                    "path": os.path.abspath(args.twin_lib),
                    "reason": "twin library not found; C-vs-Lean-model only",
                }
        except Exception as exc:
            os.dup2(saved_fd, 2)
            print(f"FATAL: {exc}", file=sys.stderr)
            return 2

        records = []
        encode_failures = []
        run_failures = []
        replay = []
        calls = 0
        calls_twin = 0
        for ordinal, (source_index, entry) in enumerate(rows):
            row_id = f"sc-{ordinal:04d}"
            fams = families.get(source_index, ())
            rec = {
                "row_id": row_id,
                "family": family_names(fams)[0],
                "families": family_names(fams),
                "source_index": source_index,
                "row_sha256": sha256_bytes(
                    json.dumps(entry, sort_keys=True,
                               separators=(",", ":")).encode()
                ),
                "witness_form": isinstance(entry[0], list),
                "expected": None,
                "C": None,
                "L": None,
                "L_twin": None,
                "R": {"status": "blocked", "reason": R_BLOCK_REASON},
                "tape_sha256": None,
                "c_vs_expected": "blocked",
                "c_vs_lean_model": "blocked",
                "c_vs_l_twin": "blocked",
                "agree": None,
                "agree_lean_model": None,
                "status": "blocked",
                "lean_model_status": "blocked",
                "domain": "unknown",
                "skip_reason": None,
                "encode_failed": False,
                "c_call_failed": False,
                "twin_call_failed": False,
            }
            try:
                (script_sig, spk, flags, expected, witness, amount,
                 raw) = decode_vector(entry)
            except Exception as exc:
                msg = f"cannot encode vector: {type(exc).__name__}: {exc}"
                rec["skip_reason"] = msg
                rec["encode_failed"] = True
                encode_failures.append((row_id, msg))
                records.append(rec)
                continue

            rec["flags"] = flags
            rec["flags_raw"] = raw["flags_text"]
            rec["amount"] = amount
            rec["script_sig_hex"] = script_sig.hex()
            rec["script_pubkey_hex"] = spk.hex()
            rec["witness_hex"] = [w.hex() for w in witness]
            rec["vector"] = raw

            expected_name = canonical_error_name(expected)
            if expected_name != "OK" and expected_name not in name_to_value:
                msg = f"expected error {expected_name!r} not in shared enum"
                rec["skip_reason"] = msg
                rec["encode_failed"] = True
                encode_failures.append((row_id, msg))
                records.append(rec)
                continue
            expected_kind = (
                0 if expected_name == "OK" else name_to_value[expected_name]
            )
            rec["expected"] = {
                "text": expected,
                "name": expected_name,
                "kind": expected_kind,
                "result": 1 if expected_name == "OK" else 0,
                "verdict": "pass" if expected_name == "OK" else "fail",
            }

            try:
                tape = build_tape(spk, script_sig, witness, amount)
            except Exception as exc:
                msg = f"cannot build tape: {type(exc).__name__}: {exc}"
                rec["skip_reason"] = msg
                rec["encode_failed"] = True
                encode_failures.append((row_id, msg))
                records.append(rec)
                continue
            rec["tape_sha256"] = sha256_bytes(tape)

            # Domain labels mirroring tape.md section 7.  The C leg itself is
            # the authority; this only labels the record.
            pre_domain_out = (
                len(tape) == 0
                or amount < 0 or amount > MAX_MONEY
                or (flags & ~MAX_SCRIPT_VERIFY_FLAGS) != 0
                or (flags & FLAG_BITS["WITNESS"]
                    and not flags & FLAG_BITS["P2SH"])
                or (flags & FLAG_BITS["CLEANSTACK"]
                    and (not flags & FLAG_BITS["P2SH"]
                         or not flags & FLAG_BITS["WITNESS"]))
            )

            try:
                result, kind = c_leg.call(tape, spk, amount, flags)
                calls += 1
            except Exception as exc:
                msg = f"C call failed: {type(exc).__name__}: {exc}"
                rec["skip_reason"] = msg
                rec["c_call_failed"] = True
                run_failures.append((row_id, msg))
                records.append(rec)
                continue

            kind_name = value_to_name.get(kind, f"UNKNOWN_{kind}")
            rec["C"] = {
                "result": result,
                "kind": kind,
                "name": kind_name,
                "bool": result == 1,
            }

            # ---- L lane: the generated C++ twin (the actual L leg) ----
            twin_result = twin_kind = None
            twin_kind_name = None
            twin_reason = None
            if twin_leg is None:
                twin_reason = twin_meta.get("reason", "twin leg unavailable")
            else:
                try:
                    twin_result, twin_kind = twin_leg.call(
                        tape, spk, amount, flags
                    )
                    calls_twin += 1
                    twin_kind_name = value_to_name.get(
                        twin_kind, f"UNKNOWN_{twin_kind}"
                    )
                except Exception as exc:
                    twin_reason = (
                        f"L_twin call failed: {type(exc).__name__}: {exc}"
                    )
                    rec["twin_call_failed"] = True
                    run_failures.append((row_id, twin_reason))
            if twin_result is not None:
                rec["L_twin"] = {
                    "leg_identity": TWIN_IDENTITY,
                    "result": twin_result,
                    "kind": twin_kind,
                    "name": twin_kind_name,
                    "bool": twin_result == 1,
                    "supported": twin_result != 3,
                    "matches_expected": (
                        (twin_result == rec["expected"]["result"]
                         and twin_kind == rec["expected"]["kind"])
                        if twin_result in (0, 1) else None
                    ),
                }
            replay.append((row_id, tape, spk, amount, flags,
                           result, kind, twin_result, twin_kind))

            # ---- Lean-model oracle lane (tierC.l2r), not L ----
            lrec = l_by_id.get(row_id)
            l_joined = False
            l_reason = None
            if lrec is None:
                l_reason = "no L verdict line for this id"
            elif canonical_error_name(lrec["want"]) != expected_name:
                l_reason = (
                    f"L join rejected: want={lrec['want']!r} != "
                    f"expected={expected!r}"
                )
            else:
                l_joined = True
            if lrec is not None:
                rec["L"] = {
                    "leg_identity": LEAN_MODEL_IDENTITY,
                    "source": "spec/data/l2/scr/results/tierC.l2r",
                    "id": lrec["id"],
                    "verdict": lrec["verdict"],
                    "bool": lrec["our_bool"],
                    "error_name": lrec["error_name"],
                    "want": lrec["want"],
                    "agree_column": lrec["agree"],
                    "joined": l_joined,
                }
            if l_reason:
                rec["lean_model_reason"] = l_reason

            if result == 2:
                rec["domain"] = "out"
                rec["c_vs_expected"] = "n/a"
                rec["c_vs_lean_model"] = "blocked"
                rec["c_vs_l_twin"] = "blocked"
                rec["lean_model_status"] = "blocked"
                rec["status"] = "blocked"
                rec["agree"] = None
                rec["agree_lean_model"] = None
                rec["skip_reason"] = (
                    "out of contract domain: C returned 2 (bad input); "
                    "not counted as a script disagreement"
                )
            elif result == 3:
                rec["domain"] = "internal"
                rec["c_vs_expected"] = "n/a"
                rec["c_vs_lean_model"] = "blocked"
                rec["c_vs_l_twin"] = "blocked"
                rec["lean_model_status"] = "blocked"
                rec["status"] = "blocked"
                rec["agree"] = None
                rec["agree_lean_model"] = None
                rec["skip_reason"] = (
                    "C returned 3 (internal error); not counted as a script "
                    "disagreement"
                )
            else:
                rec["domain"] = "out" if pre_domain_out else "in"
                c_ok = (
                    result == rec["expected"]["result"]
                    and kind == rec["expected"]["kind"]
                )
                rec["c_vs_expected"] = "agree" if c_ok else "disagree"

                # ---- Lean-model oracle comparison (not L) ----
                l_usable = (
                    l_joined
                    and lrec is not None
                    and lrec["verdict"] in ("T", "F")
                )
                if not l_usable:
                    rec["c_vs_lean_model"] = "blocked"
                    rec["lean_model_status"] = "blocked"
                    rec["agree_lean_model"] = None
                    if lrec is not None and lrec["verdict"] == "U":
                        rec["lean_model_reason"] = (
                            "Lean-model verdict is UNJUDGED (no verdict "
                            "produced for this row)"
                        )
                    elif l_reason:
                        rec["lean_model_reason"] = l_reason
                    else:
                        rec["lean_model_reason"] = (
                            "Lean-model verdict not usable"
                        )
                else:
                    l_bool = lrec["verdict"] == "T"
                    l_name = canonical_error_name(lrec["error_name"])
                    l_ok = ((result == 1) == l_bool) and (kind_name == l_name)
                    rec["c_vs_lean_model"] = "agree" if l_ok else "disagree"
                    rec["lean_model_status"] = (
                        "agree" if l_ok else "disagree"
                    )
                    rec["agree_lean_model"] = l_ok
                    if not l_ok:
                        rec["lean_model_reason"] = (
                            f"C=({result},{kind_name}) vs "
                            f"Lean-model=({l_bool},{l_name})"
                        )

                # ---- L (twin) comparison: the primary lane ----
                if twin_leg is None or twin_result is None:
                    rec["c_vs_l_twin"] = "blocked"
                    rec["status"] = "blocked"
                    rec["agree"] = None
                    rec["skip_reason"] = (
                        twin_reason or "L_twin unavailable"
                    )
                elif twin_result == 3:
                    rec["c_vs_l_twin"] = "blocked"
                    rec["status"] = "blocked"
                    rec["agree"] = None
                    rec["skip_reason"] = (
                        "outside twin subset: L_twin returned 3 "
                        "(declared boundary, not a verdict)"
                    )
                elif twin_result == 2:
                    rec["c_vs_l_twin"] = "blocked"
                    rec["status"] = "blocked"
                    rec["agree"] = None
                    rec["skip_reason"] = (
                        "L_twin returned 2 (bad input) while C judged the tape"
                    )
                else:
                    t_ok = (
                        ((result == 1) == (twin_result == 1))
                        and (kind_name == twin_kind_name)
                    )
                    rec["c_vs_l_twin"] = "agree" if t_ok else "disagree"
                    rec["status"] = "agree" if t_ok else "disagree"
                    rec["agree"] = t_ok
                    if not t_ok:
                        rec["skip_reason"] = (
                            f"C=({result},{kind_name}) vs "
                            f"L_twin=({twin_result},{twin_kind_name})"
                        )

            records.append(rec)

        # ---- determinism replay: same bytes, same process, twice ----
        determinism = "not-run"
        if not args.skip_repeat:
            determinism = "identical"
            for (row_id, tape, spk, amount, flags, result, kind,
                 twin_result, twin_kind) in replay:
                result2, kind2 = c_leg.call(tape, spk, amount, flags)
                calls += 1
                if (result2, kind2) != (result, kind):
                    determinism = "diverged"
                    run_failures.append((
                        row_id,
                        f"C determinism: first=({result},{kind}) "
                        f"second=({result2},{kind2})",
                    ))
                if twin_leg is not None and twin_result is not None:
                    twin_result2, twin_kind2 = twin_leg.call(
                        tape, spk, amount, flags
                    )
                    calls_twin += 1
                    if (twin_result2, twin_kind2) != (twin_result, twin_kind):
                        determinism = "diverged"
                        run_failures.append((
                            row_id,
                            f"L_twin determinism: "
                            f"first=({twin_result},{twin_kind}) "
                            f"second=({twin_result2},{twin_kind2})",
                        ))

        # ---- summary ----
        by_fam = {f: [] for f in FAMILY_ORDER}
        by_fam["unassigned"] = []
        for rec in records:
            for fam in rec["families"]:
                by_fam[fam].append(rec)
        family_summary = {fam: tally(recs) for fam, recs in by_fam.items()}
        totals = tally(records)

        summary = {
            "schema": "btc-lean/equiv-differential/v1",
            "note": ("Behavioral agreement on the pinned corpus; not an "
                     "LLVM IR proof."),
            "corpus": {
                "path": "spec/data/core/script_tests.json",
                "sha256": corpus_sha,
                "case_rows": len(rows),
            },
            "c_leg": {
                "path": os.path.abspath(args.core_lib),
                "sha256": c_leg.sha256,
                "symbol": "equiv_entry",
                "abi": 2,
                "calls": calls,
            },
            "lean_model": {
                **l_meta,
                "leg_identity": LEAN_MODEL_IDENTITY,
                "note": LEAN_MODEL_NOTE,
                "agree": totals["lean_model_agree"],
                "disagree": totals["lean_model_disagree"],
                "blocked": totals["lean_model_blocked"],
            },
            "l_twin": {
                **twin_meta,
                "calls": calls_twin,
                "agree": totals["twin_agree"],
                "disagree": totals["twin_disagree"],
                "blocked": totals["twin_blocked"],
                "unsupported": totals["twin_unsupported"],
            },
            "r_leg": {
                "status": "blocked",
                "rows_blocked": len(records),
                "reason": R_BLOCK_REASON,
            },
            "selections": selection_meta,
            "contract": {
                "error_header": "contract/error_kind.h",
                "error_header_sha256": sha256_file(ERROR_HEADER),
                "hash": contract_hash(),
                "recipe": ("{ cat contract/ABI.md; cat contract/tape.md; "
                           "cat contract/error_kind.h; "
                           "cat contract/corpus_schema.md; } | sha256sum"),
            },
            "totals": totals,
            "families": family_summary,
            "determinism": determinism,
        }

        with open(os.path.join(out_dir, "c-l.jsonl"), "w",
                  encoding="utf-8", newline="\n") as fh:
            for rec in records:
                fh.write(json.dumps(rec, sort_keys=True) + "\n")
        with open(os.path.join(out_dir, "summary.json"), "w",
                  encoding="utf-8", newline="\n") as fh:
            json.dump(summary, fh, indent=2, sort_keys=True)
            fh.write("\n")
        with open(os.path.join(out_dir, "summary.md"), "w",
                  encoding="utf-8", newline="\n") as fh:
            fh.write(render_summary(summary))
        with open(os.path.join(out_dir, "disagreements.md"), "w",
                  encoding="utf-8", newline="\n") as fh:
            fh.write(render_disagreements(
                records, totals, encode_failures, run_failures, determinism
            ))

        disagree = [r for r in records if r["status"] == "disagree"]
        cexp = [r for r in records if r["c_vs_expected"] == "disagree"]
        out_dom = [r for r in records if r["domain"] == "out"]
        exit_code = 0 if (
            not encode_failures and not run_failures and not disagree
            and not cexp and not out_dom
        ) else 1
    finally:
        os.dup2(saved_fd, 2)
        stderr_log.close()

    print(
        f"differential: rows={totals['rows']} attempted={totals['attempted']} "
        f"C~L_twin agree={totals['twin_agree']} "
        f"disagree={totals['twin_disagree']} "
        f"blocked={totals['twin_blocked']} "
        f"(twin unsupported={totals['twin_unsupported']}); "
        f"C~lean-model agree={totals['lean_model_agree']} "
        f"disagree={totals['lean_model_disagree']} "
        f"blocked={totals['lean_model_blocked']}; "
        f"C~expected agree={totals['c_vs_expected_agree']} "
        f"disagree={totals['c_vs_expected_disagree']}; "
        f"out_of_domain={totals['out_of_domain']}; "
        f"determinism={determinism}"
    )
    if encode_failures:
        print("HARNESS CANNOT ENCODE VECTOR(S):", file=sys.stderr)
        for row_id, msg in encode_failures:
            print(f"  {row_id}: {msg}", file=sys.stderr)
    if run_failures:
        print("C CALL / DETERMINISM FAILURE(S):", file=sys.stderr)
        for row_id, msg in run_failures:
            print(f"  {row_id}: {msg}", file=sys.stderr)
    print(f"wrote {out_dir}/c-l.jsonl, summary.json, summary.md, "
          f"disagreements.md, stderr.log")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
