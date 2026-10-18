/-
BitcoinProofs.Bip.B15.Bip94Tests — decisive BIP94 (Testnet 4) + epoch-rule
kill-vectors, exercised against the TREE's implementation
(`Bitcoin.Block.Pow` BLK-040..055, `Bitcoin.Block.Index` BLK-113/114).

2026-10-16.

BIP94 consensus clauses audited (bip-0094.mediawiki, License CC0-1.0,
fetched from bitcoin/bips master 2026-10-16):
  C1  20-minute exception (BLK-053/054): non-period-first block with
      timestamp > 20 min past prev MUST be min-difficulty (nBits = the
      powLimit encoding 0x1d00ffff); walk-back to the last real-difficulty
      block otherwise; stops at genesis edge and at height%2016=0 blocks.
  C2  First block of a difficulty period MUST use actual computed
      difficulty — the boundary branch never consults the timestamp gap.
  C3  Block-storm fix (BLK-047): retarget base = FIRST block of the
      previous period iff enforce_BIP94 (testnet4), else LAST block;
      clamp [T/4, 4T] and powLimit cap unchanged (BLK-045/048).
  C4  Time-warp guard (BLK-055): height%2016=0 ⇒ nTime ≥ prev nTime − 600
      (MAX_TIMEWARP, consensus/consensus.h:35); MTP (BLK-056/057) applies
      additionally on top.
Header arithmetic: nBits decode/encode is Y11's covered ground
(Property/Y11/PowBits.lean); this module covers the epoch rules above and
the chainwork layer (BLK-113/114) that BIP94's reorg rationale rests on.

Every expected value was computed by a python3 oracle — Core
arith_uint256/pow/chain semantics
@ cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66, big-int — and the oracle's
mutation matrix confirms each family distinguishes a mutated rule (clamp
1/4→1/5; overflow size>34→>35; timewarp 600→599).

All checks are `rfl`/`decide`/`native_decide`-closed; `native_decide` is
test-scoped only (house policy), the two `theorem`s are sorry-free and
avoid it (#print axioms below).
-/

import Bitcoin.Chain.Basic
import Bitcoin.Block.Pow
import Bitcoin.Block.Index

namespace BitcoinProofs.Bip.B15

open Bitcoin.Chain Bitcoin.Block.Pow Bitcoin.Block.Index

/-! ## Fixtures -/

/-- Testnet4 params (chainparams.cpp:364-368). -/
def tn4 : PowParams :=
  { powLimit := powLimitMainnet, fPowAllowMinDifficultyBlocks := true,
    enforceBIP94 := true }

/-- Testnet3-style params: same, but WITHOUT the BIP94 block-storm fix. -/
def tn3 : PowParams :=
  { powLimit := powLimitMainnet, fPowAllowMinDifficultyBlocks := true,
    enforceBIP94 := false }

def genesisTime : UInt32 := 1714777860   -- testnet4 genesis timestamp (BIP94)
def tFirst2 : UInt32 := genesisTime + 302400

/-- Index-node lookup from a dense height-indexed array. -/
def getOf (arr : Array IndexNode) : Nat → Option IndexNode := fun h => arr[h]?

/-- Storm chain (oracle §"block-storm"): period 1 = heights 0..2015 all
min-difficulty, timespan genesis→2015 exactly T/4; block 2016 (first of
period 2) at real difficulty bits 0x1c3fffc0 (target = powLimit/4);
heights 2017..4030 min-difficulty; block 4031 (last) min-difficulty, its
time exactly one full timespan T after block 2016's. -/
def stormArr : Array IndexNode :=
  (List.range 4032).map (fun h =>
    if h = 2016 then ({ bits := 0x1c3fffc0, time := tFirst2 } : IndexNode)
    else if h = 4031 then ({ bits := 0x1d00ffff, time := tFirst2 + 1209600 } : IndexNode)
    else if h ≤ 2015 then
      ({ bits := 0x1d00ffff,
         time := if h = 2015 then tFirst2
                 else genesisTime + 1 + UInt32.ofNat (302399 * h / 2015) } : IndexNode)
    else
      ({ bits := 0x1d00ffff,
         time := tFirst2 + 1 + UInt32.ofNat (1209599 * (h - 2017) / 2014) } : IndexNode))
  |>.toArray

/-- Period-1 chain ending at 2015 with total timespan exactly T/4
(the lower clamp edge): genesis at powLimit (bits 0x1d00ffff). -/
def quarterArr : Array IndexNode :=
  (List.range 2016).map (fun h =>
    ({ bits := if h = 0 then 0x1d00ffff else 0x1d00ffff,
       time := if h = 2015 then genesisTime + 302400
               else genesisTime + 1 + UInt32.ofNat (302399 * h / 2015) } : IndexNode))
  |>.toArray

/-- Like `quarterArr` but the period spans only 100000 s < T/4 — makes the
lower clamp arm observable. Base (first block) = powLimit/8, bits
0x1c1fffe0, so the clamped retarget lands at powLimit/32. -/
def fastArr : Array IndexNode :=
  (List.range 2016).map (fun h =>
    ({ bits := if h = 0 then 0x1c1fffe0 else 0x1d00ffff,
       time := if h = 2015 then genesisTime + 100000
               else genesisTime + 1 + UInt32.ofNat (99999 * h / 2015) } : IndexNode))
  |>.toArray

/-- Base = powLimit/8 (bits 0x1c1fffe0), period spanning 5T — makes the
upper clamp arm (4T) observable. -/
def slowArr : Array IndexNode :=
  (List.range 2016).map (fun h =>
    ({ bits := if h = 0 then 0x1c1fffe0 else 0x1d00ffff,
       time := if h = 2015 then genesisTime + 6048000
               else genesisTime + 1 + UInt32.ofNat (6047999 * h / 2015) } : IndexNode))
  |>.toArray

/-- Base = powLimit (genesis bits), period spanning exactly 4T — the
powLimit cap lands exactly at the clamp's upper edge. -/
def capArr : Array IndexNode :=
  (List.range 2016).map (fun h =>
    ({ bits := 0x1d00ffff,
       time := if h = 2015 then genesisTime + 4838400
               else genesisTime + 1 + UInt32.ofNat (4838399 * h / 2015) } : IndexNode))
  |>.toArray

/-- Heights 4999/5000 at real difficulty 0x1c3fffc0, 5001/5002 min-diff. -/
def gapArr : Array IndexNode :=
  #[ { bits := 0x1c3fffc0, time := 1719999400 }
   , { bits := 0x1c3fffc0, time := 1720000000 }
   , { bits := 0x1d00ffff, time := 1720000100 }
   , { bits := 0x1d00ffff, time := 1720000500 } ]

