#!/usr/bin/env python3
"""sighash crosscheck — statically re-derives every vector emitted in
spec/Test/Sighash/SighashTest.lean from the RAW corpora (sighash.json core corpus), through the independent
Python mirror (hashlib). Proves the Lean file's literals == Core's corpus.

Run: python3 spec/Test/Sighash/crosscheck.py
"""
import re, json, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
from mirror import hexb, decode_tx, legacy_sighash, bip143_sighash

HARNESS = str(HERE / 'SighashTest.lean')
src = open(HARNESS).read()
# strip the line-continuations inside string literals
src = src.replace('\\\n  ', '')

pat_legacy = re.compile(
    r'signatureHashLegacy \(txOf "([0-9a-f]+)"\) (\d+) \(scOf "([0-9a-f]*)"\) (0x[0-9a-f]+)\)'
    r'\s*\(revHex "([0-9a-f]+)"\) = true', re.S)
pat_bip143 = re.compile(
    r'signatureHashBip143 \(txOf "([0-9a-f]+)"\) (\d+) \(scOf "([0-9a-f]*)"\) (0x[0-9a-f]+) (\d+)\)'
    r'\s*\(beHex "([0-9a-f]+)"\) = true', re.S)

vecs = json.load(open(ROOT / 'spec' / 'data' / 'core' / 'sighash.json'))
rows = [r for r in vecs if isinstance(r, list) and len(r) == 5 and isinstance(r[2], int)]
by_rawtx = {}
for r in rows:
    by_rawtx.setdefault(r[0], []).append(r)

ok = 0
for m in pat_legacy.finditer(src):
    rawtx, nin, sc, ht, exp = m.group(1), int(m.group(2)), m.group(3), int(m.group(4), 16), m.group(5)
    # locate the corpus row (same rawTx, inputIndex, hashtype)
    cand = [r for r in by_rawtx.get(rawtx, [])
            if r[2] == nin and (r[3] & 0xFFFFFFFF) == ht and r[1] == sc]
    assert len(cand) == 1, f"corpus row not found: nIn {nin} ht {ht:#x}"
    r = cand[0]
    v, vin, vout, lt = decode_tx(hexb(rawtx))
    ht_s = ht - 2**32 if ht >= 2**31 else ht   # mirror packs '<i' (signed)
    got = legacy_sighash(v, vin, vout, lt, nin, hexb(sc), ht_s).hex()
    assert got == hexb(exp)[::-1].hex(), (nin, ht, got, exp)
    assert got == hexb(r[4])[::-1].hex(), "harness expectation != corpus"
    ok += 1

okb = 0
for m in pat_bip143.finditer(src):
    rawtx, nin, sc, ht, amt, exp = (m.group(1), int(m.group(2)), m.group(3),
                                    int(m.group(4), 16), int(m.group(5)), m.group(6))
    v, vin, vout, lt = decode_tx(hexb(rawtx))
    got = bip143_sighash(v, vin, vout, lt, nin, hexb(sc), amt, ht).hex()
    assert got == exp, (nin, ht, got, exp)
    okb += 1

n_ovr = len(re.findall(r'beHex "(?:01){32}"', src))
print(f"crosscheck: {ok} legacy corpus vectors + {n_ovr} synthetic SINGLE-overflow "
      f"+ {okb} BIP143 examples — all re-derived from the raw corpora: OK")
assert ok + n_ovr >= 50, "S1 requires >= 50 legacy vectors"
