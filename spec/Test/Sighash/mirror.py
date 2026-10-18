#!/usr/bin/env python3
"""Independent Python mirror of Bitcoin Core signature hashing.

This module is deliberately small and dependency-free.  It is used by
``crosscheck.py`` to re-derive the legacy and BIP143 digests embedded in
``SighashTest.lean`` from the raw transaction corpus.

The implementation follows the consensus serialization rules:
  * legacy ``SignatureHash``: scriptCode replaces the spent input's
    scriptSig, NONE/SINGLE output handling, ANYONECANPAY input selection;
  * BIP143: the three precomputed hashes, outpoint, scriptCode, amount,
    sequence, locktime, and hash type.

All hashes are double-SHA256.  Byte order follows the wire format: the
legacy ``sighash.json`` expectations are printed in reversed
``uint256`` order, while BIP143 expectations are printed in internal
order.  ``crosscheck.py`` handles that distinction.
"""

from __future__ import annotations

import hashlib
import struct

SIGHASH_ALL = 1
SIGHASH_NONE = 2
SIGHASH_SINGLE = 3
SIGHASH_ANYONECANPAY = 0x80

UINT256_ONE = b"\x01" + b"\x00" * 31


def hexb(value: str) -> bytes:
    return bytes.fromhex(value)


def sha256d(data: bytes) -> bytes:
    return hashlib.sha256(hashlib.sha256(data).digest()).digest()


def read_varint(data: bytes, pos: int) -> tuple[int, int]:
    first = data[pos]
    if first < 0xFD:
        return first, pos + 1
    if first == 0xFD:
        return int.from_bytes(data[pos + 1:pos + 3], "little"), pos + 3
    if first == 0xFE:
        return int.from_bytes(data[pos + 1:pos + 5], "little"), pos + 5
    return int.from_bytes(data[pos + 1:pos + 9], "little"), pos + 9


def compact_size(n: int) -> bytes:
    if n < 0xFD:
        return bytes([n])
    if n <= 0xFFFF:
        return b"\xfd" + struct.pack("<H", n)
    if n <= 0xFFFFFFFF:
        return b"\xfe" + struct.pack("<I", n)
    return b"\xff" + struct.pack("<Q", n)


def varbytes(data: bytes) -> bytes:
    return compact_size(len(data)) + data


def decode_tx(raw: bytes):
    """Decode a transaction into ``(version, vin, vout, locktime)``.

    ``vin`` entries are ``(prevout_hash, index, script_sig, sequence)``;
    ``vout`` entries are ``(value, script_pubkey)``.  SegWit witness data
    is skipped because neither legacy nor BIP143 hashing commits to it.
    """
    pos = 0
    version = struct.unpack_from("<i", raw, pos)[0]
    pos += 4

    segwit = raw[pos:pos + 2] == b"\x00\x01"
    if segwit:
        pos += 2

    n_in, pos = read_varint(raw, pos)
    vin = []
    for _ in range(n_in):
        prevout = raw[pos:pos + 32]
        pos += 32
        index = struct.unpack_from("<I", raw, pos)[0]
        pos += 4
        script_len, pos = read_varint(raw, pos)
        script_sig = raw[pos:pos + script_len]
        pos += script_len
        sequence = struct.unpack_from("<I", raw, pos)[0]
        pos += 4
        vin.append((prevout, index, script_sig, sequence))

    n_out, pos = read_varint(raw, pos)
    vout = []
    for _ in range(n_out):
        value = struct.unpack_from("<Q", raw, pos)[0]
        pos += 8
        script_len, pos = read_varint(raw, pos)
        script_pubkey = raw[pos:pos + script_len]
        pos += script_len
        vout.append((value, script_pubkey))

    if segwit:
        for _ in range(n_in):
            n_items, pos = read_varint(raw, pos)
            for _ in range(n_items):
                item_len, pos = read_varint(raw, pos)
                pos += item_len

    locktime = struct.unpack_from("<I", raw, pos)[0]
    pos += 4
    if pos != len(raw):
        raise ValueError(f"trailing transaction bytes: {pos} != {len(raw)}")
    return version, vin, vout, locktime



