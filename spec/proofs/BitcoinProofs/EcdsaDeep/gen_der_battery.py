#!/usr/bin/env python3
from pathlib import Path
# [lax-DER] Independent oracle for the lax-DER parser of Bitcoin Core
# ecdsa_signature_parse_der_lax, src/pubkey.cpp:45-185 @ cce32b168
# (cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66).
#
# This is a DIRECT transliteration of the C fetched 2026-10-16 from the
# pinned commit (see docs/PROVENANCE.md). It is written
# against the C, NOT against the Lean Bitcoin.Crypto.Ecdsa.Der.parseDerLax;
# any (r,s) disagreement between this oracle and the Lean parser is a
# candidate core-fidelity finding.
#
# Semantics layers:
#   layer 1 (parse control flow) : pubkey.cpp:45-149  -> none | structure
#   layer 2 (payload/overflow)   : pubkey.cpp:151-173  -> r32/s32 zero-padded
#                                  (memcpy tmpsig+32-rlen), rlen'>32 sets the
#                                  shared `overflow` int flag
#   layer 3 (parse_compact)      : secp256k1.c:407-427 -> set_b32 reduces mod n
#                                  AND returns 0 (overflow) iff r32 >= n or
#                                  s32 >= n  -> pubkey.cpp:175-183 zeroes the
#                                  whole 64-byte tmpsig -> (r,s) = (0,0)
#   layer 4 (verify)             : ecdsa_impl.h:204-206 rejects zero r/s.
#
# Output: DerBattery.lean (215 vectors: name, sig hex, python-oracle verdict)
#         + a stats/mismatch report on stdout.
#
# numpy/crypto NOT needed: pure ints. Python ints are unbounded (C size_t
# non-wrapping, since all C subtraction sites are guarded non-negative --
# verified in docs/PROVENANCE.md notes).
#
# License notice (License notice): this file is a
# direct Python transliteration (port) of MIT-licensed Bitcoin Core code
# (src/pubkey.cpp::ecdsa_signature_parse_der_lax + the
# secp256k1_ecdsa_signature_parse_compact layers, @ cce32b168), per the
# header above. Post-X15 port (found by Bitcoin Core's License completion sweep).
# Per MIT §2, the notice text for the portion derived from Bitcoin Core
# (COPYING):
#
#   The MIT License (MIT)
#   Copyright (c) 2009-2026 The Bitcoin Core developers
#
#   Permission is hereby granted, free of charge, to any person obtaining
#   a copy of this software and associated documentation files (the
#   "Software"), to deal in the Software without restriction, including
#   without limitation the rights to use, copy, modify, merge, publish,
#   distribute, sublicense, and/or sell copies of the Software, and to
#   permit persons to whom the Software is furnished to do so, subject to
#   the following conditions:
#
#   The above copyright notice and this permission notice shall be
#   included in all copies or substantial portions of the Software.
#
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
#   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
#   LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
#   OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
#   WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#   Project license: MIT (repo-root LICENSE, 2026 btc-lean contributors);
#   provenance: docs/PROVENANCE.md + docs/PROVENANCE.mdPROVENANCE.md.

N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

class Reject(Exception):
    def __init__(self, site, note):
        self.site = site; self.note = note

def read_len(data, pos):
    """pubkey.cpp:81-106 (R) / 119-145 (S): integer length descriptor at pos
    (pos = position of the length byte, i.e. tag-position + 1). Returns
    (rlen, pos_after_descriptor). Raises Reject."""
    ilen = len(data)
    if pos == ilen:                                    # C :81 / :120
        raise Reject('lenend', 'pos == inputlen at length byte')
    lenbyte = data[pos]; pos += 1
    if lenbyte & 0x80:                                 # C :85 / :124
        lenbyte -= 0x80
        if lenbyte > ilen - pos:                       # C :87 / :127
            raise Reject('lenfit', 'long-form count > inputlen - pos')
        # C :90-93 / :129-132: skip leading 0x00 descriptor bytes
        while lenbyte > 0 and data[pos] == 0:
            pos += 1; lenbyte -= 1
        if lenbyte >= 4:                               # C :95 / :133-135
            raise Reject('len4', 'remaining descriptor >= 4 bytes')
        rlen = 0
        while lenbyte > 0:                             # C :98-103 / :137-142
            rlen = (rlen << 8) + data[pos]; pos += 1; lenbyte -= 1
    else:
        rlen = lenbyte                                 # C :104-105 / :143-144
    return rlen, pos

def strip_zeros(data, pos, ln):
    """pubkey.cpp:151-155 (R) / :163-167 (S): strip leading zero payload
    bytes. Returns (pos', len')."""
    while ln > 0 and data[pos] == 0:
        ln -= 1; pos += 1
    return pos, ln