def gapGet : Nat → Option IndexNode := fun h => gapArr[h - 4999]?

/-- Heights 4031..4132 CONTIGUOUS (102 nodes): 4031 real-difficulty
(0x1c3fffc0), 4032 a min-difficulty BOUNDARY height, 4033..4132
min-difficulty — the walk-back must traverse every ancestor and stop at
4032, never reaching 4031's real bits. -/
def stopArr : Array IndexNode :=
  (List.range 102).map (fun i =>
    ({ bits := if i = 0 then 0x1c3fffc0 else 0x1d00ffff,
       time := 1719999000 + UInt32.ofNat (i * 100) } : IndexNode))
  |>.toArray

def stopGet : Nat → Option IndexNode := fun h => stopArr[h - 4031]?

/-! ## C3 — the block-storm fix (BLK-047): FIRST-block base vs LAST-block base

Both semantics run on the SAME chain; BIP94 preserves the period's real
difficulty 4, testnet3-style collapses to difficulty 1 (the storm). An
implementation with either semantics computes a different required nBits
for block 4032 — the decisive disagreement. -/

example : nextWorkRequired tn4 (getOf stormArr) 4031 (tFirst2 + 1209601)
    = some 0x1c3fffc0 := by native_decide

example : nextWorkRequired tn3 (getOf stormArr) 4031 (tFirst2 + 1209601)
    = some 0x1d00ffff := by native_decide

example : nextWorkRequired tn4 (getOf stormArr) 4031 (tFirst2 + 1209601) ≠
          nextWorkRequired tn3 (getOf stormArr) 4031 (tFirst2 + 1209601) := by
  native_decide

-- C2: at the boundary the min-difficulty exception does NOT apply — even a
-- >20-minute gap since block 4031 still requires the retargeted bits.
example : nextWorkRequired tn4 (getOf stormArr) 4031 (tFirst2 + 1709601)
    = some 0x1c3fffc0 := by native_decide

/-! ## C3 arithmetic: window anchor, clamp arms, cap (BLK-044/045/046/048) -/

-- BLK-044/045: block 2016 retargets from the genesis anchor; timespan T/4
-- (the exact lower clamp edge) ⇒ target powLimit/4.
example : nextWorkRequired tn4 (getOf quarterArr) 2015 (genesisTime + 302401)
    = some 0x1c3fffc0 := by native_decide

-- Lower clamp arm made visible: base powLimit/8, timespan 100000 < T/4
-- behaves like T/4 ⇒ powLimit/32 (0x1c07fff8), unlike the unclamped
-- powLimit/8·100000/T (oracle: 0x1c02a53d-ish, differs).
example : nextWorkRequired tn4 (getOf fastArr) 2015 (genesisTime + 100001)
    = some 0x1c07fff8 := by native_decide

-- Upper clamp arm: timespan 5T behaves like 4T ⇒ target (powLimit/8)·4 =
-- powLimit/2 (0x1c7fff80), NOT the uncapped powLimit·5/8 (0x1d009fff).
example : nextWorkRequired tn4 (getOf slowArr) 2015 (genesisTime + 6048001)
    = some 0x1c7fff80 := by native_decide

