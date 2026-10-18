#!/usr/bin/env python3
from pathlib import Path
"""
Y11 reference — PoW/bits compact-encoding codec (nBits).

Ground truth: Bitcoin Core @ c50817febede99c8... (v32.99 master pin used by
W3/W4), src/arith_uint256.cpp:
  * arith_uint256::SetCompact(nCompact, pfNegative, pfOverflow)  (:176-194)
  * base_uint<BITS>::bits()                                      (:155-168)
  * arith_uint256::GetCompact(fNegative)                         (:196-215)
  * base_uint<256> semantics: all arithmetic is MOD 2^256 (shift-left drops
    high bits) and GetLow64() takes the low 64 bits.
Consensus consumers: src/pow.cpp (CheckProofOfWork rejects fNegative ||
fOverflow || target==0 || target > powLimit), consensus/params.h powLimit
(0xffff * 2^208).

This file is INDEPENDENT of the Lean tree: it is the generator of both the
case corpus and the Lean file spec/proofs/BitcoinProofs/Property/Y11/PowBits.lean
(deterministic; seed 20261016). Run: python3 powbits_reference.py
"""

import json
import random

SEED = 20261016
MOD256 = 1 << 256


def bits_of(t: int) -> int:
    """base_uint<256>::bits() — position of the highest set bit + 1; 0 for 0."""
    return t.bit_length()


def set_compact(ncompact: int):
    """Returns (magnitude_mod_2^256, magnitude_unbounded, negative, overflow).

    magnitude_mod_2^256 is what Core actually stores in the arith_uint256
    (256-bit wraparound); magnitude_unbounded is the mathematical value the
    Lean `compactTarget : Nat` computes. They agree iff the decode is
    non-overflow (see docs/PROVENANCE.md).
    """
    nsize = ncompact >> 24
    nword = ncompact & 0x007FFFFF
    if nsize <= 3:
        nword >>= 8 * (3 - nsize)
        mag = nword
    else:
        mag = nword << (8 * (nsize - 3))          # unbounded int
    mag256 = mag % MOD256                          # base_uint<256> truncation
    negative = nword != 0 and (ncompact & 0x00800000) != 0
    overflow = nword != 0 and ((nsize > 34) or
                               (nword > 0xFF and nsize > 33) or
                               (nword > 0xFFFF and nsize > 32))
    return mag256, mag, negative, overflow


def get_compact(t: int, f_negative: bool = False) -> int:
    """arith_uint256::GetCompact — the unbounded-int analogue (asserts hold
    for every t < 2^256; the sign-bump keeps the mantissa <= 0x7fffff)."""
    nsize = (bits_of(t) + 7) // 8
    if nsize <= 3:
        ncompact = (t % (1 << 64)) << (8 * (3 - nsize))
    else:
        ncompact = (t >> (8 * (nsize - 3))) % (1 << 64)
    if ncompact & 0x00800000:
        ncompact >>= 8
        nsize += 1
    assert ncompact & ~0x007FFFFF == 0, hex(ncompact)
    assert nsize < 256
    ncompact |= nsize << 24
    ncompact |= (1 << 23) if (f_negative and (ncompact & 0x007FFFFF)) else 0
    return ncompact


POW_LIMIT = 0xFFFF * 256 ** 26          # mainnet/testnet3/testnet4 (BLK-040)
DIFFICULTY_ONE = 0xFFFF * 256 ** 29     # compactTarget 0x1d00ffff

# Real mainnet nBits, byte-extracted from the validated anchor blocks
# (spec/vectors/anchors/<h>.raw, bytes 72..76 LE) — VERIFIED on-chain data.
ANCHOR_NBITS = [
    (0,      0x1D00FFFF),
    (74638,  0x1C00800E),
    (91842,  0x1B0E7256),
    (91880,  0x1B0E7256),
    (481824, 0x18013CE9),
    (709632, 0x170C69EA),
]


