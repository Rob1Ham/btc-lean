#!/usr/bin/env python3
from pathlib import Path
# [E07] gen_pubkeycor_vecs.py — the PubKeyCor oracle + row generator.
#
# same pattern as gen_der_battery.py (gen_der_battery.py) for the E07 pubkey-parse lane:
#   * pyC      = an INDEPENDENT python transliteration of the C ONLY
#                (CPubKey::GetLen/Set/ValidSize pubkey.h:69-105 @cce32b168;
#                 CPubKey::Verify pubkey.cpp:283-294;
#                 secp256k1_ec_pubkey_parse secp256k1.c:265-281;
#                 ge_impl_parse group_impl.h:1084-1102) — NO Lean consulted.
#   * pyLean   = a python transliteration of the LEAN def
#                (EcdsaDeep/PubKeyParse.lean parsePubKeyDeep =
#                 Ecdsa/Verify.parsePubKey SGN-105) — byte/branch-faithful.
#   * A row is a (id, hexpk) pair; pyC vs pyLean must agree on EVERY row.
#
# R6 boundary (F-ECDSA-lax-1 / F-E14-4): the Lean def's 33-byte Some-path goes
# through sqrtP = expM = WellFounded recursion = the Lean KERNEL cannot
# reduce it (E14: WF lane fails at exp 13).  => rows whose pyLean verdict
# depends on sqrtP (33B tags 02/03 on an x < P) are emitted as **pyC TRUTH
# comment rows** (kernel-claim would be dishonest); 65B-lane rows (x,y<P,
# hybrid parity, onCurveN = mulM/addM = GMP) and all reject-before-expM
# rows (x >= P, bad tag, bad length) are emitted as `by decide` rows.
#
# Usage:  python3 gen_pubkeycor_vecs.py  >  COR-TABLE.txt   (table + diff
# verdicts on stdout; the .lean files PubKeyCorSer.lean / PubKeyCorVec.lean
# are written next to this script).
import json, csv, os, sys

P  = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
N  = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
Gx = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
Gy = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8
SQRT_EXP = (P + 1) // 4

# ---------------------------------------------------------------- pyC (C only)
def c_getlen(tag):                      # pubkey.h:69-76
    if tag in (2, 3):  return 33
    if tag in (4, 6, 7): return 65
    return 0

def c_validsize(b):                     # pubkey.h:86-88 (Set 98-105)
    return len(b) > 0 and c_getlen(b[0]) == len(b)