-- BLK-048 cap: base = powLimit over exactly 4T ⇒ exactly powLimit
-- (a no-cap mutant re-encodes 0x1d03fffc per the oracle).
example : nextWorkRequired tn4 (getOf capArr) 2015 (genesisTime + 4838401)
    = some 0x1d00ffff := by native_decide

-- BLK-049: fPowNoRetargeting copies the last nBits wholesale (regtest).
example : nextWorkRequired { tn4 with fPowNoRetargeting := true }
    (getOf stormArr) 4031 (tFirst2 + 1209601) = some 0x1d00ffff := by native_decide

-- BLK-043 copy arm (mainnet: no min-difficulty machinery): non-boundary
-- blocks copy pindexLast's nBits whatever the gap.
example : nextWorkRequired mainnetParams gapGet 5002 1720000550
    = some 0x1d00ffff := by native_decide

/-! ## C1 — 20-minute exception (BLK-053) and walk-back (BLK-054) -/

-- Gap exactly 1200 s: NOT an exception (strictly greater than 2× spacing).
example : nextWorkRequired tn4 gapGet 5000 1720001200 = some 0x1c3fffc0 := by native_decide

-- Gap 1201 s: MUST be min-difficulty. (Kill: `<` vs `≤` mutants flip V5/V6.)
example : nextWorkRequired tn4 gapGet 5000 1720001201 = some 0x1d00ffff := by native_decide

-- Gap 1199 s: real difficulty.
example : nextWorkRequired tn4 gapGet 5000 1720001199 = some 0x1c3fffc0 := by native_decide

-- BLK-054 walk-back: consecutive min-difficulty blocks fall back to the
-- last real-difficulty ancestor (5000), not the immediate predecessor.
example : nextWorkRequired tn4 gapGet 5002 1720000550 = some 0x1c3fffc0 := by native_decide

-- The walk-back STOPS at a height%2016=0 block even when that block itself
-- carries min-difficulty bits (4032) — 4031's real bits are never consulted.
example : nextWorkRequired tn4 stopGet 4132 1720000550 = some 0x1d00ffff := by
  native_decide

-- Immediate stop: pindexLast ITSELF is the min-difficulty boundary block —
-- the walk-back terminates there (kills a "walk one past the boundary"
-- mutant, which would return 4031's real bits 0x1c3fffc0).
example : nextWorkRequired tn4 stopGet 4032 1720000550 = some 0x1d00ffff := by
  native_decide

/-! ## C4 — time-warp guard (BLK-055): the −600 s edge -/

-- Exactly one spacing behind: LEGAL (kills a MAX_TIMEWARP=599 mutant, which
-- RC09's 700/700 and 99/700 smoke cases do not distinguish).
example : timewarpOk true true 100 700 = true := by rfl

-- One second past the guard: rejected.
example : timewarpOk true true 99 700 = false := by rfl

-- Non-boundary heights and non-BIP94 networks are unconstrained by C4.
example : timewarpOk true false 0 999999 = true := by rfl
example : timewarpOk false true 0 999999 = true := by rfl

/-- **C4 characterization**: the guard holds iff the block time is at most
one `MAX_TIMEWARP` behind the previous block (or the rule is off / the
height is not a period boundary). -/
theorem timewarpOk_true_iff (enforce atBoundary : Bool) (bt pt : UInt32) :
    timewarpOk enforce atBoundary bt pt = true ↔
      enforce = false ∨ atBoundary = false ∨ pt.toNat ≤ bt.toNat + 600 := by
  unfold timewarpOk
  cases enforce <;> cases atBoundary <;> simp <;> omega

/-! ## Chainwork (BLK-113/114) — the reorg-safety side of the BIP94 rationale -/

-- Exact work values: difficulty-1 = 4295032833; difficulty-4 = 4× exactly.
example : workOf 0x1d00ffff = 4295032833 := by native_decide
example : workOf 0x1c3fffc0 = 17180131332 := by native_decide
example : workOf 0x1c3fffc0 = 4 * workOf 0x1d00ffff := by native_decide

-- Two 20-minute-exception blocks contribute LESS work than one block mined
-- at the period's actual difficulty — why min-diff blocks lose reorg races.
example : chainWork [0x1d00ffff, 0x1d00ffff] < chainWork [0x1c3fffc0] := by native_decide

-- Out-of-range decode ⇒ zero work (chain.cpp:126-127).
example : workOf 0xff123456 = 0 := by native_decide

/-- **BLK-113 formula pin**: for an in-range decode, `workOf` is exactly
Core's `(~target / (target+1)) + 1` over 256-bit two's complement. -/
theorem workOf_eq_formula (bits : UInt32) (h0 : compactTarget bits ≠ 0)
    (hl : compactTarget bits ≤ powLimit) :
    workOf bits = (2 ^ 256 - 1 - compactTarget bits) / (compactTarget bits + 1) + 1 := by
  unfold workOf
  rw [if_neg (by omega)]

end BitcoinProofs.Bip.B15
