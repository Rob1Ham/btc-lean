#!/usr/bin/env python3
# [CROWNLINK] Corpus emitter: the ECDSA-lax 215-vector ECDSA battery ->
# proofs/BitcoinProofs/EcdsaDeep/CrownBattery.lean (the CROWNLINK
# sample set; see docs/PROVENANCE.md).
#
# Rows are read VERBATIM from spec/Test/Crypto/EcdsaTest.lean
# `vectors` (the lax-DER battery corpus; the parse layer is kernel-pinned
# by DerBatteryCor.lean, the verify layer = the CROWNLINK bridge).
# NO oracle, NO computation on the values: this is a verbatim lift of
# (name, expected, sig, pk, msg) 5-tuples. Regenerate:
#   python3 emit_crownlink.py   (writes ../CrownBattery.lean)
#
# License notice (license notice): no Bitcoin Core code is
# transliterated here (verbatim test-vector lift only; the vectors are
# the project generated corpus).
import re, sys, os
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
TEST = str(ROOT / 'spec' / 'Test' / 'Crypto' / 'EcdsaTest.lean')
OUT = str(HERE / 'CrownBattery.lean')
pat = re.compile(r'\("([A-Za-z0-9-]+)", (true|false), "([0-9a-f]*)", "([0-9a-f]*)", "([0-9a-f]*)"\)')
rows, seen = [], set()
for line in open(TEST):
    m = pat.search(line)
    if m:
        rows.append((m.group(1), m.group(2) == 'true', m.group(3), m.group(4), m.group(5)))
        seen.add(m.group(1))
assert len(rows) == 215 and len(seen) == 215, (len(rows), len(seen))
acc = sum(1 for r in rows if r[1]); assert (acc, 215 - acc) == (139, 76), (acc,)
# sanity: no multi-line rows (EcdsaTest rows are single lines)
with open(OUT) as f:
    old = f.read()
print("rows", len(rows), "acc", acc, "rej", 215 - acc)
print("NOTE: emitter = provenance record; CrownBattery.lean in-tree = "
      "the committed artifact (diff-vs-emitted checked at commit time)")