def find_and_delete_codeseparator(script: bytes) -> bytes:
    """Remove OP_CODESEPARATOR opcodes, preserving push payloads.

    Bitcoin Core applies ``FindAndDelete(scriptCode, CScript([OP_CODESEPARATOR]))``
    before legacy signature hashing.  A byte-wise replace would incorrectly
    remove ``0xab`` bytes that occur inside a push, so walk the opcode stream.
    """
    out = bytearray()
    pos = 0
    while pos < len(script):
        start = pos
        opcode = script[pos]
        pos += 1
        if opcode <= 0x4B:
            size = opcode
        elif opcode == 0x4C:
            size = script[pos]
            pos += 1
        elif opcode == 0x4D:
            size = int.from_bytes(script[pos:pos + 2], "little")
            pos += 2
        elif opcode == 0x4E:
            size = int.from_bytes(script[pos:pos + 4], "little")
            pos += 4
        else:
            size = 0
        pos += size
        if opcode != 0xAB:
            out += script[start:pos]
    return bytes(out)


def _serialize_inputs(vin, in_pos: int, script_code: bytes, anyone_can_pay: bool,
                      zero_other_sequences: bool = False):
    selected = [in_pos] if anyone_can_pay else range(len(vin))
    out = bytearray()
    for i in selected:
        prevout, index, _, sequence = vin[i]
        out += prevout
        out += struct.pack("<I", index)
        out += varbytes(script_code if i == in_pos else b"")
        out += struct.pack("<I", 0 if zero_other_sequences and i != in_pos else sequence)
    return bytes(out)


def legacy_sighash(version: int, vin, vout, locktime: int, in_pos: int,
                   script_code: bytes, hash_type: int) -> bytes:
    """Return the 32-byte internal-order legacy signature hash."""
    hash_type &= 0xFFFFFFFF
    base = hash_type & 0x1F
    anyone_can_pay = bool(hash_type & SIGHASH_ANYONECANPAY)

    if base == SIGHASH_SINGLE and in_pos >= len(vout):
        return UINT256_ONE

    script_code = find_and_delete_codeseparator(script_code)
    inputs = _serialize_inputs(vin, in_pos, script_code, anyone_can_pay,
                               zero_other_sequences=base in (SIGHASH_NONE, SIGHASH_SINGLE))

    if base == SIGHASH_NONE:
        outputs = b""
    elif base == SIGHASH_SINGLE:
        selected = [(0xFFFFFFFFFFFFFFFF, b"") for _ in range(in_pos)]
        selected.append(vout[in_pos])
        outputs = b"".join(struct.pack("<Q", value) + varbytes(script)
                           for value, script in selected)
    else:
        outputs = b"".join(struct.pack("<Q", value) + varbytes(script)
                           for value, script in vout)

    preimage = (
        struct.pack("<i", version)
        + compact_size(len(vin) if not anyone_can_pay else 1)
        + inputs
        + compact_size(len(vout) if base not in (SIGHASH_NONE, SIGHASH_SINGLE) else (0 if base == SIGHASH_NONE else in_pos + 1))
        + outputs
        + struct.pack("<I", locktime)
        + struct.pack("<I", hash_type)
    )
    return sha256d(preimage)


def bip143_sighash(version: int, vin, vout, locktime: int, in_pos: int,
                   script_code: bytes, amount: int, hash_type: int) -> bytes:
    """Return the 32-byte BIP143 signature hash."""
    hash_type &= 0xFFFFFFFF
    base = hash_type & 0x1F
    anyone_can_pay = bool(hash_type & SIGHASH_ANYONECANPAY)

    if anyone_can_pay:
        hash_prevouts = b"\x00" * 32
    else:
        hash_prevouts = sha256d(b"".join(
            prevout + struct.pack("<I", index)
            for prevout, index, _, _ in vin
        ))

    if anyone_can_pay or base in (SIGHASH_SINGLE, SIGHASH_NONE):
        hash_sequence = b"\x00" * 32
    else:
        hash_sequence = sha256d(b"".join(
            struct.pack("<I", sequence) for _, _, _, sequence in vin
        ))

    if base == SIGHASH_SINGLE and in_pos < len(vout):
        value, script = vout[in_pos]
        hash_outputs = sha256d(struct.pack("<Q", value) + varbytes(script))
    elif base in (SIGHASH_SINGLE, SIGHASH_NONE):
        hash_outputs = b"\x00" * 32
    else:
        hash_outputs = sha256d(b"".join(
            struct.pack("<Q", value) + varbytes(script)
            for value, script in vout
        ))

    prevout, index, _, sequence = vin[in_pos]
    preimage = (
        struct.pack("<i", version)
        + hash_prevouts
        + hash_sequence
        + prevout
        + struct.pack("<I", index)
        + varbytes(script_code)
        + struct.pack("<Q", amount)
        + struct.pack("<I", sequence)
        + hash_outputs
        + struct.pack("<I", locktime)
        + struct.pack("<I", hash_type)
    )
    return sha256d(preimage)