def main():
    cases = []          # (id, section, kind, payload)
    rng = random.Random(SEED)

    # ---- Section A: decode, systematic edges -------------------------------
    A = [
        0x00000000,  # size 0, word 0            -> target 0
        0x01000000,  # size 1, word 0            -> 0
        0x03000000,  # size 3, word 0            -> 0
        0x00FFFFFF,  # size 0: word 0x7fffff >> 24 = 0 -> 0 (word shifts away)
        0x01FFFFFF,  # size 1: word >> 16        -> 0xff
        0x02FFFFFF,  # size 2: word >> 8         -> 0xffff
        0x037FFFFF,  # size 3: identity          -> 0x7fffff
        0x04000001,  # size 4: word << 8         -> 0x100
        0x04008000,  # sign bit set in mantissa, magnitude unaffected
        0x04800001,  # sign bit set, nonzero word -> negative = True
        0x1B0E7256 & 0xFF8FFFFF | 0x00800000,  # anchor mantissa + sign bit
        0x1D00FFFF,  # difficulty 1 (genesis)
        0x1D00FFFF ^ 0x00800000,  # 0x1d80ffff: negative flag, same magnitude
        0x207FFFFF,  # nSize 32 NOT-overflow boundary (32>32 false; = Core test 0x20123456)
        0x2100FFFF,  # size 33, word 0xffff: NOT overflow, 2^240 boundary
        0x21010000,  # size 33, word 0x10000: overflow begins
        0x220000FF,  # size 34, word 0xff: NOT overflow, 255*2^248 max OK
        0x22000100,  # size 34, word 0x100: overflow (word > 0xff)
        0x23000001,  # size 35: overflow, AND magnitude 2^256 wraps to 0 in Core
        0xFF7FFFFF,  # size 255: extreme overflow
        0x170C69EA,  # anchor 709632
        0x18013CE9,  # anchor 481824
        0x1B0E7256,  # anchor 91842/91880
        0x1C00800E,  # anchor 74638 (mantissa 0x00800e, sign-clear)
        0x1C00FFFF,  # difficulty-1 mantissa at size 0x1c
        0x1C011804,  # early-chain real nBits (block ~74600 family)
        0x03012345,  # size 3 with mid word
        0x01012345,  # size 1: word >> 16 = 0x01
        0x00008000,  # size 0, word 0x8000 -> >>24 = 0
        0x2ABCDEF1,  # pseudo-random large size (0x2a = 42, overflow)
        0x0B000009,  # tiny size 11, word 9
    ]
    for i, c in enumerate(A):
        m256, munb, neg, ovf = set_compact(c)
        cases.append(dict(id=f"A{i:02d}", sec="A-decode-edge", nbits=c,
                          target_lean=munb, target_core=m256,
                          negative=neg, overflow=ovf))

    # ---- Section B: decode, real anchors + difficulty landmarks ------------
    B = [
        (0, 0x1D00FFFF), (74638, 0x1C00800E), (91842, 0x1B0E7256),
        (91880, 0x1B0E7256), (481824, 0x18013CE9), (709632, 0x170C69EA),
    ]
    for h, c in B:
        m256, munb, neg, ovf = set_compact(c)
        assert not neg and not ovf and m256 == munb
        cases.append(dict(id=f"B-{h}", sec="B-decode-anchor", height=h, nbits=c,
                          target_lean=munb, target_core=m256,
                          negative=neg, overflow=ovf))

    # ---- Section C: decode, seeded random ----------------------------------
    # C0*: realistic band (exponent 0x15..0x21, random mantissa — the shape
    #      of on-chain nBits, all non-overflow);
    # C1*: fully-random 32-bit (mostly overflow-flagged — negative space).
    for i in range(12):
        c = (rng.randrange(0x15, 0x22) << 24) | rng.randrange(0, 1 << 23)
        m256, munb, neg, ovf = set_compact(c)
        assert not neg and not ovf and m256 == munb
        cases.append(dict(id=f"C0{i:02d}", sec="C-decode-rand", nbits=c,
                          target_lean=munb, target_core=m256,
                          negative=neg, overflow=ovf))
    for i in range(12):
        c = rng.randrange(0, 1 << 32)
        m256, munb, neg, ovf = set_compact(c)
        cases.append(dict(id=f"C1{i:02d}", sec="C-decode-rand", nbits=c,
                          target_lean=munb, target_core=m256,
                          negative=neg, overflow=ovf))

    # ---- Section D: encode, systematic edges -------------------------------
    D = [
        0,                       # -> 0x00000000 (nSize 0)
        1,                       # -> 0x01000000
        0xFF,                    # -> 0x01ff0000
        0x100,                   # -> 0x02000100
        0xFFFF,                  # -> 0x02ffff00
        0x10000,                 # -> 0x03000100
        0x7FFFFF,                # -> 0x037fffff
        0x800000,                # bit 23 set -> sign-bump -> 0x04008000
        0xFFFFFF,                # -> 0x0400ffff
        0x1000000,               # -> 0x05010000
        0x123456789ABCDEF0,      # 65 bits
        0xFF00000000000000,      # 64-bit top
        DIFFICULTY_ONE // 256,   # target one mantissa shrunk
        DIFFICULTY_ONE,          # -> 0x1d00ffff round trip
        DIFFICULTY_ONE * 2,      # -> 0x1d01ffff
        POW_LIMIT,               # -> 0x1d00ffff
        POW_LIMIT + 1,           # mantissa rounding at the top
        2 ** 240,                # -> 0x21010000
        2 ** 248 - 1,            # 31 bytes of 0xff
        2 ** 255,                # -> 0x22008000 -> sign-bump 0x220080 -> 0x22008000? (compute)
        2 ** 256 - 1,            # all-ones
    ]
    for i, t in enumerate(D):
        c = get_compact(t)
        m256, munb, neg, ovf = set_compact(c)
        cases.append(dict(id=f"D{i:02d}", sec="D-encode-edge", target=t,
                          nbits_lean=None, nbits_core=c,
                          target_lean=munb, target_core=m256,
                          negative=neg, overflow=ovf))

    # ---- Section E: encode, seeded random targets (including big ones) -----
    for i in range(24):
        b = rng.randrange(1, 257)
        t = rng.getrandbits(b)
        c = get_compact(t)
        m256, munb, neg, ovf = set_compact(c)
        assert not neg and not ovf and m256 == munb   # encode of t < 2^256
        cases.append(dict(id=f"E{i:02d}", sec="E-encode-rand", target=t,
                          nbits_lean=None, nbits_core=c,
                          target_lean=munb, target_core=m256,
                          negative=neg, overflow=ovf))

    # ---- Section F: roundtrips ---------------------------------------------
    # F1: decode(getCompact(t)) == rounded t, for seeded random t
    for i in range(12):
        b = rng.randrange(1, 257)
        t = rng.getrandbits(b)
        c = get_compact(t)
        m256, munb, neg, ovf = set_compact(c)
        assert not neg and not ovf
        cases.append(dict(id=f"F1-{i:02d}", sec="F1-roundtrip-de",
                          target=t, nbits_core=c, target_lean=munb,
                          target_core=m256, negative=neg, overflow=ovf))
    # F2: getCompact(compactTarget(bits)) — fixed point on canonical inputs
    F2 = [0x1D00FFFF, 0x1C00800E, 0x1B0E7256, 0x18013CE9, 0x170C69EA,
          0x03FFFFFF, 0x207FFFFF, 0x2100FFFF, 0x1D80FFFF, 0x1C011804]
    for i, c0 in enumerate(F2):
        m256, munb, neg, ovf = set_compact(c0)
        c1 = get_compact(munb)          # Lean: getCompact (compactTarget bits)
        cases.append(dict(id=f"F2-{i:02d}", sec="F2-roundtrip-ed",
                          nbits=c0, nbits_core=c1, target_lean=munb,
                          target_core=m256, negative=neg, overflow=ovf))

    # ---- Section G: negative space — overflow-flagged decodes --------------
    # Core truncates the magnitude mod 2^256 AND raises fOverflow; Lean
    # compactTarget : Nat computes the unbounded value and exposes no flags.
    G = [0x23000001, 0x23008000, 0x22000100, 0x21010000, 0x207FFFFF,
         0x30000001, 0xFF7FFFFF, 0x1D80FFFF, 0x04800001]
    for i, c in enumerate(G):
        m256, munb, neg, ovf = set_compact(c)
        cases.append(dict(id=f"G{i:02d}", sec="G-negspace", nbits=c,
                          target_lean=munb, target_core=m256,
                          negative=neg, overflow=ovf))

    import os
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "cases.json"), "w") as f:
        json.dump(cases, f, indent=1)
    print(f"{len(cases)} cases -> cases.json")

    # ---- Divergence audit (Lean Nat vs Core 256-bit) ------------------------
    divs = [c for c in cases if c["target_lean"] != c["target_core"]]
    print("Lean-vs-Core magnitude divergences:",
          [(c["id"], hex(c["nbits"])) for c in divs])

    emit_lean(cases)