def c_ge_parse(b):                      # secp256k1.c:265-281 -> group_impl.h:1084-1102
    if len(b) == 33 and b[0] in (2, 3):
        x = int.from_bytes(b[1:33], 'big')
        if x >= P: return None                       # fe_set_b32_limit
        y2 = (x * x * x + 7) % P                     # the curve rhs (C field)
        r = pow(y2, (P + 1) // 4, P)                 # fe_sqrt (p=3 mod 4)
        if (r * r) % P != y2: return None            # ge_set_xo_var reject
        odd = (b[0] == 3)                            # TAG_PUBKEY_ODD
        y = r if ((r & 1) == odd) else (P - r)       # negate unless parity
        return (x, y)
    if len(b) == 65 and b[0] in (4, 6, 7):
        x = int.from_bytes(b[1:33], 'big')
        y = int.from_bytes(b[33:65], 'big')
        if x >= P or y >= P: return None             # fe_set_b32_limit x,y
        if b[0] in (6, 7) and ((y & 1) != (b[0] == 7)):
            return None                              # hybrid parity 1094-96
        if (y * y - x * x * x - 7) % P != 0:         # ge_is_valid_var 1098
            return None
        return (x, y)
    return None                                      # 1099-1101

def c_cpubkey_verify(b):                # pubkey.cpp:283-294 (parse dim only)
    return c_validsize(b) and c_ge_parse(b) is not None

# ------------------------------------------------------------- pyLean (the def)
def l_blen(b):    return len(b)
def l_byteAt(b, i): return b[i] if i < len(b) else 0
def l_readBE(b, pos, l):
    r = 0
    for k in range(l):                 # readBE b pos (k+1) = ...*256 + b[pos+k]
        r = r * 256 + l_byteAt(b, pos + k)
    return r
def l_negN(y):    return (0 + P - y) % P
def l_onCurveN(x, y):
    return ((y * y) % P) == (((((x * x) % P) * x) % P) + 7) % P
def l_sqrtP(x):   return pow(x, SQRT_EXP, P)          # = expM P x sqrtExp (Sgn-103)
def l_liftY2(x):  return (((((x * x) % P) * x) % P) + 7) % P
def l_isSqrt(x, r): return ((r * r) % P) == x
def l_parse(b):                       # PubKeyParse.lean parsePubKeyDeep verbatim
    tag = l_byteAt(b, 0)
    if l_blen(b) == 33 and (tag == 0x02 or tag == 0x03):
        x = l_readBE(b, 1, 32)
        if x >= P: return None
        y2 = l_liftY2(x)
        root = l_sqrtP(y2)
        if not l_isSqrt(y2, root): return None
        return (x, root if ((tag == 0x03) == (root % 2 == 1)) else l_negN(root))
    if l_blen(b) == 65 and (tag == 0x04 or tag == 0x06 or tag == 0x07):
        x = l_readBE(b, 1, 32)
        y = l_readBE(b, 33, 32)
        if x >= P or y >= P: return None
        if (tag == 0x06 or tag == 0x07) and ((y % 2 == 1) != (tag == 0x07)):
            return None
        if l_onCurveN(x, y): return (x, y)
        return None
    return None
def l_validsize(b):                    # PubKeyParse.lean validPubKeySize
    def getlen(t): return 33 if t in (2, 3) else (65 if t in (4, 6, 7) else 0)
    return l_blen(b) > 0 and getlen(l_byteAt(b, 0)) == l_blen(b)

# ------------------------------------------------------------------ helpers
def h(s): return bytes.fromhex(s)
def hx(b): return b.hex().upper()
def ser33(tag, x): return bytes([tag]) + x.to_bytes(32, 'big')
def ser65(tag, x, y): return bytes([tag]) + x.to_bytes(32, 'big') + y.to_bytes(32, 'big')
def r6_row(hexid):                    # 33B Some-path (sqrtP = expM = WF)
    b = h(hexid) if isinstance(hexid, str) else hexid
    return b[0] == 2 or b[0] == 3 and False
def needs_r6(b):
    """True iff the pyLean verdict of b depends on sqrtP (33B tags 02/03,
    x < P): kernel `decide` cannot reduce expM (R6)."""
    if len(b) == 33 and b[0] in (2, 3):
        x = l_readBE(b, 1, 32)
        return x < P          # x>=P rejects before sqrtP => decide-clean
    return False

def fmt(p): return 'none' if p is None else 'some (0x%X, 0x%X)' % p

# ------------------------------------------------------------------ corpora
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
V340 = str(ROOT / 'spec' / 'data' / 'bips' / 'bip-0340_test-vectors.csv')
V341 = str(ROOT / 'spec' / 'data' / 'bips' / 'bip-0341_wallet-test-vectors.json')
bip340 = list(csv.DictReader(open(V340)))
pkc   = {r['index']: r['public key'] for r in bip340}
r0, r1, r4, r5, r12, r14, r15 = (pkc['0'], pkc['1'], pkc['4'], pkc['5'],
                                  bip340[12]['signature'][:64],
                                  pkc['14'], pkc['15'])
d341 = json.load(open(V341))
spk1 = d341['scriptPubKey'][0]
internal, tweak, tweaked = (spk1['given']['internalPubkey'],
                            spk1['intermediary']['tweak'],
                            spk1['intermediary']['tweakedPubkey'])
spkhex = spk1['expected']['scriptPubKey']
kps = d341['keyPathSpending'][0]
X0B32 = '00' * 32                       # the honest SYNTH zero-y
DFF1 = r1                               # BIP340 row-1 pubkey (valid xonly x)
D69C = r5                               # BIP340 row-5 pubkey (non-residue x)
X14  = r14                              # BIP340 row-14 pubkey (x = P+1 >= P)
RD12 = r12                              # BIP340 row-12 sig[0:32] = r = P
TWEAK, INTL, TWD = tweak, internal, tweaked

# pkform-000..009 (pkform-* 65B corpus): hexes extracted read-only from
# the PubKeyMatrix.lean M6 rows (= the ECDSA-lax EcdsaTest pkform
# vectors) — NO hand transcription (avoids the classic dropped-nibble).
import re
_src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         'PubKeyMatrix.lean')).read()
PKFORM = {}
for m in re.finditer(r'-- M6-pkform-(\w+)-(\d+)\n'
                     r'example : corePubKeyOk \(fromHex "([0-9a-fA-F]+)"\)', _src):
    PKFORM[int(m.group(2))] = m.group(3)
assert len(PKFORM) == 10, 'pkform extraction: got %d' % len(PKFORM)
for _i in range(10):
    assert len(PKFORM[_i]) == 130, (PKFORM[_i], len(PKFORM[_i]))

rows = []          # (unit, id, hex, kind, note)  kind: 'K' decide / 'R6' pyC
def add(unit, id, hexs, kind, note):
    rows.append((unit, id, hexs if isinstance(hexs, str) else hx(hexs), kind, note))

