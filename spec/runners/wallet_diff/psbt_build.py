"""Deterministic PSBT v0 edge-case builder for the wallet error corpus.

The module is standard-library only and produces the candidate byte strings
that ``psbt_replay.py --emit`` submits to a pinned regtest bitcoind.  Nothing
here decides whether a PSBT is valid: validity, error text, and the decoded
field projection come from the live node.

Layout follows BIP 174: the five magic bytes, then global, input, and output
maps, each terminated by a zero byte.  Every entry is a CompactSize key
length, the key, a CompactSize value length, and the value.  Keys embed their
type as a CompactSize prefix, which is what Core calls ``<keytype><keydata>``.

Determinism comes from fixed previous transactions, fixed scripts, fixed
keys, and fixed signatures.  No clock, randomness, or wallet state is read.
The malformed cases use the same serializers with an explicit override on one
length or one field, or with a deliberate slice.
"""

from __future__ import annotations

import base64
import hashlib
import struct
from dataclasses import dataclass
from typing import Iterable, Sequence

MAGIC = bytes.fromhex("70736274ff")
SEPARATOR = b"\x00"

# Fixed data: never used on a public network.
PUBKEY = bytes.fromhex("0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
XONLY = bytes.fromhex("79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
DER_SIG = bytes.fromhex(
    "304402203609e17b84f6a7d30c80bfa610b5b4542f32a8a0d5447a12fb1366d7f01cc44a"
    "0220573a954c4518331561406f90300e8f3358f51928d43c212a8caed02de67eebee01"
)
TAP_SIG = b"\x00" * 64
UNKNOWN_GLOBAL_KEY = b"\x7f\x01"
UNKNOWN_INPUT_KEY = b"\x7f\xaa"
UNKNOWN_OUTPUT_KEY = b"\x7f\xbb"

H160_A = b"\x11" * 20
H160_B = b"\x22" * 20
H160_C = b"\x33" * 20
H160_D = b"\x44" * 20


# --------------------------------------------------------------------- encoding


def cs(value: int) -> bytes:
    """Canonical Bitcoin CompactSize."""
    if value < 0xFD:
        return bytes([value])
    if value <= 0xFFFF:
        return b"\xfd" + struct.pack("<H", value)
    if value <= 0xFFFFFFFF:
        return b"\xfe" + struct.pack("<I", value)
    if value <= 0xFFFFFFFFFFFFFFFF:
        return b"\xff" + struct.pack("<Q", value)
    raise ValueError("CompactSize out of range")


def varbytes(data: bytes) -> bytes:
    return cs(len(data)) + data


def txout(value: int, script: bytes) -> bytes:
    return struct.pack("<q", value) + varbytes(script)


def p2pkh(h160: bytes) -> bytes:
    return b"\x76\xa9\x14" + h160 + b"\x88\xac"


def p2sh(h160: bytes) -> bytes:
    return b"\xa9\x14" + h160 + b"\x87"


def p2wpkh(h160: bytes) -> bytes:
    return b"\x00\x14" + h160


def p2wsh(sha256: bytes) -> bytes:
    return b"\x00\x20" + sha256


def p2tr(xonly: bytes) -> bytes:
    return b"\x51\x20" + xonly


def push32(xonly: bytes) -> bytes:
    return b"\x20" + xonly


def serialize_tx(
    version: int,
    inputs: Sequence[dict],
    outputs: Sequence[dict],
    locktime: int = 0,
    witnesses: Sequence[Sequence[bytes]] | None = None,
) -> bytes:
    """Serialize a transaction; ``witnesses`` adds the BIP 144 witness section."""
    out = struct.pack("<i", version)
    out += cs(len(inputs))
    for txin in inputs:
        out += bytes(txin["prev_txid"])
        out += struct.pack("<I", txin["vout"])
        out += varbytes(txin.get("script_sig", b""))
        out += struct.pack("<I", txin.get("sequence", 0xFFFFFFFF))
    out += cs(len(outputs))
    for txo in outputs:
        out += txout(txo["value"], txo["script"])
    if witnesses is not None:
        for stack in witnesses:
            out += cs(len(stack))
            for item in stack:
                out += varbytes(item)
    out += struct.pack("<I", locktime)
    return out


def txid_internal(raw_tx: bytes) -> bytes:
    """Double SHA-256 in wire order (the outpoint byte order)."""
    return hashlib.sha256(hashlib.sha256(raw_tx).digest()).digest()


def txid_display(raw_tx: bytes) -> str:
    return txid_internal(raw_tx)[::-1].hex()


def make_prev_tx(tag: bytes, outputs: Sequence[tuple[int, bytes]]) -> bytes:
    """A fixed previous transaction whose txid can be spent by later cases."""
    prev_hash = hashlib.sha256(b"wallet-psbt-corpus-prev-" + tag).digest()
    txins = [{"prev_txid": prev_hash, "vout": 0, "script_sig": b"", "sequence": 0xFFFFFFFF}]
    txouts = [{"value": value, "script": script} for value, script in outputs]
    return serialize_tx(2, txins, txouts)


def spend_tx(
    prevs: Sequence[tuple[bytes, int]],
    outputs: Sequence[tuple[int, bytes]],
    version: int = 2,
    locktime: int = 0,
    script_sigs: Sequence[bytes] | None = None,
    witnesses: Sequence[Sequence[bytes]] | None = None,
) -> bytes:
    """Build an unsigned transaction from ``(previous_tx_bytes, vout)`` pairs."""
    txins = []
    for index, (prev_tx, vout) in enumerate(prevs):
        txins.append(
            {
                "prev_txid": txid_internal(prev_tx),
                "vout": vout,
                "script_sig": b"" if script_sigs is None else script_sigs[index],
                "sequence": 0xFFFFFFFD,
            }
        )
    txouts = [{"value": value, "script": script} for value, script in outputs]
    return serialize_tx(version, txins, txouts, locktime, witnesses)


# ------------------------------------------------------------------- PSBT pieces


def entry(key: bytes, value: bytes) -> bytes:
    return varbytes(key) + varbytes(value)


def raw_entry(
    key: bytes,
    value: bytes,
    key_len: bytes | None = None,
    value_len: bytes | None = None,
) -> bytes:
    """An entry with an optional non-canonical or wrong length prefix."""
    return (
        (cs(len(key)) if key_len is None else key_len)
        + key
        + (cs(len(value)) if value_len is None else value_len)
        + value
    )


def map_bytes(entries: Iterable[bytes], terminated: bool = True) -> bytes:
    body = b"".join(entries)
    return body + (SEPARATOR if terminated else b"")


def build(
    global_entries: Sequence[tuple[bytes, bytes]] | Sequence[bytes],
    input_maps: Sequence[Sequence[tuple[bytes, bytes]] | Sequence[bytes]],
    output_maps: Sequence[Sequence[tuple[bytes, bytes]] | Sequence[bytes]],
    magic: bytes = MAGIC,
    terminate_global: bool = True,
) -> bytes:
    def as_bytes(items):
        return [item if isinstance(item, bytes) else entry(*item) for item in items]

    out = magic + map_bytes(as_bytes(global_entries), terminate_global)
    for entries in input_maps:
        out += map_bytes(as_bytes(entries))
    for entries in output_maps:
        out += map_bytes(as_bytes(entries))
    return out


# Global key types (BIP 174 plus the current PSBTv2 extensions).
G_UNSIGNED_TX = b"\x00"
G_XPUB = b"\x01"
G_TX_VERSION = b"\x02"
G_FALLBACK_LOCKTIME = b"\x03"
G_INPUT_COUNT = b"\x04"
G_OUTPUT_COUNT = b"\x05"
G_TX_MODIFIABLE = b"\x06"
G_VERSION = b"\xfb"
G_PROPRIETARY = b"\xfc"

# Input key types.
I_NON_WITNESS_UTXO = b"\x00"
I_WITNESS_UTXO = b"\x01"
I_PARTIAL_SIG = b"\x02"
I_SIGHASH = b"\x03"
I_REDEEM_SCRIPT = b"\x04"
I_WITNESS_SCRIPT = b"\x05"
I_BIP32 = b"\x06"
I_FINAL_SCRIPTSIG = b"\x07"
I_FINAL_SCRIPTWITNESS = b"\x08"
I_TAP_KEY_SIG = b"\x13"
I_TAP_SCRIPT_SIG = b"\x14"
I_TAP_LEAF_SCRIPT = b"\x15"
I_TAP_INTERNAL_KEY = b"\x17"
I_TAP_MERKLE_ROOT = b"\x18"
I_PROPRIETARY = b"\xfc"

# Output key types.
O_REDEEM_SCRIPT = b"\x00"
O_WITNESS_SCRIPT = b"\x01"
O_BIP32 = b"\x02"
O_AMOUNT = b"\x03"
O_SCRIPT = b"\x04"
O_PROPRIETARY = b"\xfc"


def g_tx(raw_tx: bytes) -> tuple[bytes, bytes]:
    return G_UNSIGNED_TX, raw_tx


def g_version(version: int) -> tuple[bytes, bytes]:
    return G_VERSION, struct.pack("<I", version)


def g_tx_version(version: int) -> tuple[bytes, bytes]:
    return G_TX_VERSION, struct.pack("<I", version)


def g_count(key: bytes, count: int) -> tuple[bytes, bytes]:
    return key, cs(count)


def g_unknown(keydata: bytes = b"", value: bytes = b"x") -> tuple[bytes, bytes]:
    return UNKNOWN_GLOBAL_KEY + keydata, value


def g_proprietary(subtype: int = 1, payload: bytes = b"wallet-review") -> tuple[bytes, bytes]:
    return G_PROPRIETARY + varbytes(b"WALX") + cs(subtype), payload


def xpub_key() -> bytes:
    """A 79-byte G_XPUB key: type, version, depth, fingerprint, child, chaincode, pubkey."""
    version = b"\x04\x35\x87\xcf"  # tpub
    depth = b"\x00"
    fingerprint = b"\x00\x00\x00\x00"
    child = b"\x00\x00\x00\x00"
    chaincode = b"\x5a" * 32
    return G_XPUB + version + depth + fingerprint + child + chaincode + PUBKEY


def i_non_witness(raw_tx: bytes) -> tuple[bytes, bytes]:
    return I_NON_WITNESS_UTXO, raw_tx


def i_witness(raw_txout: bytes) -> tuple[bytes, bytes]:
    return I_WITNESS_UTXO, raw_txout


def i_partial_sig(signature: bytes = DER_SIG, pubkey: bytes = PUBKEY) -> tuple[bytes, bytes]:
    return I_PARTIAL_SIG + pubkey, signature


def i_sighash(value: int = 1) -> tuple[bytes, bytes]:
    return I_SIGHASH, struct.pack("<I", value)


def i_redeem(script: bytes) -> tuple[bytes, bytes]:
    return I_REDEEM_SCRIPT, script


def i_witness_script(script: bytes) -> tuple[bytes, bytes]:
    return I_WITNESS_SCRIPT, script


def i_bip32(path: Sequence[int] = (0x8000002C, 0x80000000)) -> tuple[bytes, bytes]:
    return I_BIP32 + PUBKEY, b"\xde\xad\xbe\xef" + b"".join(struct.pack("<I", p) for p in path)


def i_final_scriptsig(script: bytes) -> tuple[bytes, bytes]:
    return I_FINAL_SCRIPTSIG, script


def i_final_witness(stack: Sequence[bytes]) -> tuple[bytes, bytes]:
    return I_FINAL_SCRIPTWITNESS, cs(len(stack)) + b"".join(varbytes(item) for item in stack)


def i_unknown(keydata: bytes = b"", value: bytes = b"u") -> tuple[bytes, bytes]:
    return UNKNOWN_INPUT_KEY + keydata, value


def i_proprietary(subtype: int = 1, payload: bytes = b"in") -> tuple[bytes, bytes]:
    return I_PROPRIETARY + varbytes(b"WALX") + cs(subtype), payload


def o_unknown(keydata: bytes = b"", value: bytes = b"o") -> tuple[bytes, bytes]:
    return UNKNOWN_OUTPUT_KEY + keydata, value


def o_proprietary(subtype: int = 1, payload: bytes = b"out") -> tuple[bytes, bytes]:
    return O_PROPRIETARY + varbytes(b"WALX") + cs(subtype), payload


# ------------------------------------------------------------------ fixed graph

PKH_A = p2pkh(H160_A)
PKH_B = p2pkh(H160_B)
WPKH_B = p2wpkh(H160_B)
WPKH_C = p2wpkh(H160_C)
SH_C = p2sh(H160_C)
WSH_D = p2wsh(hashlib.sha256(b"\x51").digest())
TR_T = p2tr(XONLY)

PREV_A = make_prev_tx(b"a", [(100_000, PKH_A)])
PREV_B = make_prev_tx(b"b", [(200_000, WPKH_B)])
PREV_T = make_prev_tx(b"t", [(150_000, TR_T)])
PREV_MULTI = make_prev_tx(b"m", [(100_000, PKH_A), (200_000, WPKH_B)])

TX_A = spend_tx([(PREV_A, 0)], [(90_000, WPKH_C)])
TX_B = spend_tx([(PREV_B, 0)], [(190_000, WPKH_C)])
TX_T = spend_tx([(PREV_T, 0)], [(140_000, WPKH_C)])
TX_MULTI = spend_tx(
    [(PREV_MULTI, 0), (PREV_MULTI, 1)],
    [(120_000, WPKH_C), (170_000, PKH_A)],
)
TX_TWO_OUT = spend_tx([(PREV_A, 0)], [(40_000, WPKH_C), (50_000, PKH_B)])
TX_ZERO = serialize_tx(2, [], [])
TX_NO_OUT = spend_tx([(PREV_A, 0)], [])

UTXO_A = txout(100_000, PKH_A)
UTXO_B = txout(200_000, WPKH_B)
UTXO_T = txout(150_000, TR_T)


@dataclass(frozen=True)
class Case:
    case_id: str
    taxonomy: str
    note: str
    data: bytes | None = None
    b64: str | None = None

    def as_b64(self) -> str:
        if self.b64 is not None:
            return self.b64
        assert self.data is not None
        return base64.b64encode(self.data).decode("ascii")


def case(
    case_id: str,
    taxonomy: str,
    note: str,
    data: bytes | None = None,
    b64: str | None = None,
) -> Case:
    return Case(case_id=case_id, taxonomy=taxonomy, note=note, data=data, b64=b64)


def build_cases() -> list[Case]:
    """Return the ordered corpus candidates."""
    cases: list[Case] = []

    # ---------------------------------------------------------- valid v0 PSBTs
    cases += [
        case(
            "valid.v0.legacy.empty_maps",
            "valid/v0/legacy",
            "One P2PKH input and one P2WPKH output; both per-input/output maps empty.",
            build([g_tx(TX_A)], [[]], [[]]),
        ),
        case(
            "valid.v0.legacy.non_witness_utxo",
            "valid/v0/legacy",
            "Legacy input carries the full previous transaction as non_witness_utxo.",
            build([g_tx(TX_A)], [[i_non_witness(PREV_A)]], [[]]),
        ),
        case(
            "valid.v0.legacy.witness_utxo_only",
            "valid/v0/legacy",
            "Legacy input carries only witness_utxo; decoding accepts the field without a witness program.",
            build([g_tx(TX_A)], [[i_witness(UTXO_A)]], [[]]),
        ),
        case(
            "valid.v0.legacy.both_utxos",
            "valid/v0/legacy",
            "Legacy input carries both witness_utxo and non_witness_utxo with the same txout.",
            build([g_tx(TX_A)], [[i_non_witness(PREV_A), i_witness(UTXO_A)]], [[]]),
        ),
        case(
            "valid.v0.legacy.final_and_partial",
            "valid/v0/legacy",
            "final_scriptSig and partial_sigs coexist; decode does not enforce finalization exclusivity.",
            build(
                [g_tx(TX_A)],
                [[i_non_witness(PREV_A), i_partial_sig(), i_final_scriptsig(b"\x51")]],
                [[]],
            ),
        ),
        case(
            "valid.v0.segwit.witness_utxo",
            "valid/v0/segwit",
            "P2WPKH input with a witness_utxo.",
            build([g_tx(TX_B)], [[i_witness(UTXO_B)]], [[]]),
        ),
        case(
            "valid.v0.segwit.both_utxos",
            "valid/v0/segwit",
            "P2WPKH input with matching witness_utxo and non_witness_utxo.",
            build([g_tx(TX_B)], [[i_non_witness(PREV_B), i_witness(UTXO_B)]], [[]]),
        ),
        case(
            "valid.v0.segwit.final_fields",
            "valid/v0/segwit",
            "P2WPKH input has final_scriptSig and final_scriptwitness.",
            build(
                [g_tx(TX_B)],
                [[i_witness(UTXO_B), i_final_scriptsig(b"\x51"), i_final_witness([DER_SIG, PUBKEY])]],
                [[]],
            ),
        ),
        case(
            "valid.v0.segwit.partial_sig",
            "valid/v0/segwit",
            "P2WPKH input has one valid DER-encoded partial signature.",
            build([g_tx(TX_B)], [[i_witness(UTXO_B), i_partial_sig()]], [[]]),
        ),
        case(
            "valid.v0.segwit.scripts_and_paths",
            "valid/v0/segwit",
            "P2WPKH input carries redeem_script, witness_script, sighash, and a BIP32 path.",
            build(
                [g_tx(TX_B)],
                [[i_witness(UTXO_B), i_redeem(b"\x00\x14" + H160_D), i_witness_script(b"\x51"), i_sighash(), i_bip32()]],
                [[]],
            ),
        ),
        case(
            "valid.v0.taproot.witness_utxo",
            "valid/v0/taproot",
            "P2TR input with a witness_utxo; no taproot signing fields.",
            build([g_tx(TX_T)], [[i_witness(UTXO_T)]], [[]]),
        ),
        case(
            "valid.v0.taproot.key_path_fields",
            "valid/v0/taproot",
            "P2TR input with a 64-byte taproot key-path signature, internal key, and merkle root.",
            build(
                [g_tx(TX_T)],
                [[i_witness(UTXO_T), (I_TAP_KEY_SIG, TAP_SIG), (I_TAP_INTERNAL_KEY, XONLY), (I_TAP_MERKLE_ROOT, b"\x33" * 32)]],
                [[]],
            ),
        ),
        case(
            "valid.v0.taproot.script_path_fields",
            "valid/v0/taproot",
            "P2TR input with one taproot script-path signature and one leaf script with a control block.",
            build(
                [g_tx(TX_T)],
                [[
                    i_witness(UTXO_T),
                    (I_TAP_SCRIPT_SIG + XONLY + b"\x44" * 32, TAP_SIG),
                    (I_TAP_LEAF_SCRIPT + b"\xc0" + XONLY, b"\x51\xc0"),
                ]],
                [[]],
            ),
        ),
        case(
            "valid.v0.unknown.global",
            "valid/v0/unknown",
            "Unknown global key type 0x7f is preserved verbatim.",
            build([g_tx(TX_A), g_unknown()], [[]], [[]]),
        ),
        case(
            "valid.v0.unknown.input",
            "valid/v0/unknown",
            "Unknown input key type 0x7f is preserved verbatim.",
            build([g_tx(TX_A)], [[i_unknown()]], [[]]),
        ),
        case(
            "valid.v0.unknown.output",
            "valid/v0/unknown",
            "Unknown output key type 0x7f is preserved verbatim.",
            build([g_tx(TX_A)], [[]], [[o_unknown()]]),
        ),
        case(
            "valid.v0.unknown.empty_value",
            "valid/v0/unknown",
            "Unknown global field with a zero-length value.",
            build([g_tx(TX_A), g_unknown(b"\x02", b"")], [[]], [[]]),
        ),
        case(
            "valid.v0.proprietary.all_levels",
            "valid/v0/proprietary",
            "Proprietary identifier on the global, input, and output maps.",
            build(
                [g_tx(TX_A), g_proprietary()],
                [[i_proprietary()]],
                [[o_proprietary()]],
            ),
        ),
        case(
            "valid.v0.global_xpub",
            "valid/v0/global",
            "A global xpub with an inline key origin path.",
            build(
                [g_tx(TX_A), (xpub_key(), b"\xde\xad\xbe\xef" + struct.pack("<II", 0x8000002C, 0x80000000))],
                [[]],
                [[]],
            ),
        ),
        case(
            "valid.v0.two_inputs_two_outputs",
            "valid/v0/multi",
            "Two inputs (one legacy, one segwit) and two outputs; fee is derivable.",
            build(
                [g_tx(TX_MULTI)],
                [[i_non_witness(PREV_MULTI), i_witness(txout(100_000, PKH_A))], [i_witness(txout(200_000, WPKH_B))]],
                [[], []],
            ),
        ),
        case(
            "valid.v0.version_field_zero",
            "valid/v0/global",
            "Explicit PSBT_GLOBAL_VERSION value 0 alongside the unsigned transaction.",
            build([g_tx(TX_A), g_version(0)], [[]], [[]]),
        ),
        case(
            "valid.v0.zero_inputs_zero_outputs",
            "valid/v0/shape",
            "Structurally empty transaction: zero inputs and zero outputs.",
            build([g_tx(TX_ZERO)], [], []),
        ),
        case(
            "valid.v0.one_input_zero_outputs",
            "valid/v0/shape",
            "One unsigned input and no outputs.",
            build([g_tx(TX_NO_OUT)], [[]], []),
        ),
        case(
            "valid.v0.two_outputs_no_utxo",
            "valid/v0/shape",
            "One input without UTXO data and two outputs; no fee is reported.",
            build([g_tx(TX_TWO_OUT)], [[]], [[], []]),
        ),
    ]

    # ------------------------------------------------------- malformed framing
    cases += [
        case(
            "invalid.magic.bad",
            "malformed/framing",
            "The fifth magic byte is changed.",
            MAGIC[:4] + b"\xfe" + build([g_tx(TX_A)], [[]], [[]])[5:],
        ),
        case(
            "invalid.magic.short",
            "malformed/framing",
            "Only three magic bytes are present.",
            b"\x70\x73\x62",
        ),
        case(
            "invalid.global.missing_separator",
            "malformed/truncated",
            "Global map ends at EOF without its separator byte.",
            build([g_tx(TX_ZERO)], [], [], terminate_global=False),
        ),
        case(
            "invalid.input.missing_separator",
            "malformed/truncated",
            "The single input map ends at EOF without its separator byte.",
            MAGIC
            + map_bytes([entry(*g_tx(TX_NO_OUT))])
            + map_bytes([entry(*i_witness(UTXO_A))], terminated=False),
        ),
        case(
            "invalid.output.missing_separator",
            "malformed/truncated",
            "The single output map ends at EOF without its separator byte.",
            MAGIC
            + map_bytes([entry(*g_tx(TX_A))])
            + map_bytes([entry(*i_witness(UTXO_A))])
            + map_bytes([entry(*o_unknown())], terminated=False),
        ),
        case(
            "invalid.global.truncated_key_length",
            "malformed/truncated",
            "Global map ends immediately after a 0xfd CompactSize prefix.",
            MAGIC + b"\xfd",
        ),
        case(
            "invalid.global.truncated_key_data",
            "malformed/truncated",
            "Key length says five bytes but only one key byte follows.",
            MAGIC + cs(5) + b"\x00",
        ),
        case(
            "invalid.global.truncated_value",
            "malformed/truncated",
            "Unsigned transaction value is cut short of its declared length.",
            MAGIC + raw_entry(G_UNSIGNED_TX, TX_A[:10], value_len=cs(len(TX_A))),
        ),
        case(
            "invalid.compact.key_length_noncanonical",
            "malformed/compact-size",
            "One-byte key length encoded with the 0xfd form.",
            MAGIC + raw_entry(G_UNSIGNED_TX, TX_A, key_len=b"\xfd\x01\x00"),
        ),
        case(
            "invalid.compact.value_length_noncanonical",
            "malformed/compact-size",
            "One-byte value length encoded with the 0xfd form.",
            MAGIC + raw_entry(UNKNOWN_GLOBAL_KEY, b"x", value_len=b"\xfd\x01\x00"),
        ),
        case(
            "invalid.compact.key_length_huge",
            "malformed/compact-size",
            "Key length is the maximum uint64, above Core's allocation limit.",
            MAGIC + b"\xff" + b"\xff" * 8,
        ),
        case(
            "invalid.compact.value_length_huge",
            "malformed/compact-size",
            "Value length is the maximum uint64, above Core's allocation limit.",
            MAGIC + varbytes(G_UNSIGNED_TX) + b"\xff" + b"\xff" * 8,
        ),
        case(
            "invalid.trailing_data",
            "malformed/framing",
            "One extra zero byte follows a complete PSBT.",
            build([g_tx(TX_A)], [[]], [[]]) + b"\x00",
        ),
    ]

    # --------------------------------------------------- malformed map contents
    cases += [
        case(
            "invalid.duplicate.global_version",
            "malformed/duplicate",
            "PSBT_GLOBAL_VERSION appears twice in the global map.",
            build([g_tx(TX_A), g_version(0), g_version(0)], [[]], [[]]),
        ),
        case(
            "invalid.duplicate.global_unknown",
            "malformed/duplicate",
            "The same unknown global key appears twice.",
            build([g_tx(TX_A), g_unknown(), g_unknown()], [[]], [[]]),
        ),
        case(
            "invalid.duplicate.input_unknown",
            "malformed/duplicate",
            "The same unknown input key appears twice.",
            build([g_tx(TX_A)], [[i_witness(UTXO_A), i_unknown(), i_unknown()]], [[]]),
        ),
        case(
            "invalid.duplicate.output_unknown",
            "malformed/duplicate",
            "The same unknown output key appears twice.",
            build([g_tx(TX_A)], [[]], [[o_unknown(), o_unknown()]]),
        ),
        case(
            "invalid.duplicate.partial_sig",
            "malformed/duplicate",
            "The same partial-signature pubkey key appears twice.",
            build([g_tx(TX_B)], [[i_witness(UTXO_B), i_partial_sig(), i_partial_sig()]], [[]]),
        ),
        case(
            "invalid.global.no_unsigned_tx",
            "malformed/global",
            "An empty global map in PSBTv0 with no unsigned transaction.",
            build([], [], []),
        ),
        case(
            "invalid.global.unsigned_tx_nonempty_scriptsig",
            "malformed/global",
            "The unsigned transaction's input carries a scriptSig.",
            build([g_tx(spend_tx([(PREV_A, 0)], [(90_000, WPKH_C)], script_sigs=[b"\x51"]))], [[]], [[]]),
        ),
        case(
            "invalid.global.unsigned_tx_nonempty_witness",
            "malformed/global",
            "The unsigned transaction carries a BIP144 witness section; the v0 global field expects the no-witness serialization and rejects the leftover bytes.",
            build([g_tx(spend_tx([(PREV_A, 0)], [(90_000, WPKH_C)], witnesses=[[b"\x01"]]))], [[]], [[]]),
        ),
        case(
            "invalid.global.version_one",
            "malformed/version",
            "PSBT_GLOBAL_VERSION value 1, which does not exist.",
            build([g_tx(TX_A), g_version(1)], [[]], [[]]),
        ),
        case(
            "invalid.global.version_three",
            "malformed/version",
            "PSBT_GLOBAL_VERSION value 3, above the highest supported version.",
            build([g_tx(TX_A), g_version(3)], [[]], [[]]),
        ),
        case(
            "invalid.v0.tx_version_field",
            "malformed/version",
            "A PSBTv2 global transaction-version field inside a v0 PSBT.",
            build([g_tx(TX_A), g_tx_version(2)], [[]], [[]]),
        ),
        case(
            "invalid.v0.fallback_locktime_field",
            "malformed/version",
            "A PSBTv2 fallback-locktime field inside a v0 PSBT.",
            build([g_tx(TX_A), (G_FALLBACK_LOCKTIME, struct.pack("<I", 0))], [[]], [[]]),
        ),
        case(
            "invalid.v0.input_count_field",
            "malformed/version",
            "A PSBTv2 input-count field inside a v0 PSBT.",
            build([g_tx(TX_A), g_count(G_INPUT_COUNT, 1)], [[]], [[]]),
        ),
        case(
            "invalid.v0.output_count_field",
            "malformed/version",
            "A PSBTv2 output-count field inside a v0 PSBT.",
            build([g_tx(TX_A), g_count(G_OUTPUT_COUNT, 1)], [[]], [[]]),
        ),
        case(
            "invalid.v0.tx_modifiable_field",
            "malformed/version",
            "A PSBTv2 tx-modifiable field inside a v0 PSBT.",
            build([g_tx(TX_A), (G_TX_MODIFIABLE, b"\x00")], [[]], [[]]),
        ),
        case(
            "invalid.v0.output_amount_field",
            "malformed/version",
            "A PSBTv2 output amount field inside a v0 PSBT output map.",
            build([g_tx(TX_A)], [[]], [[(O_AMOUNT, struct.pack("<q", 90_000))]]),
        ),
        case(
            "invalid.v0.output_script_field",
            "malformed/version",
            "A PSBTv2 output script field inside a v0 PSBT output map.",
            build([g_tx(TX_A)], [[]], [[(O_SCRIPT, WPKH_C)]]),
        ),
        case(
            "invalid.v2.unsigned_tx_present",
            "malformed/version",
            "A PSBTv2 header that also carries PSBT_GLOBAL_UNSIGNED_TX.",
            build(
                [g_tx(TX_A), g_version(2), g_tx_version(2), g_count(G_INPUT_COUNT, 1), g_count(G_OUTPUT_COUNT, 1)],
                [[]],
                [[]],
            ),
        ),
        case(
            "invalid.v2.missing_required_fields",
            "malformed/version",
            "A PSBTv2 header with none of the required v2 global fields.",
            build([g_version(2)], [], []),
        ),
        case(
            "invalid.inputs.count_mismatch",
            "malformed/maps",
            "Two-input transaction but only one per-input map is supplied.",
            build([g_tx(TX_MULTI)], [[]], []),
        ),
        case(
            "invalid.outputs.count_mismatch",
            "malformed/maps",
            "Two-output transaction but only one per-output map is supplied.",
            build([g_tx(TX_TWO_OUT)], [[]], [[]]),
        ),
        case(
            "invalid.non_witness.hash_mismatch",
            "malformed/utxo",
            "non_witness_utxo is the previous transaction for a different outpoint.",
            build([g_tx(TX_B)], [[i_non_witness(PREV_A)]], [[]]),
        ),
        case(
            "invalid.non_witness.index_out_of_range",
            "malformed/utxo",
            "The unsigned input's output index is beyond the previous transaction's outputs.",
            build(
                [g_tx(spend_tx([(PREV_A, 5)], [(90_000, WPKH_C)]))],
                [[i_non_witness(PREV_A)]],
                [[]],
            ),
        ),
        case(
            "invalid.non_witness.truncated_tx",
            "malformed/utxo",
            "non_witness_utxo ends inside the previous transaction.",
            build([g_tx(TX_A)], [[i_non_witness(PREV_A[:-4])]], [[]]),
        ),
        case(
            "invalid.witness_utxo.truncated",
            "malformed/utxo",
            "witness_utxo value is one byte instead of amount plus script.",
            build([g_tx(TX_A)], [[(I_WITNESS_UTXO, b"\x01")]], [[]]),
        ),
        case(
            "invalid.partial_sig.key_size",
            "malformed/signature",
            "Partial-signature key is one byte instead of a pubkey.",
            build([g_tx(TX_B)], [[(I_PARTIAL_SIG + b"\x01", DER_SIG)]], [[]]),
        ),
        case(
            "invalid.partial_sig.invalid_pubkey",
            "malformed/signature",
            "Partial-signature key contains an invalid compressed pubkey.",
            build([g_tx(TX_B)], [[(I_PARTIAL_SIG + b"\x02" + b"\x00" * 32, DER_SIG)]], [[]]),
        ),
        case(
            "invalid.partial_sig.bad_der",
            "malformed/signature",
            "Partial-signature value is not strict-DER encoded.",
            build([g_tx(TX_B)], [[(I_PARTIAL_SIG + PUBKEY, b"\x00\x00")]], [[]]),
        ),
        case(
            "invalid.taproot.key_sig_short",
            "malformed/taproot",
            "Taproot key-path signature is 63 bytes.",
            build([g_tx(TX_T)], [[i_witness(UTXO_T), (I_TAP_KEY_SIG, b"\x00" * 63)]], [[]]),
        ),
        case(
            "invalid.taproot.key_sig_long",
            "malformed/taproot",
            "Taproot key-path signature is 66 bytes.",
            build([g_tx(TX_T)], [[i_witness(UTXO_T), (I_TAP_KEY_SIG, b"\x00" * 66)]], [[]]),
        ),
        case(
            "invalid.xpub.bad_pubkey",
            "malformed/global",
            "Global xpub key has the right length but an invalid compressed pubkey.",
            build(
                [
                    g_tx(TX_A),
                    (
                        G_XPUB + b"\x04\x35\x87\xcf" + b"\x00" + b"\x00" * 4 + b"\x00" * 4 + b"\x5a" * 32 + b"\x02" + b"\x00" * 32,
                        b"\xde\xad\xbe\xef",
                    ),
                ],
                [[]],
                [[]],
            ),
        ),
        case(
            "invalid.xpub.bad_size",
            "malformed/global",
            "Global xpub key is shorter than the required 79 bytes.",
            build([g_tx(TX_A), (G_XPUB + b"\x00" * 10, b"\xde\xad\xbe\xef")], [[]], [[]]),
        ),
    ]

    # ------------------------------------------------------- base64 transport
    cases += [
        case(
            "invalid.base64.not_base64",
            "malformed/base64",
            "The RPC argument contains characters outside the base64 alphabet.",
            b64="!!!!not-base64!!!!",
        ),
        case(
            "invalid.base64.empty",
            "malformed/base64",
            "The empty string is passed as the PSBT argument.",
            b64="",
        ),
    ]

    return cases


def main() -> None:
    """Print the deterministic base64 of every candidate, for inspection."""
    import argparse

    parser = argparse.ArgumentParser(description="Dump the PSBT case builder output")
    parser.add_argument("--json", action="store_true", help="emit one JSON object per case")
    parser.add_argument(
        "--save-raw",
        metavar="DIR",
        help="write each case as <case_id>.psbt (base64 candidates are skipped)",
    )
    args = parser.parse_args()

    cases = build_cases()
    if args.save_raw:
        from pathlib import Path

        target = Path(args.save_raw)
        target.mkdir(parents=True, exist_ok=True)
        for item in cases:
            if item.data is not None:
                (target / f"{item.case_id}.psbt").write_bytes(item.data)
    for item in cases:
        if args.json:
            import json

            print(json.dumps({"case_id": item.case_id, "psbt_b64": item.as_b64()}, sort_keys=True))
        else:
            print(f"{item.case_id}\t{len(item.as_b64())}\t{item.as_b64()}")


if __name__ == "__main__":
    main()