# ---------------------------------------------------------------------------
# Lean emission
# ---------------------------------------------------------------------------

HEADER = '''import Bitcoin.Chain.Basic
import Bitcoin.Block.Pow

/-!
# Y11 property-test corpus — PoW/bits (nBits compact decode/encode)

Independent reference implementation generated from the cited Bitcoin Core semantics.

Ground truth: Bitcoin Core `arith_uint256.cpp` @ `c50817f` (v32.99 master
pin; fetched from github.com/bitcoin/bitcoin at that commit):
`arith_uint256::SetCompact` (arith_uint256.cpp:176-194 — exponent byte,
0x007fffff mantissa, `nSize <= 3` right-shift arm, sign/overflow flags),
`base_uint::bits()` (:155-168), `arith_uint256::GetCompact` (:196-215 —
`CeilDiv(bits,8)` size, low-64 mantissa, 0x00800000 sign-bump re-encode),
with base_uint<256> wraparound semantics. The corpus was generated by the
plain-python reference `powbits_reference.py` (repo copy in this dir,
seed 20261016, REPRODUCIBLE — regenerates this file byte-for-byte; the
generator is kept with the corpus) and is independent of
the Lean implementation. Real-anchor nBits were byte-extracted from the
validated anchor headers (spec/vectors/anchors/*.raw, bytes 72-76
LE): heights 0, 74638, 91842, 91880, 481824, 709632.

Sections (137 cases + 5 named theorem instances, all kernel `decide`-checkable):
  A  `compactTarget` decode edges vs python `set_compact` magnitude
  B  decode of the six REAL mainnet anchor nBits
  C  decode, pseudo-random 32-bit nBits (fixed seed)
  D  `getCompact` encode edges vs python `get_compact`
  E  encode, pseudo-random targets up to 2^256 (fixed seed)
  F1 decode∘encode roundtrips; F2 encode∘decode roundtrips
  G  negative space: overflow-flagged nBits (Lean unbounded Nat vs Core
     256-bit truncation — see docs/PROVENANCE.md)

KNOWN DIVERGENCE (pinned in G, PROPOSED-side from python, VERIFIED-side
Lean computes exactly the unbounded value): for overflow-flagged nBits
(size ≥ 0x23, or size 0x22 with mantissa > 0xff, or size 0x21 with
mantissa > 0xffff) Core's stored magnitude WRAPS mod 2^256 while Lean's
`compactTarget : Nat` does not; Core rejects those via the fOverflow flag
in CheckProofOfWork, but `permittedDifficultyTransition` decodes newBits
without flag checks, so the divergence is reachable there.
-/

namespace BitcoinProofs.Property.Y11.PowBits

open Bitcoin.Chain Bitcoin.Block.Pow

set_option maxRecDepth 10000
set_option maxHeartbeats 2000000

/-! ## A. decode edges (python `set_compact` magnitude, unbounded arm) -/
'''

