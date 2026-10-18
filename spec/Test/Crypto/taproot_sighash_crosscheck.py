#!/usr/bin/env python3
"""
BIP341 sighash crosscheck — independent hashlib mirror of the BIP341 sighash
(bip-0341.mediawiki §"Signature hashing for key and script path spends";
Core SignatureHashSchnorr interpreter.cpp:1493-1578).

1. Validates itself against ALL 7 official key-path inputSpending cases of
   spec/data/bips/bip-0341_wallet-test-vectors.json (sigMsg + sigHash).
2. Re-derives every sigMsg/sigHash literal baked into
   spec/Test/Crypto/TaprootSighashTest.lean (official AND synthetic
   annex/tapscript cases — no official annex/tapscript sighash vectors
   exist, so those expectations are generated HERE and consumed by the
   Lean harness; this file is their generator and checker).

Run: python3 spec/Test/Crypto/taproot_sighash_crosscheck.py
"""
import hashlib, json, re, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
VECTORS = str(ROOT / 'spec' / 'data' / 'bips' / 'bip-0341_wallet-test-vectors.json')
HARNESS = str(HERE / 'TaprootSighashTest.lean')

# ---------- raw primitives (independent: hashlib only) ----------

def sha256(b): return hashlib.sha256(b).digest()

def tagged_hash(tag, msg):
    t = hashlib.sha256(tag.encode()).digest()
    return hashlib.sha256(t + t + msg).digest()

def varbytes(b):  # CompactSize length prefix + bytes (ser_string-ish)
    n = len(b)
    if n < 0xfd: return bytes([n]) + b
    if n <= 0xffff: return b'\xfd' + n.to_bytes(2, 'little') + b
    if n <= 0xffffffff: return b'\xfe' + n.to_bytes(4, 'little') + b
    return b'\xff' + n.to_bytes(8, 'little') + b

def read_varint(b, i):
    n0 = b[i]
    if n0 < 0xfd: return n0, i + 1
    if n0 == 0xfd: return int.from_bytes(b[i+1:i+3], 'little'), i + 3
    if n0 == 0xfe: return int.from_bytes(b[i+1:i+5], 'little'), i + 5
    return int.from_bytes(b[i+1:i+9], 'little'), i + 9

def decode_tx(b):
    """(version, vin, vout, locktime); vin = [(txid-as-is, n, scriptSig, seq)],
    vout = [(value, spk)] — legacy/nSegwit wire, matches rawUnsignedTx."""
    i = 0
    version = int.from_bytes(b[i:i+4], 'little'); i += 4
    # no segwit marker in the wallet-test corpus rawUnsignedTx
    nvin, i = read_varint(b, i)
    vin = []
    for _ in range(nvin):
        h = b[i:i+32]; i += 32
        n = int.from_bytes(b[i:i+4], 'little'); i += 4
        slen, i = read_varint(b, i)
        ss = b[i:i+slen]; i += slen
        seq = int.from_bytes(b[i:i+4], 'little'); i += 4
        vin.append((h, n, ss, seq))
    nvout, i = read_varint(b, i)
    vout = []
    for _ in range(nvout):
        val = int.from_bytes(b[i:i+8], 'little'); i += 8
        slen, i = read_varint(b, i)
        spk = b[i:i+slen]; i += slen
        vout.append((val, spk))
    locktime = int.from_bytes(b[i:i+4], 'little'); i += 4
    assert i == len(b), "trailing bytes in rawUnsignedTx"
    return version, vin, vout, locktime

def ctout(value, spk):
    return value.to_bytes(8, 'little') + varbytes(spk)

# ---------- the BIP341 mirror (single SHA256 throughout, TPR-046) ----------

def sub_hashes(tx, spent):
    version, vin, vout, locktime = tx
    sha_prevouts = sha256(b''.join(h + n.to_bytes(4, 'little') for h, n, _, _ in vin))
    sha_amounts = sha256(b''.join(a.to_bytes(8, 'little') for a, _ in spent))
    sha_scripts = sha256(b''.join(varbytes(s) for _, s in spent))
    sha_sequences = sha256(b''.join(q.to_bytes(4, 'little') for _, _, _, q in vin))
    sha_outputs = sha256(b''.join(ctout(v, s) for v, s in vout))
    return sha_prevouts, sha_amounts, sha_scripts, sha_sequences, sha_outputs