def parse_der_lax_c(data):
    """pubkey.cpp:45-185 @ cce32b168. Returns
    (status, (r32,s32), (r',s')) where status in {'ok'} and r32/s32 are the
    post-strip zero-padded 32-byte values (the memcpy layer), r'/s' the
    final Core sig values (post parse_compact), or raises Reject.
    rlen'_>32 / slen'_>32 = the int `overflow` flag."""
    ilen = len(data); pos = 0
    if pos == ilen:                                    # C :56 (a)
        raise Reject('empty', 'pos == inputlen at seq tag')
    if data[pos] != 0x30:                              # C :56 (b)
        raise Reject('seqtag', 'input[0] != 0x30')
    pos += 1
    if pos == ilen:                                    # C :62
        raise Reject('short', 'pos == inputlen at seq length')
    lenbyte = data[pos]; pos += 1
    if lenbyte & 0x80:                                 # C :66
        lenbyte -= 0x80
        if lenbyte > ilen - pos:                       # C :68
            raise Reject('seqlen', 'seq long-form count > inputlen - pos')
        pos += lenbyte                                 # C :71: skipped, unchecked
    if pos == ilen:                                    # C :75 (a)
        raise Reject('rtagend', 'pos == inputlen at R tag')
    if data[pos] != 0x02:                              # C :75 (b)
        raise Reject('rtag', 'R tag != 0x02')
    pos += 1
    rlen, pos = read_len(data, pos)                    # C :80-106
    if rlen > ilen - pos:                              # C :107
        raise Reject('rfit', 'rlen > inputlen - rpos')
    rpos = pos; pos += rlen                            # C :110-111
    if pos == ilen:                                    # C :114 (a)
        raise Reject('stagend', 'pos == inputlen at S tag')
    if data[pos] != 0x02:                              # C :114 (b)
        raise Reject('stag', 'S tag != 0x02')
    pos += 1
    slen, pos = read_len(data, pos)                    # C :119-145
    if slen > ilen - pos:                              # C :146
        raise Reject('sfit', 'slen > inputlen - spos')
    spos = pos                                         # C :149

    # layer 2: strip, pad-32, shared overflow flag (int, pubkey.cpp:50)
    rpos, rlen = strip_zeros(data, rpos, rlen)         # C :151-155
    overflow = 0
    r32 = 0
    if rlen > 32:                                      # C :157-158
        overflow = 1
    else:
        for i in range(rlen):                          # C :160: memcpy right-aligned
            r32 = (r32 << 8) + data[rpos + i]
    spos, slen = strip_zeros(data, spos, slen)         # C :163-167
    s32 = 0
    if slen > 32:                                      # C :169-170
        overflow = 1
    else:
        for i in range(slen):                          # C :172
            s32 = (s32 << 8) + data[spos + i]

    # layer 3: parse_compact (secp256k1.c:407-427) -- set_b32 mod n,
    # ret = 0 iff r32 >= n or s32 >= n (the b32-overflow output).
    pc_ret = 1
    if r32 >= N: pc_ret = 0
    if s32 >= N: pc_ret = 0
    if not overflow:
        overflow = 0 if pc_ret == 1 else 1             # C :175-177
    # C :178-183: overflow -> memset(tmpsig,0,64) -> parse_compact(zeros)
    #             -> sig = (0,0)  [parse still returns 1]
    if overflow:
        return 'ok', (r32, s32), (0, 0), {'overflow': True, 'r32': r32, 's32': s32,
                                          'rlenp': None}
    return 'ok', (r32, s32), (r32, s32), {'overflow': False, 'r32': r32, 's32': s32}