FOOTER = '''/-! ## Corpus size audit -/
-- total generated cases: {N} (see cases.json, repo copy, for the full table)

end BitcoinProofs.Property.Y11.PowBits
'''


def emit_lean(cases):
    out = [HEADER]
    n = 0

    def dec(line):
        return f"example : {line} := by decide\n"

    # A + C: decode vectors — assert Lean compactTarget equals python target
    out.append("\n/-! ### A. systematic decode edges -/\n\n")
    for c in cases:
        if c["sec"] == "A-decode-edge":
            n += 1
            out.append(dec(
                f"compactTarget (0x{c['nbits']:08x} : UInt32) = {c['target_lean']}"))
    out.append("\n/-! ### B. real mainnet anchor nBits (validated headers) -/\n\n")
    for c in cases:
        if c["sec"] == "B-decode-anchor":
            n += 1
            out.append(dec(
                f"compactTarget (0x{c['nbits']:08x} : UInt32) = {c['target_lean']}"))
    out.append("\n/-! ### C. pseudo-random decode (seed 20261016) -/\n\n")
    for c in cases:
        if c["sec"] == "C-decode-rand":
            n += 1
            out.append(dec(
                f"compactTarget (0x{c['nbits']:08x} : UInt32) = {c['target_lean']}"))

    out.append("\n/-! ## D. encode edges (python `get_compact`) -/\n\n")
    for c in cases:
        if c["sec"] == "D-encode-edge":
            n += 1
            out.append(dec(
                f"getCompact {c['target']} = 0x{c['nbits_core']:08x}"))

    out.append("\n/-! ## E. pseudo-random encode (seed 20261016) -/\n\n")
    for c in cases:
        if c["sec"] == "E-encode-rand":
            n += 1
            out.append(dec(
                f"getCompact {c['target']} = 0x{c['nbits_core']:08x}"))

    out.append("\n/-! ## F. roundtrips -/\n\n/-! ### F1. decode ∘ encode -/\n\n")
    for c in cases:
        if c["sec"] == "F1-roundtrip-de":
            n += 1
            out.append(dec(
                f"compactTarget (getCompact {c['target']}) = {c['target_lean']}"))
    out.append("\n/-! ### F2. encode ∘ decode (fixed points on canonical inputs) -/\n\n")
    for c in cases:
        if c["sec"] == "F2-roundtrip-ed":
            n += 1
            out.append(dec(
                f"getCompact (compactTarget (0x{c['nbits']:08x} : UInt32)) "
                f"= 0x{c['nbits_core']:08x}"))

    out.append("\n/-! ## G. negative space: overflow-flagged nBits. Lean target =\n"
               "python UNBOUNDED magnitude; Core stores it mod 2^256 and raises\n"
               "fOverflow (both python values below; divergence ids in cases.json). -/\n\n")
    for c in cases:
        if c["sec"] == "G-negspace":
            n += 1
            out.append(dec(
                f"compactTarget (0x{c['nbits']:08x} : UInt32) = {c['target_lean']}"))
            if c["target_lean"] != c["target_core"]:
                out.append(f"-- Core (mod 2^256, fOverflow={str(c['overflow']).lower()}, "
                           f"fNegative={str(c['negative']).lower()}): {c['target_core']}\n")

    out.append("\n/-! ## Named theorem instances (axiom-audit handles; values\n"
               "cross-checked against the generated case corpus) -/\n\n")
    out.append("""/-- Real-anchor decode: genesis difficulty-1 (case B-0; matches core's
`compactTarget_difficulty_one`, proved there by `rfl`). -/
theorem anchor_decode_genesis :
    compactTarget (0x1d00ffff : UInt32) = 0xffff * 256 ^ 26 := by decide

/-- Real-anchor decode: block 481824 (case B-481824). -/
theorem anchor_decode_481824 :
    compactTarget (0x18013ce9 : UInt32) = 30353962581764818649842367179120467226026534727449575424 := by
  decide

/-- Real-anchor encode: the difficulty-1 target re-encodes to its own nBits
(case F2-00). -/
theorem anchor_roundtrip_genesis :
    getCompact (compactTarget (0x1d00ffff : UInt32)) = (0x1d00ffff : UInt32) := by
  decide

/-- Encode edge: mainnet powLimit re-encodes to difficulty-1 nBits (case D15). -/
theorem encode_powLimit :
    getCompact (0xffff * 256 ^ 26) = (0x1d00ffff : UInt32) := by
  decide

/-- Negative space: the 0x23000001 overflow divergence, Lean side pinned as a
named theorem (case G00; Core stores 0 and raises fOverflow — docs/PROVENANCE.md). -/
theorem negspace_overflow_23000001 :
    compactTarget (0x23000001 : UInt32) = 2 ^ 256 := by
  decide

""")

    out.append(FOOTER.format(N=len(cases)))
    path = str(Path(__file__).resolve().parent / 'PowBits.lean')
    with open(path, "w") as f:
        f.writelines(out)
    print(f"wrote {path} ({n} decide assertions + audit)")


if __name__ == "__main__":
    main()
