#!/usr/bin/env python3
"""Behavioral differential driver: Core shim (C) vs rbitcoin adapter (R).

NOT a proof and NOT a cell. It loads the two real shared libraries through the
ABI v2 symbol and compares `(result, error_kind)` on a corpus of small tapes.

  C = /tmp/opencode/cbuild/libequiv-core.so   (pinned Core, behavioral build)
  R = libequiv-rust-r3.so                     (adapter/entry_r3.rs)

Usage:
  python3 diff_driver.py --core-so ... --rust-so ... [--verbose]

Exit 0 always unless --strict is passed. `--strict` fails if any case in the
`core` category disagrees. `domain` cases are expected to disagree by design
(the adapter returns 2 for a bit rbitcoin cannot express); `external` cases are
known engine divergences recorded as findings, not gate failures.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import struct
import sys
from dataclasses import dataclass, field
from pathlib import Path

RESULT_FAIL, RESULT_PASS, RESULT_BAD_INPUT, RESULT_INTERNAL = 0, 1, 2, 3
E_OK, E_UNKNOWN, E_EVAL_FALSE, E_OP_RETURN = 0, 1, 2, 3

P2SH = 0x000001
STRICTENC = 0x000002
DERSIG = 0x000004
LOW_S = 0x000008
NULLDUMMY = 0x000010
SIGPUSHONLY = 0x000020
MINIMALDATA = 0x000040
DISCOURAGE_NOPS = 0x000080
CLEANSTACK = 0x000100
CLTV = 0x000200
CSV = 0x000400
WITNESS = 0x000800
DISC_UPGR_WITNESS = 0x001000
MINIMALIF = 0x002000
NULLFAIL = 0x004000
WITNESS_PUBKEYTYPE = 0x008000
CONST_SCRIPTCODE = 0x010000
TAPROOT = 0x020000
DISC_UPGR_TAPROOT = 0x040000
DISC_OP_SUCCESS = 0x080000
DISC_UPGR_PUBKEY = 0x100000
MAX_MONEY = 2_100_000_000_000_000


def varint(n: int) -> bytes:
    if n < 0xFD:
        return bytes([n])
    if n <= 0xFFFF:
        return b"\xfd" + struct.pack("<H", n)
    if n <= 0xFFFFFFFF:
        return b"\xfe" + struct.pack("<I", n)
    return b"\xff" + struct.pack("<Q", n)


def push(data: bytes) -> bytes:
    n = len(data)
    if n < 0x4C:
        return bytes([n]) + data
    if n <= 0xFF:
        return b"\x4c" + bytes([n]) + data
    return b"\x4d" + struct.pack("<H", n) + data


def push_scriptnum(n: int) -> bytes:
    if n == 0:
        return b"\x00"
    if n == -1:
        return b"\x4f"
    if 1 <= n <= 16:
        return bytes([0x50 + n])
    neg = n < 0
    n = abs(n)
    out = bytearray()
    while n:
        out.append(n & 0xFF)
        n >>= 8
    if out[-1] & 0x80:
        out.append(0x80 if neg else 0x00)
    elif neg:
        out[-1] |= 0x80
    return push(bytes(out))


def tx_legacy(script_sigs: list[bytes], outputs: list[tuple[int, bytes]] | None = None,
              sequences: list[int] | None = None, locktime: int = 0) -> bytes:
    if outputs is None:
        outputs = [(0, b"")]
    if sequences is None:
        sequences = [0xFFFFFFFF] * len(script_sigs)
    out = struct.pack("<i", 2) + varint(len(script_sigs))
    for ss, seq in zip(script_sigs, sequences):
        out += b"\x00" * 32 + struct.pack("<I", 0xFFFFFFFF)
        out += varint(len(ss)) + ss
        out += struct.pack("<I", seq)
    out += varint(len(outputs))
    for value, spk in outputs:
        out += struct.pack("<q", value) + varint(len(spk)) + spk
    out += struct.pack("<I", locktime)
    return out


def tx_witness(script_sig: bytes, witness: list[bytes],
               outputs: list[tuple[int, bytes]] | None = None) -> bytes:
    if outputs is None:
        outputs = [(0, b"")]
    out = struct.pack("<i", 2) + b"\x00\x01" + varint(1)
    out += b"\x00" * 32 + struct.pack("<I", 0xFFFFFFFF)
    out += varint(len(script_sig)) + script_sig
    out += struct.pack("<I", 0xFFFFFFFF)
    out += varint(len(outputs))
    for value, spk in outputs:
        out += struct.pack("<q", value) + varint(len(spk)) + spk
    out += varint(len(witness))
    for item in witness:
        out += varint(len(item)) + item
    out += struct.pack("<I", 0)
    return out


def tx_witness_multi(script_sigs: list[bytes], witnesses: list[list[bytes]],
                     outputs: list[tuple[int, bytes]] | None = None,
                     sequences: list[int] | None = None, locktime: int = 0) -> bytes:
    if outputs is None:
        outputs = [(0, b"")]
    if sequences is None:
        sequences = [0xFFFFFFFF] * len(script_sigs)
    out = struct.pack("<i", 2) + b"\x00\x01" + varint(len(script_sigs))
    for ss, seq in zip(script_sigs, sequences):
        out += b"\x00" * 32 + struct.pack("<I", 0xFFFFFFFF)
        out += varint(len(ss)) + ss
        out += struct.pack("<I", seq)
    out += varint(len(outputs))
    for value, spk in outputs:
        out += struct.pack("<q", value) + varint(len(spk)) + spk
    for wit in witnesses:
        out += varint(len(wit))
        for item in wit:
            out += varint(len(item)) + item
    out += struct.pack("<I", locktime)
    return out


def hash160(b: bytes) -> bytes:
    return hashlib.new("ripemd160", hashlib.sha256(b).digest()).digest()


def sha256(b: bytes) -> bytes:
    return hashlib.sha256(b).digest()


def p2pkh_spk(h: bytes) -> bytes:
    return b"\x76\xa9\x14" + h + b"\x88\xac"


def p2wpkh_spk(h: bytes) -> bytes:
    return b"\x00\x14" + h


def p2wsh_spk(h: bytes) -> bytes:
    return b"\x00\x20" + h


def p2sh_spk(h: bytes) -> bytes:
    return b"\xa9\x14" + h + b"\x87"


def p2tr_spk(key: bytes) -> bytes:
    return b"\x51\x20" + key


def der_sig(hashtype: int = 1, r: bytes = b"\x01" * 32, s: bytes = b"\x01" * 32) -> bytes:
    body = b"\x02" + bytes([len(r)]) + r + b"\x02" + bytes([len(s)]) + s
    return b"\x30" + bytes([len(body)]) + body + bytes([hashtype])


@dataclass
class Case:
    name: str
    tx: bytes
    spk: bytes
    amount: int
    index: int
    flags: int
    category: str = "core"  # core | domain | external
    want_c: tuple[int, int] | None = None
    note: str = ""


def cases() -> list[Case]:
    one = tx_legacy([b""])
    two = tx_legacy([b"", b"\x6a"])  # input 1 scriptSig = OP_RETURN
    two_bad0 = tx_legacy([b"\x00", b"\x6a"])
    pkh = hash160(b"\x02" + b"\x11" * 32)
    uncomp = b"\x04" + b"\x22" * 64
    badder = b"\x30\x00\x01"

    # P2SH / witness helpers
    redeem_v0_20 = b"\x00\x14" + b"\x33" * 20
    redeem_v1 = b"\x51\x20" + b"\x02" + b"\x11" * 31
    redeem_v0_32 = b"\x00\x20" + b"\x44" * 32
    p2sh_v0_20 = p2sh_spk(hash160(redeem_v0_20))
    p2sh_v0_32 = p2sh_spk(hash160(redeem_v0_32))
    wscript = b"\x51"

    # DER-valid high-S: S = 0x7fff..ff > n/2, first byte < 0x80.
    high_s = b"\x7f" + b"\xff" * 31
    sig_der = der_sig()
    key = b"\x02" + b"\x11" * 32

    return [
        # ---- E0 tapes -----------------------------------------------------
        Case("E0 OP_1 pass", one, b"\x51", 0, 0, 0, want_c=(1, 0)),
        Case("E0 OP_0 fail", one, b"\x00", 0, 0, 0, want_c=(0, 2)),
        Case("E0 OP_RETURN", one, b"\x6a", 0, 0, 0, want_c=(0, 3)),
        Case("E0 empty tx", b"", b"\x51", 0, 0, 0, want_c=(2, 1)),

        # ---- script-level errors -----------------------------------------
        Case("OP_VERIFY empty", one, b"\x69", 0, 0, 0, want_c=(0, 18)),
        Case("OP_1 OP_VERIFY empties stack", one, b"\x51\x69", 0, 0, 0,
             want_c=(0, 2)),
        Case("OP_0 OP_VERIFY", one, b"\x00\x69", 0, 0, 0, want_c=(0, 11)),
        Case("EQUALVERIFY", one, b"\x51\x52\x88", 0, 0, 0, want_c=(0, 12)),
        Case("NUMEQUALVERIFY", one, b"\x51\x52\x9d", 0, 0, 0, want_c=(0, 15)),
        Case("unbalanced IF", one, b"\x51\x63", 0, 0, 0, want_c=(0, 20)),
        Case("ELSE alone", one, b"\x67", 0, 0, 0, want_c=(0, 20)),
        Case("ENDIF alone", one, b"\x68", 0, 0, 0, want_c=(0, 20)),
        Case("disabled CAT", one, b"\x7e", 0, 0, 0, want_c=(0, 17)),
        Case("unknown 0xba", one, b"\xba", 0, 0, 0, want_c=(0, 16)),
        Case("OP_VERIF", one, b"\x65", 0, 0, 0, want_c=(0, 16)),
        Case("FROMALTSTACK empty", one, b"\x6c", 0, 0, 0, want_c=(0, 19)),
        Case("PICK out of range", one, b"\x51\x79", 0, 0, 0, want_c=(0, 18)),
        Case("script > 10000", one, b"\x51" * 10001, 0, 0, 0, want_c=(0, 5)),
        Case("push > 520", one, b"\x4d\x09\x02" + b"\xaa" * 521, 0, 0, 0,
             want_c=(0, 6)),
        Case("MINIMALDATA", one, b"\x4c\x01\x07", 0, 0, MINIMALDATA, want_c=(0, 25)),
        Case("CLEANSTACK", one, b"\x51\x51", 0, 0, P2SH | WITNESS | CLEANSTACK,
             want_c=(0, 30)),
        Case("CONST_SCRIPTCODE", one, b"\xab\x51", 0, 0, CONST_SCRIPTCODE,
             want_c=(0, 53)),

        # ---- locktime -----------------------------------------------------
        Case("CLTV negative", one, b"\x4f\xb1", 0, 0, CLTV, want_c=(0, 21)),
        Case("CLTV unsatisfied", one, b"\x51\xb1", 0, 0, CLTV, want_c=(0, 22)),
        Case("CSV negative", one, b"\x4f\xb2", 0, 0, CSV, want_c=(0, 21)),
        Case("CSV unsatisfied", one, b"\x51\xb2", 0, 0, CSV, want_c=(0, 22)),

        # ---- P2PKH fast path ---------------------------------------------
        Case("p2pkh hash mismatch", tx_legacy([push(b"\x30") + push(key)]),
             p2pkh_spk(b"\x00" * 20), 0, 0, 0, want_c=(0, 12)),
        Case("p2pkh empty sig", tx_legacy([push(b"") + push(key)]),
             p2pkh_spk(hash160(key)), 0, 0, 0, want_c=(0, 2)),
        Case("p2pkh bad pubkey", tx_legacy([push(der_sig()) + push(b"\x05" + b"\x11" * 32)]),
             p2pkh_spk(hash160(b"\x05" + b"\x11" * 32)), 0, 0, 0, want_c=(0, 2)),
        Case("p2pkh bad DER no DERSIG", tx_legacy([push(badder) + push(key)]),
             p2pkh_spk(hash160(key)), 0, 0, 0, want_c=(0, 2)),
        Case("p2pkh bad DER DERSIG", tx_legacy([push(badder) + push(key)]),
             p2pkh_spk(hash160(key)), 0, 0, DERSIG, want_c=(0, 24)),
        Case("p2pkh STRICTENC pubkey",
             tx_legacy([push(der_sig()) + push(b"\x05" + b"\x11" * 32)]),
             p2pkh_spk(hash160(b"\x05" + b"\x11" * 32)), 0, 0, STRICTENC,
             want_c=(0, 29)),
        Case("p2pkh STRICTENC hashtype",
             tx_legacy([push(der_sig(0x04)) + push(key)]),
             p2pkh_spk(hash160(key)), 0, 0, STRICTENC, want_c=(0, 23)),
        Case("p2pkh LOW_S high S",
             tx_legacy([push(der_sig(1, b"\x01" * 32, high_s)) + push(key)]),
             p2pkh_spk(hash160(key)), 0, 0, LOW_S, want_c=(0, 27)),
        Case("p2pkh DERSIG+LOW_S high S",
             tx_legacy([push(der_sig(1, b"\x01" * 32, high_s)) + push(key)]),
             p2pkh_spk(hash160(key)), 0, 0, DERSIG | LOW_S, want_c=(0, 27)),

        # ---- P2SH ---------------------------------------------------------
        Case("p2sh empty scriptSig", one, p2sh_v0_20, 0, 0, P2SH, want_c=(0, 18)),
        Case("p2sh redeem hash mismatch",
             tx_legacy([push(b"\x33" * 20)]), p2sh_spk(b"\x00" * 20), 0, 0, P2SH,
             want_c=(0, 2)),
        Case("p2sh non-push scriptSig",
             tx_legacy([push(redeem_v0_20) + b"\x76"]), p2sh_v0_20, 0, 0, P2SH,
             want_c=(0, 26)),
        Case("p2sh non-push + hash mismatch",
             tx_legacy([b"\x51\x76"]), p2sh_v0_20, 0, 0, P2SH,
             category="external",
             note="Core evals spk (EQUAL false=>2) before the push-only check; "
                  "rbitcoin checks push-only first (26)"),
        Case("p2sh witness malleated",
             tx_legacy([push(b"\xaa") + push(redeem_v0_20)]), p2sh_v0_20, 0, 0,
             P2SH | WITNESS, want_c=(0, 42)),
        Case("p2sh empty scriptSig v0/32", one, p2sh_v0_32, 0, 0, P2SH,
             want_c=(0, 18)),

        # ---- witness v0 ---------------------------------------------------
        Case("p2wpkh wrong witness len", tx_witness(b"", [b"\x01"]),
             p2wpkh_spk(pkh), 0, 0, P2SH | WITNESS, want_c=(0, 40)),
        Case("p2wpkh pubkey hash mismatch",
             tx_witness(b"", [der_sig(), key]), p2wpkh_spk(b"\x11" * 20),
             0, 0, P2SH | WITNESS, want_c=(0, 12)),
        Case("p2wpkh empty sig item",
             tx_witness(b"", [b"", key]), p2wpkh_spk(hash160(key)), 0, 0,
             P2SH | WITNESS, category="external",
             note="same engine token as the empty-pubkey case; Core gives 2 here"),
        Case("p2wpkh WITNESS_PUBKEYTYPE",
             tx_witness(b"", [der_sig(), uncomp]), p2wpkh_spk(hash160(uncomp)), 0, 0,
             P2SH | WITNESS | WITNESS_PUBKEYTYPE, want_c=(0, 44)),
        Case("p2wsh empty witness (2-input tx)",
             tx_witness_multi([b"", b""], [[], [b"\x01"]]),
             p2wsh_spk(b"\x11" * 32), 0, 0, P2SH | WITNESS, want_c=(0, 39)),
        Case("p2wsh script hash mismatch", tx_witness(b"", [b"\x51"]),
             p2wsh_spk(b"\x11" * 32), 0, 0, P2SH | WITNESS, want_c=(0, 40)),
        Case("p2wsh OP_0", tx_witness(b"", [b"\x00"]),
             p2wsh_spk(sha256(b"\x00")), 0, 0, P2SH | WITNESS, want_c=(0, 2)),
        Case("p2wsh cleanstack", tx_witness(b"", [wscript, wscript]),
             p2wsh_spk(sha256(wscript)), 0, 0, P2SH | WITNESS, want_c=(0, 30)),
        Case("p2wsh MINIMALIF", tx_witness(b"", [b"\x02", b"\x63\x51\x68"]),
             p2wsh_spk(sha256(b"\x63\x51\x68")), 0, 0,
             P2SH | WITNESS | MINIMALIF, want_c=(0, 31)),
        Case("witness unexpected",
             tx_witness(b"", [b"\x01"]), b"\x51", 0, 0, P2SH | WITNESS,
             want_c=(0, 43)),
        Case("witness program wrong length",
             tx_witness(b"", [b"\x01"]), b"\x00\x02\xaa\xbb", 0, 0,
             P2SH | WITNESS, want_c=(0, 38)),
        Case("discourage upgradeable witness program",
             tx_witness(b"", [b"\x01"]), b"\x52\x02\xaa\xbb", 0, 0,
             P2SH | WITNESS | DISC_UPGR_WITNESS, want_c=(0, 34)),
        Case("malleated native witness",
             tx_witness(b"\x51", [b"\x01"]), p2wsh_spk(b"\x11" * 32), 0, 0,
             P2SH | WITNESS, want_c=(0, 41)),
        Case("malleated + false program",
             tx_witness(b"\x51", [b"\x01"]), p2wsh_spk(b"\x00" * 32), 0, 0,
             P2SH | WITNESS, category="external",
             note="Core evals spk first (false program=>2); rbitcoin checks "
                  "scriptSig emptiness first (41)"),

        # ---- CHECKMULTISIG / CHECKSIG -------------------------------------
        Case("cms null dummy", one, b"\x51\x00\x00\xae", 0, 0, NULLDUMMY,
             want_c=(0, 28)),
        Case("cms underflow", one, b"\xae", 0, 0, 0, want_c=(0, 18)),
        Case("cms nkeys too big", one, b"\x00\x00\x01\x15\xae", 0, 0, 0,
             want_c=(0, 10)),
        Case("cms nsigs > nkeys", one, b"\x00\x00\x00\x52\x51\x51\xae", 0, 0, 0,
             want_c=(0, 9)),
        Case("cms nullfail", one,
             b"\x00" + push(sig_der) + b"\x51" + push(key) + b"\x51\xae", 0, 0,
             NULLFAIL, want_c=(0, 32)),
        Case("cms 1of1 invalid no nullfail", one,
             b"\x00" + push(sig_der) + b"\x51" + push(key) + b"\x51\xae", 0, 0,
             0, want_c=(0, 2)),
        Case("checksigverify false", one, b"\x00\x00\xad", 0, 0, 0, want_c=(0, 14)),
        Case("checksigverify empty sig", one, b"\x00\x51\xad", 0, 0, 0,
             want_c=(0, 14)),

        # ---- taproot key path (single input) -----------------------------
        Case("p2tr empty key sig", tx_witness(b"", [b""]),
             p2tr_spk(b"\x02" + b"\x11" * 31), 0, 0,
             P2SH | WITNESS | TAPROOT, want_c=(0, 45)),
        Case("p2tr empty witness encoding", tx_witness(b"", []),
             p2tr_spk(b"\x02" + b"\x11" * 31), 0, 0,
             P2SH | WITNESS | TAPROOT, want_c=(2, 1),
             note="segwit flag set but no witness bytes: both parsers reject"),

        # ---- multi-input (input 0 target) --------------------------------
        Case("multi input0 pass, input1 invalid", two, b"\x51", 0, 0, 0,
             want_c=(1, 0), note="input 1 scriptSig is OP_RETURN"),
        Case("multi input0 fail", two_bad0, b"\x00", 0, 0, 0, want_c=(0, 2)),
        Case("multi input0 p2wsh pass, input1 invalid",
             tx_witness_multi([b"", b"\x6a"], [[b"\x51"], []]),
             p2wsh_spk(sha256(b"\x51")), 0, 0, P2SH | WITNESS,
             want_c=(1, 0), note="BIP143 input 0 exact; vin=1 failure discarded"),
        Case("multi index1", tx_legacy([b"", b""]), b"\x51", 0, 1, 0,
             category="domain", note="public entry cannot skip input 0"),
        Case("multi input0 taproot", tx_legacy([b"", b""]),
             p2tr_spk(b"\x02" + b"\x11" * 31), 0, 0, P2SH | WITNESS | TAPROOT,
             category="domain", note="BIP341 hashes all spent outputs"),
        Case("multi input0 p2sh-v1 ACS (not taproot)",
             tx_witness_multi([push(redeem_v1), b""], [[b"\x01" * 64], []]),
             p2sh_spk(hash160(redeem_v1)), 0, 0,
             P2SH | WITNESS | TAPROOT, want_c=(1, 0),
             note="Core excludes is_p2sh v1 from BIP341: unknown program => success"),

        # ---- domain / contract edges -------------------------------------
        Case("flags bit 5 SIGPUSHONLY", one, b"\x51", 0, 0, SIGPUSHONLY,
             category="domain"),
        Case("flags bit 7 DISCOURAGE_NOPS", one, b"\x51\xb0", 0, 0, DISCOURAGE_NOPS,
             category="domain"),
        Case("flags bit 18 DISC_UPGR_TAPROOT", one, b"\x51", 0, 0,
             DISC_UPGR_TAPROOT, category="domain"),
        Case("flags bit 19 DISC_OP_SUCCESS", one, b"\x51", 0, 0,
             DISC_OP_SUCCESS, category="domain"),
        Case("flags bit 20 DISC_UPGR_PUBKEY", one, b"\x51", 0, 0,
             DISC_UPGR_PUBKEY, category="domain"),
        Case("flags unknown high bit", one, b"\x51", 0, 0, 1 << 40,
             category="domain", want_c=(2, 1)),
        Case("WITNESS without P2SH", one, b"\x51", 0, 0, WITNESS,
             category="domain", want_c=(2, 1)),
        Case("CLEANSTACK without WITNESS", one, b"\x51", 0, 0, P2SH | CLEANSTACK,
             category="domain", want_c=(2, 1)),
        Case("amount > MAX_MONEY", one, b"\x51", MAX_MONEY + 1, 0, 0,
             want_c=(2, 1)),
        Case("amount negative", one, b"\x51", -1, 0, 0, want_c=(2, 1)),
        Case("spk > 10000 bytes", one, b"\x51" * 10001, 0, 0, 0, want_c=(0, 5)),
        Case("trailing tx byte", one + b"\x00", b"\x51", 0, 0, 0, want_c=(2, 1)),
        Case("input index out of range", one, b"\x51", 0, 5, 0, want_c=(2, 1)),

        # ---- known engine divergences (recorded, not gate) ---------------
        Case("p2wpkh empty pubkey item, hash match",
             tx_witness(b"", [b"\x30", b""]), p2wpkh_spk(hash160(b"")), 0, 0,
             P2SH | WITNESS, category="external",
             note="rbitcoin early-errors (unmapped token); Core runs the implied "
                  "P2PKH script and reaches EVAL_FALSE (2)"),
        Case("p2wpkh empty pubkey item, hash mismatch",
             tx_witness(b"", [der_sig(), b""]), p2wpkh_spk(b"\x11" * 20), 0, 0,
             P2SH | WITNESS, category="external",
             note="same rbitcoin token, but Core returns EQUALVERIFY (12): the "
                  "token cannot be mapped faithfully without hashing the pubkey"),
    ]


def load(path: Path):
    lib = ctypes.CDLL(str(path))
    fn = lib.equiv_entry
    fn.restype = ctypes.c_int
    fn.argtypes = [
        ctypes.POINTER(ctypes.c_uint8), ctypes.c_uint64,
        ctypes.POINTER(ctypes.c_uint8), ctypes.c_uint64,
        ctypes.c_int64, ctypes.c_uint32, ctypes.c_uint64,
        ctypes.POINTER(ctypes.c_int32),
    ]
    return fn


def call(fn, case: Case) -> tuple[int, int]:
    tb = (ctypes.c_uint8 * len(case.tx)).from_buffer_copy(case.tx) if case.tx else None
    sb = (ctypes.c_uint8 * len(case.spk)).from_buffer_copy(case.spk) if case.spk else None
    kind = ctypes.c_int32(E_UNKNOWN)
    rc = fn(tb, len(case.tx), sb, len(case.spk), case.amount, case.index, case.flags,
            ctypes.byref(kind))
    return rc, kind.value


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--core-so", default="/tmp/opencode/cbuild/libequiv-core.so")
    ap.add_argument("--rust-so",
                    default="/tmp/opencode/wave16b-scratch/08-r-harness/libequiv-rust-r3.so")
    ap.add_argument("--strict", action="store_true")
    args = ap.parse_args()

    cf, rf = load(Path(args.core_so)), load(Path(args.rust_so))
    counts = {"core": [0, 0], "domain": [0, 0], "external": [0, 0]}
    failures = []
    print(f"{'case':42s} {'C':>8s} {'R':>8s} {'wantC':>8s}  verdict")
    for c in cases():
        cgot = call(cf, c)
        rgot = call(rf, c)
        agree = cgot == rgot
        cok = c.want_c is None or cgot == c.want_c
        counts[c.category][0] += 1
        if agree and cok:
            counts[c.category][1] += 1
            verdict = "match"
        else:
            verdict = f"MISMATCH{'/C!=want' if not cok else ''}"
            failures.append((c, cgot, rgot))
        print(f"{c.name:42s} {str(cgot):>8s} {str(rgot):>8s} "
              f"{str(c.want_c):>8s}  {verdict}"
              + (f"  [{c.note}]" if c.note and verdict != "match" else ""))

    print("\nsummary (agree & C matches want, per category):")
    for k, (n, ok) in counts.items():
        print(f"  {k:9s} {ok}/{n}")
    if failures:
        print("\nnon-matching cases:")
        for c, cgot, rgot in failures:
            print(f"  - {c.name}: C={cgot} R={rgot} wantC={c.want_c} "
                  f"[{c.category}] {c.note}")
    core_bad = [(c, cg, rg) for c, cg, rg in failures if c.category == "core"]
    print(f"\ncore-category mismatches: {len(core_bad)}")
    if args.strict and (core_bad or any(c.want_c and call(cf, c) != c.want_c
                                        for c in cases())):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
