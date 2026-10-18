#!/usr/bin/env python3
"""Build real-PoW public Taproot validation fixtures from pinned Core vectors.

The supplied parent/history/UTXO state is conditional test input. The block
is not a reachable historical-mainnet-chain claim. Generated signatures use
public test scalars and the independent Python BIP340/BIP341 references.
"""

import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "spec/Test/Crypto"))
import gen_schnorr_random as curve
import taproot_sighash_crosscheck as bip341

CORPUS = ROOT / "spec/data/bips/bip-0341_wallet-test-vectors.json"
CORPUS_SHA256 = "403e19fb81dd1f31e745699216308f61fb403774b2aafa87b631b8f7c042d37f"
DEST = ROOT / "spec/data/review/taproot-validation"
HEIGHT = 709632
HEADER_TIME = 1231006507
NONCE = 3652175247  # Independently re-hashed below; no mining is needed on regeneration.
PARENT = "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f"


def sha256d(data):
    return hashlib.sha256(hashlib.sha256(data).digest()).digest()


def compact(n):
    if n < 253:
        return bytes([n])
    size = 2 if n <= 0xffff else 4 if n <= 0xffffffff else 8
    return bytes([{2: 253, 4: 254, 8: 255}[size]])+n.to_bytes(size, "little")


def stack_bytes(items):
    return compact(len(items))+b"".join(bip341.varbytes(item) for item in items)


def encode_tx(tx, witness=None):
    version, vin, vout, locktime = tx
    have_witness = witness is not None and any(witness)
    data = version.to_bytes(4, "little")+(b"\x00\x01" if have_witness else b"")
    data += compact(len(vin))
    data += b"".join(h+n.to_bytes(4, "little")+bip341.varbytes(ss)+seq.to_bytes(4, "little")
                     for h, n, ss, seq in vin)
    data += compact(len(vout))+b"".join(bip341.ctout(value, script) for value, script in vout)
    if have_witness:
        assert len(witness) == len(vin)
        data += b"".join(stack_bytes(items) for items in witness)
    return data+locktime.to_bytes(4, "little")


def decode_tx(data):
    """Limited independent BIP144 decoder for these deterministic fixtures."""
    pos = 0

    def take(n):
        nonlocal pos
        result = data[pos:pos+n]
        assert len(result) == n
        pos += n
        return result

    def number(n):
        return int.from_bytes(take(n), "little")

    def count():
        first = number(1)
        return first if first < 253 else number({253: 2, 254: 4, 255: 8}[first])

    version = number(4)
    have_witness = data[pos:pos+2] == b"\x00\x01"
    if have_witness:
        take(2)
    vin = [(take(32), number(4), take(count()), number(4)) for _ in range(count())]
    vout = [(number(8), take(count())) for _ in range(count())]
    witness = [[take(count()) for _ in range(count())] for _ in vin] if have_witness else [[] for _ in vin]
    tx = (version, vin, vout, number(4))
    assert pos == len(data) and encode_tx(tx, witness) == data
    return tx, witness


def merkle(leaves):
    assert leaves
    while len(leaves) > 1:
        if len(leaves) % 2:
            leaves = leaves+[leaves[-1]]
        leaves = [sha256d(leaves[i]+leaves[i+1]) for i in range(0, len(leaves), 2)]
    return leaves[0]


def output_for_script(script):
    internal_point = curve.pt_mul(2, curve.G)
    internal = internal_point[0].to_bytes(32, "big")
    leaf = curve.tagged_hash(b"TapLeaf", b"\xc0"+bip341.varbytes(script))
    tweak = int.from_bytes(curve.tagged_hash(b"TapTweak", internal+leaf), "big")
    assert tweak < curve.n
    point = curve.pt_add(curve.lift_x(internal), curve.pt_mul(tweak, curve.G))
    assert point is not None
    control = bytes([0xc0 | (point[1] & 1)])+internal
    return b"\x51\x20"+point[0].to_bytes(32, "big"), control, leaf


def signed_script_tx(previous, value, output, script, separator, annex=None):
    spk, control, leaf = output_for_script(script)
    tx = (2, [(previous, 0, b"", 0xffffffff)], [output], 0)
    digest = bip341.sighash(tx, [(value, spk)], 0, 0, ext_flag=1, annex=annex,
                            tapleaf_hash=leaf, codesep_pos=separator)
    pk, signature = curve.sign(1, bytes(32), digest)
    items = [signature, script, control]+([annex] if annex is not None else [])
    return tx, items, spk, digest, pk