def sig_msg(tx, spent, in_pos, hash_type, ext_flag=0, annex=None,
            tapleaf_hash=None, codesep_pos=None):
    """Returns the SigMsg WITHOUT the epoch byte (the vector field
    `sigMsg` includes the leading 0x00 epoch — added by callers)."""
    version, vin, vout, locktime = tx
    sh_p, sh_a, sh_s, sh_q, sh_o = sub_hashes(tx, spent)
    acp = (hash_type & 0x80) != 0
    output_all = hash_type == 0 or (hash_type & 3) == 1
    single = (hash_type & 3) == 3
    annex_present = annex is not None
    m = bytes([hash_type])
    m += version.to_bytes(4, 'little') + locktime.to_bytes(4, 'little')
    if not acp:  # TPR-037: all four sub-hashes even for NONE/SINGLE
        m += sh_p + sh_a + sh_s + sh_q
    if output_all:
        m += sh_o
    m += bytes([ext_flag * 2 + (1 if annex_present else 0)])  # spend_type
    if acp:
        h, n, _, q = vin[in_pos]
        m += h + n.to_bytes(4, 'little') + ctout(*spent[in_pos]) + q.to_bytes(4, 'little')
    else:
        m += in_pos.to_bytes(4, 'little')
    if annex_present:
        m += sha256(varbytes(annex))  # interpreter.cpp:1964, annex incl 0x50
    if single:
        m += sha256(ctout(*vout[in_pos]))
    if ext_flag == 1:
        m += tapleaf_hash + b'\x00' + codesep_pos.to_bytes(4, 'little')
    return m

def sighash(tx, spent, in_pos, hash_type, **kw):
    return tagged_hash('TapSighash', b'\x00' + sig_msg(tx, spent, in_pos, hash_type, **kw))


def main():
    d = json.load(open(VECTORS))
    kp = d['keyPathSpending'][0]
    tx = decode_tx(bytes.fromhex(kp['given']['rawUnsignedTx']))
    spent = [(u['amountSats'], bytes.fromhex(u['scriptPubKey'])) for u in kp['given']['utxosSpent']]
    ok = 0
    for c in kp['inputSpending']:
        g, it = (c['given'], c['intermediary'])
        ip, ht = (g['txinIndex'], g['hashType'])
        got_msg = b'\x00' + sig_msg(tx, spent, ip, ht)
        got_hash = sighash(tx, spent, ip, ht)
        assert got_msg == bytes.fromhex(it['sigMsg']), f'sigMsg mismatch case ht={ht}'
        assert got_hash == bytes.fromhex(it['sigHash']), f'sigHash mismatch case ht={ht}'
        ok += 1
    print(f'mirror: {ok}/7 official key-path sigMsg+sigHash re-derived: OK')
    src = open(HARNESS).read()
    pat = re.compile('\\("([a-z0-9-]+)",\\s*(\\d+),\\s*(\\d+),\\s*"([0-9a-f]*)",\\s*"([0-9a-f]*)",\\s*(\\d+),\\s*"([0-9a-f]+)",\\s*"([0-9a-f]+)"\\)', re.S)
    ok2 = 0
    for m in pat.finditer(src):
        name, ip, ht, annex, leaf, cs, exp_msg, exp_hash = m.groups()
        ip, ht, cs = (int(ip), int(ht), int(cs))
        kw = {}
        if annex:
            kw['annex'] = bytes.fromhex(annex)
        if leaf:
            kw['ext_flag'] = 1
            kw['tapleaf_hash'] = bytes.fromhex(leaf)
            kw['codesep_pos'] = cs
        got = b'\x00' + sig_msg(tx, spent, ip, ht, **kw)
        assert got == bytes.fromhex(exp_msg), f'{name}: sigMsg {got.hex()} != {exp_msg}'
        got_h = sighash(tx, spent, ip, ht, **kw)
        assert got_h == bytes.fromhex(exp_hash), f'{name}: sigHash {got_h.hex()} != {exp_hash}'
        ok2 += 1
    assert ok2 >= 7, 'harness must embed at least the 7 official cases'
    print(f'crosscheck: {ok2} harness sigMsg/sigHash literals re-derived (official + synthetic annex/tapscript): OK')

if __name__ == "__main__":
    main()
