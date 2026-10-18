#!/usr/bin/env python3
# [CROWNLINK] Unit-4 (E08 extension) corpus emitter: the 19 official
# BIP340 vectors -> proofs/BitcoinProofs/EcdsaDeep/CrownSchnorr.lean
# (the CROWNSCHNORR sample set; see docs/PROVENANCE.md).
#
# Rows are read VERBATIM from spec/Test/Crypto/SchnorrTest.lean
# `vectors` (the generated bip-0340_test-vectors.csv corpus;
# the verify layer = the CROWNSCHNORR bridge over E08's
# SchnorrEquation.lean crown). NO oracle, NO computation on the
# values: this is a verbatim lift of (name, expected, pk, msg, sig)
# 5-tuples -> CrownSRow (name, expected, sig, pk, msg).
#
# This emitter = the VERBATIM-CHECK record (emit_crownlink.py's
# pattern): it re-parses the source rows, re-asserts 19 / 9+10 /
# (pk,sig)=(32B,64B) / b340-14=pk-p+1 (the one kernel row), AND
# diffs every (name,expected,sig,pk,msg) 5-tuple against the
# in-tree committed CrownSchnorr.lean row block. Regenerate-check:
#   python3 emit_crownschnorr.py   (exit 0 = rows verbatim)
#
# License notice (license notice): no Bitcoin Core code is
# transliterated here (verbatim test-vector lift only; the vectors
# are the official bip-0340 test vectors, committed).
import re, sys, os
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
TEST = str(ROOT / 'spec' / 'Test' / 'Crypto' / 'SchnorrTest.lean')
OUT = str(HERE / 'CrownSchnorr.lean')
pat = re.compile(r'\("(b340-\d\d)", (True|False),\s*"([0-9A-F]*)", "([0-9A-F]*)", "([0-9A-F]*)"\)', re.S)
rows, seen = [], set()
for m in pat.finditer(open(TEST).read()):
    rows.append((m.group(1), m.group(2) == 'True', m.group(5), m.group(3), m.group(4)))
    seen.add(m.group(1))
assert len(rows) == 19 and len(seen) == 19, (len(rows), len(seen))
acc = sum(1 for r in rows if r[1]); assert (acc, 19 - acc) == (9, 10), (acc,)
for r in rows:
    assert len(r[3]) == 64 and len(r[2]) == 128, r[0]  # pk 32B, sig 64B
    assert len(r[2]) % 2 == len(r[3]) % 2 == len(r[4]) % 2 == 0
assert rows[14][0] == 'b340-14' and rows[14][1] is False \
    and len(rows[14][3]) == 64 and rows[14][3][54:] == 'FEFFFFFC30', \
    'kernel row b340-14 (pk = p+1)'
assert rows[12][0] == 'b340-12' and rows[12][1] is False  # r = p (WF wall: pk DFF1 < p)
# verbatim diff vs the in-tree row block
src = open(OUT).read()
rowpat = re.compile(r'\u27e8"(b340-\d\d)", (true|false), fromHex\s*"([0-9A-F]*)", fromHex\s*"([0-9A-F]*)", fromHex\s*"([0-9A-F]*)"\u27e9')
inl = [(m.group(1), m.group(2) == 'true', m.group(3), m.group(4), m.group(5))
       for m in rowpat.finditer(src)]
assert len(inl) == 19, len(inl)
assert inl == rows, 'IN-TREE CROWN Schnorr ROWS DRIFT vs SchnorrTest vectors!'
print("rows", len(rows), "acc", acc, "rej", 19 - acc,
      "| in-tree CrownSchnorr.lean rows VERBATIM == SchnorrTest vectors")
print("NOTE: emitter = verbatim-check record; CrownSchnorr.lean in-tree = "
      "the committed artifact (this script exits non-0 on any drift)")