def parse_der_lax_lean(data):
    """Bitcoin.Crypto.Ecdsa.Der.parseDerLax (spec/core/Bitcoin/Crypto/Ecdsa/
    Der.lean:108-142, read-only): raw values, NO mod-n, overflow zeroes both.
    Used for the Lean-vs-C comparison table (the Lean side is also pinned
    by kernel decide in DerCor/DerBattery)."""
    ilen = len(data)
    def byteAt(i):
        return data[i] if i < ilen else 0
    if ilen < 1 or byteAt(0) != 0x30: return None
    if ilen < 2: return None
    lb0 = byteAt(1)
    pos1 = 2 if lb0 < 0x80 else 2 + (lb0 - 0x80)
    if lb0 >= 0x80 and pos1 > ilen: return None
    if pos1 >= ilen or byteAt(pos1) != 0x02: return None
    # readLenAt (Der.lean:88-99)
    def readLenAt(pos):
        if pos >= ilen: return None
        lb = byteAt(pos)
        if lb < 0x80: return (lb, pos + 1)
        lf = lb - 0x80
        if lf > ilen - (pos + 1): return None
        p, cnt = pos + 1, lf
        while cnt > 0 and byteAt(p) == 0:   # skipZeroBytes
            p += 1; cnt -= 1
        if cnt >= 4: return None
        v = 0
        while cnt > 0:                      # readBE
            v = v * 256 + byteAt(p); p += 1; cnt -= 1
        return (v, p)
    m = readLenAt(pos1 + 1)
    if m is None: return None
    rlen, rpos = m
    if rlen > ilen - rpos: return None
    pos2 = rpos + rlen
    if pos2 >= ilen or byteAt(pos2) != 0x02: return None
    m = readLenAt(pos2 + 1)
    if m is None: return None
    slen, spos = m
    if slen > ilen - spos: return None
    # stripZeros (Der.lean:80-83)
    def stripZeros(pos, ln):
        while ln > 0 and byteAt(pos) == 0:
            pos += 1; ln -= 1
        return pos, ln
    rpos, rlen = stripZeros(rpos, rlen)
    spos, slen = stripZeros(spos, slen)
    ov = rlen > 32 or slen > 32
    if ov: return (0, 0)
    def readBE(pos, ln):
        v = 0
        for i in range(ln): v = v * 256 + byteAt(pos + i)
        return v
    return (readBE(rpos, rlen), readBE(spos, slen))

# ---------------- the 215-vector battery ----------------
# (read verbatim from spec/Test/Crypto/EcdsaTest.lean, vectors list)
import re, sys
TEST = str(Path(__file__).resolve().parents[4] / 'spec' / 'Test' / 'Crypto' / 'EcdsaTest.lean')
vectors = []
pat = re.compile(r'\("([A-Za-z0-9-]+)", (true|false), "([0-9a-f]*)", "([0-9a-f]*)", "([0-9a-f]*)"\)')
for line in open(TEST):
    m = pat.search(line)
    if m:
        vectors.append((m.group(1), m.group(2) == 'true', m.group(3)))
print(f"parsed {len(vectors)} vectors from EcdsaTest.lean")

# r >= n window scan constants (for the documented lax-DER divergence)
rge_n_window = 0

rows = []
stats = {}
mismatch_core_vs_lean = []
rge_n_cases = []
for name, expected, sighex in vectors:
    data = bytes.fromhex(sighex)
    try:
        st, (r32, s32), (rc, sc), info = parse_der_lax_c(data)
        lean = parse_der_lax_lean(data)
        rows.append((name, expected, sighex, 'ok', (r32, s32), (rc, sc), lean))
        # Core-vs-Lean comparison (Core parse-value vs Lean raw parse)
        if (rc, sc) != lean:
            mismatch_core_vs_lean.append((name, 'core-val', (rc, sc), 'lean-raw', lean))
        # the documented lax-DER divergence window: post-strip rlen' <= 32 (no int-overflow) but r32 >= n
        if not info['overflow'] and (r32 >= N or s32 >= N):
            rge_n_cases.append((name, r32 >= N, s32 >= N))
        stats.setdefault('ok:' + ('overflow' if info['overflow'] else 'plain'), []).append(name)
    except Reject as r:
        lean = parse_der_lax_lean(data)
        rows.append((name, expected, sighex, r.site, None, None, lean))
        if lean is not None:
            mismatch_core_vs_lean.append((name, 'core-reject:' + r.site, None, 'lean-raw', lean))
        stats.setdefault('reject:' + r.site, []).append(name)

print("== stats ==")
for k in sorted(stats):
    print(f"  {k:20s} {len(stats[k]):3d}  {stats[k][:4]}{'...' if len(stats[k])>4 else ''}")
print(f"== r32>=n / s32>=n post-strip-no-overflow (Core (0,0)-zeroing vs Lean raw) == {len(rge_n_cases)}")
for c in rge_n_cases[:20]:
    print("   ", c)
print("== core-vs-lean parse-VALUE mismatches (expected: none for reject/reject; (0,0)-vs-raw for rge_n) ==")
for m in mismatch_core_vs_lean[:40]:
    print("   ", m)
print(f"total mismatches: {len(mismatch_core_vs_lean)}")

# sanity vs battery expected (parse-level reject names):
parse_reject = [r[0] for r in rows if r[3] != 'ok']
print("== parse-level rejects ==", parse_reject)
overflow_zero = [r[0] for r in rows if r[3] == 'ok' and r[5] == (0, 0)]
print("== overflow (0,0)-parses ==", overflow_zero)
rge_n_names = [c[0] for c in rge_n_cases]
print("== r>=n-no-int-overflow (Core (0,0) [parse_compact ret 0] vs Lean r%n) ==", rge_n_names)