def build(nonce, header_time):
    corpus_bytes = CORPUS.read_bytes()
    assert hashlib.sha256(corpus_bytes).hexdigest() == CORPUS_SHA256
    corpus = json.loads(corpus_bytes)
    official = corpus["keyPathSpending"][0]
    signed_raw = bytes.fromhex(official["auxiliary"]["fullySignedTx"])
    signed, signed_witness = decode_tx(signed_raw)
    spent = [(row["amountSats"], bytes.fromhex(row["scriptPubKey"]))
             for row in official["given"]["utxosSpent"]]
    assert len(spent) == len(signed[1]) == 9
    for row in official["inputSpending"]:
        index, hashtype = row["given"]["txinIndex"], row["given"]["hashType"]
        digest = bip341.sighash(signed, spent, index, hashtype)
        assert digest.hex() == row["intermediary"]["sigHash"]
        assert signed_witness[index] == [bytes.fromhex(x) for x in row["expected"]["witness"]]
        assert curve.verify(spent[index][1][2:], digest, signed_witness[index][0][:64])

    pk = curve.pt_mul(1, curve.G)[0].to_bytes(32, "big")
    separator_script = bytes.fromhex("02aabb750063ab68ab20")+pk+b"\xac"
    # Three 2DUP/CHECKSIGVERIFY pairs followed by CHECKSIG: four signatures.
    # With nine NOPs, the full witness is exactly 150 bytes; +50 = 200 WU.
    budget_script = b"\x61"*9+bytes.fromhex("6ead")*3+b"\xac"
    budget_spk, _, _ = output_for_script(budget_script)
    separator_spk, _, _ = output_for_script(separator_script)

    leaf_case = corpus["scriptPubKey"][4]
    literal_script = bytes.fromhex(leaf_case["given"]["scriptTree"][1]["script"])
    literal_control = bytes.fromhex(leaf_case["expected"]["scriptPathControlBlocks"][1])
    literal_spk = bytes.fromhex(leaf_case["expected"]["scriptPubKey"])
    initial_point = bytes.fromhex("ab"*32)
    parent = (1, [(initial_point, 0, b"", 0xffffffff)], [(9, separator_spk)], 0)
    parent_raw = encode_tx(parent, [[literal_script, literal_control]])
    child, child_items, child_spk, child_digest, _ = signed_script_tx(
        sha256d(encode_tx(parent)), 9, (8, budget_spk), separator_script, 6, b"\x50\x99")
    assert child_spk == separator_spk
    child_raw = encode_tx(child, [child_items])
    last, last_items, last_spk, last_digest, _ = signed_script_tx(
        sha256d(encode_tx(child)), 8, (7, b"\x51"), budget_script, 0xffffffff)
    assert last_spk == budget_spk
    last_items.insert(1, pk)
    assert len(budget_script) == 16 and len(stack_bytes(last_items)) == 150
    last_raw = encode_tx(last, [last_items])

    initial_coins = [dict(txid=h.hex(), n=n, amount=value, scriptPubKey=script.hex())
                     for (h, n, _, _), (value, script) in zip(signed[1], spent)]
    initial_coins.append(dict(txid=initial_point.hex(), n=0, amount=10, scriptPubKey=literal_spk.hex()))
    assert len({(row["txid"], row["n"]) for row in initial_coins}) == 10

    transactions = [(signed, signed_raw), (parent, parent_raw), (child, child_raw), (last, last_raw)]
    reserved = bytes([1])*32
    witness_root = merkle([bytes(32)]+[sha256d(raw) for _, raw in transactions])
    commitment = bytes.fromhex("6a24aa21a9ed")+sha256d(witness_root+reserved)
    cb = (1, [(bytes(32), 0xffffffff, b"\x03"+HEIGHT.to_bytes(3, "little"), 0xffffffff)],
          [(0, commitment)], 0)
    cb_raw = encode_tx(cb, [[reserved]])
    root = merkle([sha256d(encode_tx(cb))]+[sha256d(encode_tx(tx)) for tx, _ in transactions])
    header = struct.pack("<I", 4)+bytes.fromhex(PARENT)[::-1]+root+struct.pack("<III", header_time, 0x1d00ffff, nonce)
    block = header+compact(5)+cb_raw+b"".join(raw for _, raw in transactions)

    # Extra real signatures make the no-separator sentinel and the wrong
    # byte-offset signing error observable without mining further blocks.
    extra = []
    for name, script, signed_separator, actual_separator, annex, expected in [
        ("no separator sentinel", b"\x20"+pk+b"\xac", 0xffffffff, 0xffffffff, None, "pass"),
        ("wrong zero separator sentinel", b"\x20"+pk+b"\xac", 0, 0xffffffff, None, "schnorrSig"),
        ("wrong byte-offset separator", separator_script, 9, 6, b"\x50\x99", "schnorrSig")]:
        tx, items, spk, _, _ = signed_script_tx(bytes.fromhex("44"*32), 9, (8, b"\x51"),
                                              script, signed_separator, annex)
        _, _, leaf = output_for_script(script)
        correct_digest = bip341.sighash(tx, [(9, spk)], 0, 0, ext_flag=1, annex=annex,
                                       tapleaf_hash=leaf, codesep_pos=actual_separator)
        assert curve.verify(pk, correct_digest, items[0]) == (expected == "pass")
        extra.append(dict(name=name, rawTx=encode_tx(tx, [items]).hex(), amount=9,
                          scriptPubKey=spk.hex(), expected=expected))

    # A valid key-path annex signature over the official transaction/cache.
    row = official["inputSpending"][0]
    annex = b"\x50\x99"
    digest = bip341.sighash(signed, spent, 0, row["given"]["hashType"], annex=annex)
    annex_pk, annex_sig = curve.sign(int(row["intermediary"]["tweakedPrivkey"], 16), bytes(32), digest)
    assert annex_pk == spent[0][1][2:]
    annex_witness = [list(items) for items in signed_witness]
    annex_witness[0] = [annex_sig+bytes([row["given"]["hashType"]]), annex]
    metadata = dict(kind="conditional public Taproot integration fixture", height=HEIGHT,
                    time=header_time, nonce=nonce, bits="1d00ffff", parent=PARENT,
                    blockHash=sha256d(header)[::-1].hex(), blockSha256=hashlib.sha256(block).hexdigest(),
                    initialCoins=initial_coins, expectedScriptOk=12, expectedScriptUnjudged=0,
                    officialCorpusSha256=CORPUS_SHA256,
                    officialSources=[
                        "https://raw.githubusercontent.com/bitcoin/bitcoin/cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66/src/test/data/bip341_wallet_vectors.json",
                        "https://raw.githubusercontent.com/bitcoin/bips/927b6de9915c9262615a6399de51b200f81e5aa4/bip-0341/wallet-test-vectors.json"],
                    officialKeypathInputs=[row["given"]["txinIndex"] for row in official["inputSpending"]],
                    childSighash=child_digest.hex(), budgetSighash=last_digest.hex(),
                    budgetWitnessBytes=150, budgetInitial=200, budgetSigops=4,
                    separatorOpcodeIndex=6, legacySeparatorByteOffset=9,
                    keyPathAnnexTx=encode_tx(signed, annex_witness).hex(), extraCases=extra,
                    scope="Real PoW; caller-supplied ancestor/UTXO state is conditional, not a reachable historical-mainnet-chain claim or whole-bitcoind verdict.")
    return block, metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--header-template", type=Path)
    args = parser.parse_args()
    block, metadata = build(NONCE, HEADER_TIME)
    if args.header_template:
        args.header_template.write_bytes(block[:80])
        print("Wrote deterministic header template; no fixture promoted.")
        return
    assert int.from_bytes(sha256d(block[:80]), "little") <= 0xffff << (8*26), "unmined header"
    files = {"valid.raw": block, "provenance.json": (json.dumps(metadata, indent=2)+"\n").encode()}
    if not args.check:
        DEST.mkdir(parents=True, exist_ok=True)
    for name, data in files.items():
        path = DEST/name
        if args.check:
            assert path.read_bytes() == data, f"fixture drift: {name}"
        else:
            path.write_bytes(data)
    print(f"taproot-validation: bytes={len(block)} hash={metadata['blockHash']} "
          f"sha256={metadata['blockSha256']}")


if __name__ == "__main__":
    main()