# ---------------- U3 PubKeyCorSer — serializers + 65B round trips ----------------
# s0 pyC TRUTH (R6): 33B Some-path = sqrtP = expM = kernel-stuck
add('SER', 'SER-S0-G-02',  ser33(2, Gx), 'R6', 'serCompressed 02 Gx')
add('SER', 'SER-S0-G-03',  ser33(3, Gx), 'R6', 'serCompressed 03 Gx')
add('SER', 'SER-S0-1-02',  ser33(2, int(DFF1, 16)), 'R6', 'serCompressed 02 <BIP340 row-1 pk>')
add('SER', 'SER-S0-1-03',  ser33(3, int(DFF1, 16)), 'R6', 'serCompressed 03 <BIP340 row-1 pk>')
# s1-s10: G-serializer + parity matrix (all 65B-lane = decide-clean)
add('SER', 'SER-G-U-RT',   ser65(4, Gx, Gy), 'K', 'parse(serUncompressed Gx Gy) = some (Gx, Gy)')
add('SER', 'SER-G-U-ODD',  ser65(4, Gx, (P - Gy) % P), 'K', 'serUncompressed Gx (P-Gy) (odd y): tag 04 not parity-checked')
add('SER', 'SER-G-H-RT',   ser65((7 if (P - Gy) % 2 else 6), Gx, (P - Gy) % P), 'K', 'serHybrid Gx (P-Gy) (auto-tag 07): round trip')
add('SER', 'SER-G-H-06E',  ser65(6, Gx, Gy), 'K', 'serHybrid tag 06 y=Gy even: round trip')
add('SER', 'SER-G-H-07E',  ser65(7, Gx, Gy), 'K', 'tag 07 + even y: hybrid parity REJECT')
add('SER', 'SER-G-H-06O',  ser65(6, Gx, (P - Gy) % P), 'K', 'tag 06 + odd y: hybrid parity REJECT')
add('SER', 'SER-G-S1',     ser65(4, Gx, Gy), 'K', 'readBE (serUncompressed Gx Gy) 1 32 = Gx')
add('SER', 'SER-G-S2',     ser65(4, Gx, Gy), 'K', 'readBE (serUncompressed Gx Gy) 33 32 = Gy')
add('SER', 'SER-G-S3',     ser65(4, Gx, Gy), 'K', 'byteAt (serUncompressed Gx Gy) 0 = 4')
add('SER', 'SER-G-S4',     ser65(4, Gx, Gy), 'K', 'blen (serUncompressed Gx Gy) = 65')
# s11-s13: pkform-000..009 round trips + tag-mismatch mutants
for i in range(10):
    b = h(PKFORM[i]); x = int.from_bytes(b[1:33], 'big'); y = int.from_bytes(b[33:65], 'big')
    tag = b[0]
    add('SER', 'SER-P%03d-U' % i, ser65(4, x, y), 'K', 'pkform-%03d: parse(serUncompressed) round trip (04)' % i)
    add('SER', 'SER-P%03d-H' % i, ser65(7 if y % 2 else 6, x, y), 'K', 'pkform-%03d: parse(serHybrid auto-tag) round trip' % i)
    add('SER', 'SER-P%03d-M' % i, ser65((7 if y % 2 == 0 else 6), x, y), 'K',
        'pkform-%03d: tag-parity MISMATCH (0x%02X, y %s) -> none'
        % (i, (7 if y % 2 == 0 else 6), 'odd' if y % 2 else 'even'))