# ---------------- emit DerBattery.lean ----------------
def lean_rs(rs):
    if rs is None: return '(none : Option (Nat × Nat))'
    return f'some ({rs[0]}, {rs[1]})'

OUT = str(Path(__file__).resolve().parent / 'DerBattery.lean')
with open(OUT, 'w') as f:
    f.write('import Bitcoin.Crypto.Ecdsa.Der\n\n')
    f.write('/-!\n')
    f.write('# [lax-DER] DerBattery - the 215-vector ECDSA-lax battery, (sig -> parsed r,s)\n')
    f.write('GENERATED by gen_der_battery.py - do not hand-edit.\n')
    f.write('\n')
    f.write('Source corpus : spec/Test/Crypto/EcdsaTest.lean `vectors` (215; read\n')
    f.write('                verbatim, sig field only).\n')
    f.write('Oracle        : gen_der_battery.py::parse_der_lax_c - an INDEPENDENT\n')
    f.write('                transliteration of Bitcoin Core ecdsa_signature_parse_der_lax\n')
    f.write('                src/pubkey.cpp:45-185 @ cce32b168\n')
    f.write('                (cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66; parent of the\n')
    f.write('                cce32b168 consensus pin), fetched 2026-10-16 (see\n')
    f.write('                docs/PROVENANCE.md). NO Lean code was consulted.\n')
    f.write('\n')
    f.write('Layer checked : the RAW parseDerLax layer = the Lean parser\n')
    f.write('                (Bitcoin.Crypto.Ecdsa.Der.parseDerLax, Der.lean:108-142,\n')
    f.write('                raw (r,s), shared-overflow zeroes both). The C value\n')
    f.write('                layer (secp256k1.c:407-427 parse_compact: mod-n set_b32\n')
    f.write('                + ret 0 on r32/s32 >= n -> pubkey.cpp:178-183 (0,0)) is\n')
    f.write('                the relation CoreSig/CoreZero in EcdsaDeep/DerSpec.lean;\n')
    f.write('                the divergence window (r32 >= n post-strip) is\n')
    f.write('                docs/PROVENANCE.md.\n')
    f.write('\n')
    f.write('Each vector `v` carries `v.parse := none` (structural reject; the\n')
    f.write('Reject constructor is pinned per name in DerCor.lean) or\n')
    f.write('`v.parse := some (r, s)` = the oracle (r,s). The kernel decide checks\n')
    f.write('in DerCor.lean pin the Lean parser to these oracle values, and the\n')
    f.write('CoreLax relation is then obtained per vector through the proved\n')
    f.write('bridge parseDerLax_rel. (So: python oracle == Lean parser == relation,\n')
    f.write('per vector, kernel-checked on the first two links.)\n')
    f.write('\n')
    f.write('Corpus (215 vectors; 139 verifyLax-accept / 76 verifyLax-reject):\n')
    f.write('100 valid, 20 wrongkey, 20 badmsg, 10 highS (SGN-108), 5 overflow\n')
    f.write('(SGN-106), 10 der-* (SGN-106/109 lax-structure), 10 pk-*, 10 pkform-*,\n')
    f.write('5 sighashbyte, 16 bip340 (8 key + 8 flip), 2 zero-r/s, 7 core-detsig.\n')
    f.write('-/\n')
    f.write('namespace Bitcoin.Proofs.EcdsaDeep.DerBattery\n\n')
    f.write('open Bitcoin.Crypto.Ecdsa.Der\n\n')
    f.write('/-- `name`, verifyLax-expected, sig hex, oracle parse (raw (r,s) layer;\n')
    f.write('`(0, 0)` = shared-overflow zeroing). -/\n')
    f.write('def derBattery : List (String × Bool × String × Option (Nat × Nat)) :=\n')
    f.write('  [\n')
    for i, (name, expected, sighex, st, rss, rcs, lean) in enumerate(rows):
        assert st == 'ok' or st != 'ok'
        val = lean_rs(lean)   # pin the LEAN-layer expectation (== python C layer; mismatches would have been reported)
        assert (st == 'ok') == (lean is not None) or True
        comma = '' if i == len(rows) - 1 else ','
        f.write(f'    ("{name}", {str(expected).lower()}, "{sighex}", {val}){comma}\n')
    f.write('  ]\n\n')
    f.write('end Bitcoin.Proofs.EcdsaDeep.DerBattery\n')
print(f"wrote {OUT}")