# ---------------- U4 PubKeyCorVec — BIP340/341 + negatives ----------------
add('VEC', 'B340-14-33B',  ser33(2, int(X14, 16)), 'K', 'row-14 pk (x = P+1 >= P) 33B tag 02: none')
add('VEC', 'B340-14-65U',  ser65(4, int(X14, 16), 0), 'K', 'row-14 x 65B tag 04 (y=0^32 SYNTH): none (x>=P)')
add('VEC', 'B340-14-65H',  ser65(6, int(X14, 16), 0), 'K', 'row-14 x 65B tag 06 (y=0^32 SYNTH): none (x>=P)')
add('VEC', 'B340-12R-33B', ser33(2, int(RD12, 16)), 'K', 'row-12 sig[0:32] = r = P (field size) as 33B x: none (x>=P)')
add('VEC', 'B340-5-65U',   ser65(4, int(D69C, 16), int(DFF1, 16)), 'K', 'row-5 pk (non-residue x) 65B tag 04, y=row-1 pk (SYNTH): none (off-curve)')
add('VEC', 'B340-1-65U',   ser65(4, int(DFF1, 16), Gy), 'K', 'row-1 pk (valid x) 65B tag 04, y=Gy (SYNTH): none (off-curve)')
add('VEC', 'B340-5-33B',   ser33(2, int(D69C, 16)), 'R6', 'row-5 pk (non-residue x) 33B tag 02: none (ge_set_xo_var reject)')
add('VEC', 'B340-0-33B',   ser33(2, int(pkc['0'], 16)), 'R6', 'row-0 pk (valid x) 33B tag 02: some')
add('VEC', 'B340-1-33B',   ser33(2, int(DFF1, 16)), 'R6', 'row-1 pk (valid x) 33B tag 02: some')
add('VEC', 'B340-1-33BO',  ser33(3, int(DFF1, 16)), 'R6', 'row-1 pk 33B tag 03: some (odd root)')
add('VEC', 'B340-15-33B',  ser33(3, int(r15, 16)), 'R6', 'row-15 pk (valid x) 33B tag 03: some')
# BIP341 (wallet-test-vectors v1, scriptPubKey case 1)
add('VEC', 'B341-X-32B',   h(TWD), 'K', 'tweakedPubkey raw xonly 32B: none (blen 32 != 33/65; taproot keys are NOT CPubKeys)')
add('VEC', 'B341-SPK-34B', h(spkhex), 'K', 'expected scriptPubKey 5120||tweaked (34B): none (blen)')
add('VEC', 'B341-T65-51',  ser65(0x51, int(TWD, 16), int(TWEAK, 16)), 'K', 'tag 0x51 (65B, spk version byte) x=tweaked y=tweak (SYNTH): none (tag)')
add('VEC', 'B341-I65U-0',  ser65(4, int(INTL, 16), 0), 'K', 'internalPubkey 65B tag 04 y=0^32 (SYNTH): none (off-curve)')
add('VEC', 'B341-I33B',    ser33(2, int(INTL, 16)), 'R6', 'internalPubkey (valid x) 33B tag 02: some')
add('VEC', 'B341-T33B',    ser33(2, int(TWD, 16)), 'R6', 'tweakedPubkey (valid x) 33B tag 02: some (tweaked point on curve)')
add('VEC', 'B341-K33B',    ser33(2, int(TWEAK, 16)), 'R6', 'tweak (scalar as x) 33B tag 02: pyC truth')
add('VEC', 'B341-K65U-0',  ser65(4, int(TWEAK, 16), 0), 'K', 'tweak (scalar as x) 65B tag 04 y=0^32 (SYNTH): none (off-curve)')
# D: tag/prefix matrix on corpus keys (lengths defined by PubKeyMatrix)
for t in (0x00, 0x01, 0x05, 0x08, 0x7F, 0xFF):
    add('VEC', 'D-%02X-33' % t, ser33(t, int(DFF1, 16)), 'K', 'tag 0x%02X (33B, row-1 x): none (tag matrix)' % t)
    add('VEC', 'D-%02X-65' % t, ser65(t, int(DFF1, 16), int(D69C, 16)), 'K', 'tag 0x%02X (65B, row-1 x row-5 y): none (tag matrix)' % t)
add('VEC', 'D-FF-INV',     ser65(0xFF, int(DFF1, 16), int(D69C, 16)), 'K', 'tag 0xFF = CPubKey::Invalidate marker (pubkey.h:79-82): none')

# ------------------------------------------------------------------ the diff
bad = 0; krows = 0; r6rows = 0
print('%-14s %-11s %-18s %-18s %s' % ('id', 'kind', 'pyC', 'pyLean', 'note'))
print('-' * 100)
for unit, id, hexs, kind, note in rows:
    b = h(hexs)
    pc, pl = c_cpubkey_verify(b), (l_validsize(b) and l_parse(b) is not None)
    pcp = 'ok' if pc else 'no'; plp = 'ok' if pl else 'no'
    if pc != pl:
        bad += 1; print('MISMATCH', id, pcp, plp)
    if kind == 'K': krows += 1
    else: r6rows += 1
    print('%-14s %-11s %-18s %-18s %s' % (id, kind, pcp, plp, note))

# sanity: pyC truth of R6 rows printed in full for the .lean comment rows
print('\nR6 (pyC TRUTH) rows in full:')
for unit, id, hexs, kind, note in rows:
    if kind == 'R6':
        b = h(hexs); g = c_ge_parse(b)
        print('  %-14s ge_parse = %-60s validsize=%s cVerify=%s  # %s'
              % (id, fmt(g) if g else 'none', c_validsize(b), c_cpubkey_verify(b), note))

# pyLean-vs-pyLean33 detail for R6 rows (branch taken)
print('\ndecide-count: %d decide rows, %d R6 pyC rows, %d pyC/pyLean mismatches'
      % (krows, r6rows, bad))
sys.exit(1 if bad else 0)
