import Bitcoin.Block.Pow
import Bitcoin.Block.Connect

/-! # PDW38 — TOP-186..190 (route B).

Five rules.yaml rows, theorems stated on the exact core definitions:

* BLK-044 `nextWorkRequired` — the retarget window anchor is the block at
  height H − interval, and the timespan is `last.time − first.time`.
* BLK-049 `nextWorkRequired`/`calculateNextWorkRequired` —
  `fPowNoRetargeting` copies nBits at a period boundary; on a
  min-difficulty chain (regtest) non-boundary heights take the
  BLK-053/054 branch instead (powLimit or the walk-back bits).
* INV-097 `calculateNextWorkRequired` — `old·actual/T` with `actual`
  clamped to `[T/4, 4T]`, capped by powLimit; all three clamp arms and
  both BIP94 bases, plus the min-difficulty bypass at the caller.
* BLK-067 `finalityCutoff` — BIP113 switch, both arms + determination,
  and the `MTP(prev)` call site built from `medianTimePast`.
* TXV-026 `feeAccumInRange` — accumulated fees in MoneyRange iff true.

No core writes; tags ride these proofs. -/

namespace BitcoinProofs.AF.PDW38

open Bitcoin.Block.Pow Bitcoin.Block.Connect Bitcoin.Chain

/-- **BLK-044**: at a period boundary (new height `H`), `nextWorkRequired`
reads the ancestor at `H − interval` and feeds `last.time`/`first.time`
into `calculateNextWorkRequired` — the pow.cpp:41-47 window anchors. -/
@[rule "BLK-044"]
theorem nextWorkRequired_timespan_anchor
    (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight H : Nat) (newTime : UInt32) (last first : IndexNode)
    (hH : H = lastHeight + 1)
    (hT : 1 ≤ difficultyAdjustmentInterval P)
    (hb : H % difficultyAdjustmentInterval P = 0)
    (hget : get lastHeight = some last)
    (hfirst : get (H - difficultyAdjustmentInterval P) = some first) :
    nextWorkRequired P get lastHeight newTime
      = some (calculateNextWorkRequired P last.bits last.time
          first.time first.bits) := by
  subst hH
  have hTpos : 0 < difficultyAdjustmentInterval P := by omega
  have hidx : lastHeight + 1 - difficultyAdjustmentInterval P
      = lastHeight - (difficultyAdjustmentInterval P - 1) := by omega
  have hcond : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = false := by
    simp [hb]
  have hfirst' : get (lastHeight - (difficultyAdjustmentInterval P - 1))
      = some first := by rw [← hidx]; exact hfirst
  simp only [nextWorkRequired, hget, hcond, Bool.false_eq_true, ite_false, hfirst']

/-- **BLK-049**: no-retarget mode (regtest) copies the last nBits. -/
@[rule "BLK-049"]
theorem calculateNextWorkRequired_noRetarget
    (P : PowParams) (lastBits lastTime firstTime firstBits : UInt32)
    (h : P.fPowNoRetargeting = true) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits = lastBits := by
  simp [calculateNextWorkRequired, h]

/-- **BLK-049** (boundary arm): at a period boundary `nextWorkRequired`
returns `calculateNextWorkRequired`, which under `fPowNoRetargeting`
copies the last block's `nBits`. -/
@[rule "BLK-049"]
theorem nextWorkRequired_noRetarget_boundary
    (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) (last first : IndexNode)
    (h : P.fPowNoRetargeting = true)
    (hget : get lastHeight = some last)
    (hb : (lastHeight + 1) % difficultyAdjustmentInterval P = 0)
    (hfirst : get (lastHeight - (difficultyAdjustmentInterval P - 1))
      = some first) :
    nextWorkRequired P get lastHeight newTime = some last.bits := by
  have hcond : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = false := by
    simp [hb]
  simp only [nextWorkRequired, hget, hcond, Bool.false_eq_true, ite_false, hfirst]
  simp [calculateNextWorkRequired, h]

/-- **BLK-049** (non-boundary, min-difficulty): when
`fPowAllowMinDifficultyBlocks` is on, `nextWorkRequired` never reaches
`calculateNextWorkRequired` on a non-boundary height — it takes the
min-difficulty branch (BLK-053/054) instead. -/
@[rule "BLK-049"]
theorem nextWorkRequired_nonBoundary_minDifficulty
    (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) (last : IndexNode)
    (hmin : P.fPowAllowMinDifficultyBlocks = true)
    (hget : get lastHeight = some last)
    (hnb : (lastHeight + 1) % difficultyAdjustmentInterval P ≠ 0) :
    nextWorkRequired P get lastHeight newTime =
      (if newTime.toNat > last.time.toNat + P.powTargetSpacing * 2
       then some (getCompact P.powLimit)
       else minDiffWalkBack P get lastHeight) := by
  unfold nextWorkRequired
  simp only [hget]
  have hcond : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = true := by
    simp [hnb]
  simp [hcond, hmin]

/-- **BLK-049** (regtest slow block): regtest sets both
`fPowNoRetargeting` and `fPowAllowMinDifficultyBlocks`, so a non-boundary
block more than `2 × spacing` late returns `powLimit`, not the previous
`nBits`.  This is the branch the old row omitted. -/
@[rule "BLK-049"]
theorem nextWorkRequired_regtest_slow_nonBoundary_powLimit
    (get : Nat → Option IndexNode) (lastHeight : Nat) (newTime : UInt32)
    (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : (lastHeight + 1) % difficultyAdjustmentInterval regtestParams ≠ 0)
    (hslow : newTime.toNat > last.time.toNat + regtestParams.powTargetSpacing * 2) :
    nextWorkRequired regtestParams get lastHeight newTime =
      some (getCompact regtestParams.powLimit) := by
  rw [nextWorkRequired_nonBoundary_minDifficulty regtestParams get lastHeight
    newTime last (by rfl) hget hnb]
  simp [hslow]

/-- **INV-097** (BIP94 off): with the observed timespan inside the clamp
window and the legacy base, the new target is `old · span / T` truncated,
capped at powLimit (pow.cpp:63-84). -/
@[rule "INV-097"]
theorem calculateNextWorkRequired_target_mid
    (P : PowParams) (lastBits lastTime firstTime firstBits : UInt32)
    (hnr : P.fPowNoRetargeting = false)
    (hbip : P.enforceBIP94 = false)
    (hle : firstTime.toNat ≤ lastTime.toNat)
    (hlo : ((P.powTargetTimespan / 4 : Nat) : Int)
      ≤ (lastTime.toNat : Int) - firstTime.toNat)
    (hhi : (lastTime.toNat : Int) - firstTime.toNat
      ≤ ((P.powTargetTimespan * 4 : Nat) : Int)) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits
      = getCompact (min (compactTarget lastBits *
          (lastTime.toNat - firstTime.toNat) / P.powTargetTimespan) P.powLimit) := by
  have hraw : ¬ ((lastTime.toNat : Int) - firstTime.toNat
      < ((P.powTargetTimespan / 4 : Nat) : Int)) := by omega
  have hraw2 : ¬ ((lastTime.toNat : Int) - firstTime.toNat
      > ((P.powTargetTimespan * 4 : Nat) : Int)) := by omega
  have hto : ((lastTime.toNat : Int) - firstTime.toNat).toNat
      = lastTime.toNat - firstTime.toNat := by omega
  unfold calculateNextWorkRequired
  simp only [hnr, Bool.false_eq_true, ite_false]
  rw [ite_eq_right hraw, ite_eq_right hraw2]
  simp [hto, hbip]

/-- **INV-097** (BIP94 on): the same target law with the period-first base. -/
@[rule "INV-097"]
theorem calculateNextWorkRequired_target_mid_bip94
    (P : PowParams) (lastBits lastTime firstTime firstBits : UInt32)
    (hnr : P.fPowNoRetargeting = false)
    (hbip : P.enforceBIP94 = true)
    (hle : firstTime.toNat ≤ lastTime.toNat)
    (hlo : ((P.powTargetTimespan / 4 : Nat) : Int)
      ≤ (lastTime.toNat : Int) - firstTime.toNat)
    (hhi : (lastTime.toNat : Int) - firstTime.toNat
      ≤ ((P.powTargetTimespan * 4 : Nat) : Int)) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits
      = getCompact (min (compactTarget firstBits *
          (lastTime.toNat - firstTime.toNat) / P.powTargetTimespan) P.powLimit) := by
  have hraw : ¬ ((lastTime.toNat : Int) - firstTime.toNat
      < ((P.powTargetTimespan / 4 : Nat) : Int)) := by omega
  have hraw2 : ¬ ((lastTime.toNat : Int) - firstTime.toNat
      > ((P.powTargetTimespan * 4 : Nat) : Int)) := by omega
  have hto : ((lastTime.toNat : Int) - firstTime.toNat).toNat
      = lastTime.toNat - firstTime.toNat := by omega
  unfold calculateNextWorkRequired
  simp only [hnr, Bool.false_eq_true, ite_false]
  rw [ite_eq_right hraw, ite_eq_right hraw2]
  simp [hto, hbip]

/-! ### INV-097 — the full clamped-retarget law

Core's `CalculateNextWorkRequired` (pow.cpp:63-84) computes
`base · nActualTimespan / T` with `nActualTimespan` clamped to
`[T/4, 4T]`, then caps at `powLimit`.  `retargetActual` is that clamped
timespan; `retargetBase` is the BIP94-dependent base.  The general
theorem below covers every timespan value (both clamp arms and the
interior), and the specializations expose the clamp endpoints and both
BIP94 bases. -/

/-- Core's retarget base: first-of-period bits under BIP94, else the
last block's bits (pow.cpp:66-68). -/
def retargetBase (P : PowParams) (lastBits firstBits : UInt32) : Nat :=
  if P.enforceBIP94 then compactTarget firstBits else compactTarget lastBits

/-- Core's clamped `nActualTimespan` (pow.cpp:70-76) as a `Nat`. -/
def retargetActual (P : PowParams) (lastTime firstTime : UInt32) : Nat :=
  let raw : Int := lastTime.toNat - firstTime.toNat
  (if raw < ((P.powTargetTimespan / 4 : Nat) : Int)
   then ((P.powTargetTimespan / 4 : Nat) : Int)
   else if raw > ((P.powTargetTimespan * 4 : Nat) : Int)
   then ((P.powTargetTimespan * 4 : Nat) : Int)
   else raw).toNat

/-- **INV-097** (all timespans): with retargeting on, the result is
`getCompact (min (base · clampedSpan / T) powLimit)` — the row with
`actual` read as Core's clamped timespan. -/
@[rule "INV-097"]
theorem calculateNextWorkRequired_target_eq
    (P : PowParams) (lastBits lastTime firstTime firstBits : UInt32)
    (hnr : P.fPowNoRetargeting = false) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits
      = getCompact (min (retargetBase P lastBits firstBits *
          retargetActual P lastTime firstTime / P.powTargetTimespan) P.powLimit) := by
  unfold calculateNextWorkRequired retargetBase retargetActual
  simp only [hnr, Bool.false_eq_true, ite_false]

/-- **INV-097** (low clamp arm): a timespan below `T/4` uses `T/4`. -/
@[rule "INV-097"]
theorem retargetActual_low (P : PowParams) (lastTime firstTime : UInt32)
    (h : (lastTime.toNat : Int) - firstTime.toNat
      < ((P.powTargetTimespan / 4 : Nat) : Int)) :
    retargetActual P lastTime firstTime = P.powTargetTimespan / 4 := by
  unfold retargetActual
  dsimp only
  rw [ite_eq_left h]
  exact Int.toNat_natCast _

/-- **INV-097** (high clamp arm): a timespan above `4T` uses `4T`. -/
@[rule "INV-097"]
theorem retargetActual_high (P : PowParams) (lastTime firstTime : UInt32)
    (h : (lastTime.toNat : Int) - firstTime.toNat
      > ((P.powTargetTimespan * 4 : Nat) : Int)) :
    retargetActual P lastTime firstTime = P.powTargetTimespan * 4 := by
  unfold retargetActual
  dsimp only
  have hnot : ¬ ((lastTime.toNat : Int) - firstTime.toNat
      < ((P.powTargetTimespan / 4 : Nat) : Int)) := by omega
  rw [ite_eq_right hnot, ite_eq_left h]
  exact Int.toNat_natCast _

/-- **INV-097** (interior): inside the clamp window the observed span is
used unchanged. -/
@[rule "INV-097"]
theorem retargetActual_mid (P : PowParams) (lastTime firstTime : UInt32)
    (hlo : ¬ ((lastTime.toNat : Int) - firstTime.toNat
      < ((P.powTargetTimespan / 4 : Nat) : Int)))
    (hhi : ¬ ((lastTime.toNat : Int) - firstTime.toNat
      > ((P.powTargetTimespan * 4 : Nat) : Int))) :
    retargetActual P lastTime firstTime = lastTime.toNat - firstTime.toNat := by
  unfold retargetActual
  dsimp only
  have hto : ((lastTime.toNat : Int) - firstTime.toNat).toNat
      = lastTime.toNat - firstTime.toNat := by omega
  rw [ite_eq_right hlo, ite_eq_right hhi, hto]

/-- **INV-097** (low endpoint target). -/
@[rule "INV-097"]
theorem calculateNextWorkRequired_target_low
    (P : PowParams) (lastBits lastTime firstTime firstBits : UInt32)
    (hnr : P.fPowNoRetargeting = false)
    (h : (lastTime.toNat : Int) - firstTime.toNat
      < ((P.powTargetTimespan / 4 : Nat) : Int)) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits
      = getCompact (min (retargetBase P lastBits firstBits *
          (P.powTargetTimespan / 4) / P.powTargetTimespan) P.powLimit) := by
  rw [calculateNextWorkRequired_target_eq P lastBits lastTime firstTime firstBits hnr,
    retargetActual_low P lastTime firstTime h]

/-- **INV-097** (high endpoint target). -/
@[rule "INV-097"]
theorem calculateNextWorkRequired_target_high
    (P : PowParams) (lastBits lastTime firstTime firstBits : UInt32)
    (hnr : P.fPowNoRetargeting = false)
    (h : (lastTime.toNat : Int) - firstTime.toNat
      > ((P.powTargetTimespan * 4 : Nat) : Int)) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits
      = getCompact (min (retargetBase P lastBits firstBits *
          (P.powTargetTimespan * 4) / P.powTargetTimespan) P.powLimit) := by
  rw [calculateNextWorkRequired_target_eq P lastBits lastTime firstTime firstBits hnr,
    retargetActual_high P lastTime firstTime h]

/-- **INV-097** (interior target, any base). -/
@[rule "INV-097"]
theorem calculateNextWorkRequired_target_interior
    (P : PowParams) (lastBits lastTime firstTime firstBits : UInt32)
    (hnr : P.fPowNoRetargeting = false)
    (hlo : ¬ ((lastTime.toNat : Int) - firstTime.toNat
      < ((P.powTargetTimespan / 4 : Nat) : Int)))
    (hhi : ¬ ((lastTime.toNat : Int) - firstTime.toNat
      > ((P.powTargetTimespan * 4 : Nat) : Int))) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits
      = getCompact (min (retargetBase P lastBits firstBits *
          (lastTime.toNat - firstTime.toNat) / P.powTargetTimespan) P.powLimit) := by
  rw [calculateNextWorkRequired_target_eq P lastBits lastTime firstTime firstBits hnr,
    retargetActual_mid P lastTime firstTime hlo hhi]

/-- **INV-097** (BIP94 off, all timespans). -/
@[rule "INV-097"]
theorem calculateNextWorkRequired_target_eq_bip94_off
    (P : PowParams) (lastBits lastTime firstTime firstBits : UInt32)
    (hnr : P.fPowNoRetargeting = false) (hbip : P.enforceBIP94 = false) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits
      = getCompact (min (compactTarget lastBits *
          retargetActual P lastTime firstTime / P.powTargetTimespan) P.powLimit) := by
  rw [calculateNextWorkRequired_target_eq P lastBits lastTime firstTime firstBits hnr]
  simp [retargetBase, hbip]

/-- **INV-097** (BIP94 on, all timespans). -/
@[rule "INV-097"]
theorem calculateNextWorkRequired_target_eq_bip94_on
    (P : PowParams) (lastBits lastTime firstTime firstBits : UInt32)
    (hnr : P.fPowNoRetargeting = false) (hbip : P.enforceBIP94 = true) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits
      = getCompact (min (compactTarget firstBits *
          retargetActual P lastTime firstTime / P.powTargetTimespan) P.powLimit) := by
  rw [calculateNextWorkRequired_target_eq P lastBits lastTime firstTime firstBits hnr]
  simp [retargetBase, hbip]

/-- **INV-097** (min-difficulty branch): on a min-difficulty chain the
`CalculateNextWorkRequired` formula is bypassed for a late non-boundary
block, which returns `powLimit` instead. -/
@[rule "INV-097"]
theorem nextWorkRequired_minDifficulty_powLimit
    (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) (last : IndexNode)
    (hmin : P.fPowAllowMinDifficultyBlocks = true)
    (hget : get lastHeight = some last)
    (hnb : (lastHeight + 1) % difficultyAdjustmentInterval P ≠ 0)
    (hslow : newTime.toNat > last.time.toNat + P.powTargetSpacing * 2) :
    nextWorkRequired P get lastHeight newTime = some (getCompact P.powLimit) := by
  rw [nextWorkRequired_nonBoundary_minDifficulty P get lastHeight newTime last
    hmin hget hnb]
  simp [hslow]

/-- **BLK-067**: BIP113 — CSV active selects the parent MTP, else the
block's own time; both arms and the determination law. -/
@[rule "BLK-067"]
theorem finalityCutoff_eq (csvActive : Bool) (mtp blockTime : UInt32) :
    finalityCutoff csvActive mtp blockTime
      = if csvActive then mtp else blockTime := rfl

@[rule "BLK-067"]
theorem finalityCutoff_iff (csvActive : Bool) (mtp blockTime cutoff : UInt32) :
    finalityCutoff csvActive mtp blockTime = cutoff
      ↔ (csvActive = true ∧ cutoff = mtp) ∨ (csvActive = false ∧ cutoff = blockTime) := by
  cases csvActive <;> simp [finalityCutoff, eq_comm]

/-- **BLK-067** (call site): when the parent window resolves, the cutoff
is built from the parent's `medianTimePast` — the row's `MTP(prev)` is no
longer an unconstrained argument. -/
@[rule "BLK-067"]
theorem finalityCutoffAtParent_eq
    (csvActive : Bool) (get : Nat → Option UInt32) (parentHeight : Nat)
    (mtp blockTime : UInt32)
    (hmtp : medianTimePast get parentHeight = some mtp) :
    finalityCutoffAtParent csvActive get parentHeight blockTime =
      some (if csvActive then mtp else blockTime) := by
  unfold finalityCutoffAtParent
  rw [hmtp]
  cases csvActive <;> simp [finalityCutoff]

/-- **BLK-067** (unresolved parent window): the call site is `none`. -/
@[rule "BLK-067"]
theorem finalityCutoffAtParent_none
    (csvActive : Bool) (get : Nat → Option UInt32) (parentHeight : Nat)
    (blockTime : UInt32)
    (hmtp : medianTimePast get parentHeight = none) :
    finalityCutoffAtParent csvActive get parentHeight blockTime = none := by
  unfold finalityCutoffAtParent
  rw [hmtp]
  rfl

/-- **BLK-067** (membership form): every resolved cutoff is either the
parent's MTP (CSV active) or the block time (CSV inactive). -/
@[rule "BLK-067"]
theorem finalityCutoffAtParent_iff
    (csvActive : Bool) (get : Nat → Option UInt32) (parentHeight : Nat)
    (blockTime cutoff : UInt32) :
    finalityCutoffAtParent csvActive get parentHeight blockTime = some cutoff
      ↔ ∃ mtp, medianTimePast get parentHeight = some mtp ∧
          ((csvActive = true ∧ cutoff = mtp) ∨
           (csvActive = false ∧ cutoff = blockTime)) := by
  unfold finalityCutoffAtParent
  cases h : medianTimePast get parentHeight with
  | none => simp
  | some mtp =>
    simp only [Option.map_some, Option.some.injEq]
    rw [finalityCutoff_iff]
    constructor
    · intro hc; exact ⟨mtp, rfl, hc⟩
    · rintro ⟨m, hm, hc⟩
      have : m = mtp := hm.symm
      subst this
      exact hc

/-- **TXV-026** (BLK-091 alias): the accumulated-fee gate is exactly
MoneyRange — accept iff `0 ≤ fees ≤ MAX_MONEY`. -/
@[rule "TXV-026"]
theorem feeAccumInRange_iff (fees : Int) :
    feeAccumInRange fees = true ↔ 0 ≤ fees ∧ fees ≤ Bitcoin.Data.MAX_MONEY := by
  unfold feeAccumInRange
  exact Bitcoin.Conservation.moneyRange_eq_true_iff fees

@[rule "TXV-026"]
theorem feeAccumInRange_reject_neg (fees : Int) (h : fees < 0) :
    feeAccumInRange fees = false := by
  rw [Bool.eq_false_iff]
  intro htrue
  rw [feeAccumInRange_iff] at htrue
  exact absurd (Int.lt_of_lt_of_le h htrue.1) (Int.lt_irrefl fees)

@[rule "TXV-026"]
theorem feeAccumInRange_reject_high (fees : Int) (h : Bitcoin.Data.MAX_MONEY < fees) :
    feeAccumInRange fees = false := by
  rw [Bool.eq_false_iff]
  intro htrue
  rw [feeAccumInRange_iff] at htrue
  exact absurd (Int.lt_of_lt_of_le h htrue.2) (Int.lt_irrefl Bitcoin.Data.MAX_MONEY)

end BitcoinProofs.AF.PDW38

/-! ## Axiom pins (subset [propext, Classical.choice, Quot.sound]) -/
#print axioms BitcoinProofs.AF.PDW38.nextWorkRequired_timespan_anchor
#print axioms BitcoinProofs.AF.PDW38.calculateNextWorkRequired_noRetarget
#print axioms BitcoinProofs.AF.PDW38.nextWorkRequired_noRetarget_boundary
#print axioms BitcoinProofs.AF.PDW38.nextWorkRequired_nonBoundary_minDifficulty
#print axioms BitcoinProofs.AF.PDW38.nextWorkRequired_regtest_slow_nonBoundary_powLimit
#print axioms BitcoinProofs.AF.PDW38.calculateNextWorkRequired_target_mid
#print axioms BitcoinProofs.AF.PDW38.calculateNextWorkRequired_target_mid_bip94
#print axioms BitcoinProofs.AF.PDW38.calculateNextWorkRequired_target_eq
#print axioms BitcoinProofs.AF.PDW38.calculateNextWorkRequired_target_low
#print axioms BitcoinProofs.AF.PDW38.calculateNextWorkRequired_target_high
#print axioms BitcoinProofs.AF.PDW38.calculateNextWorkRequired_target_interior
#print axioms BitcoinProofs.AF.PDW38.calculateNextWorkRequired_target_eq_bip94_off
#print axioms BitcoinProofs.AF.PDW38.calculateNextWorkRequired_target_eq_bip94_on
#print axioms BitcoinProofs.AF.PDW38.nextWorkRequired_minDifficulty_powLimit
#print axioms BitcoinProofs.AF.PDW38.finalityCutoff_iff
#print axioms BitcoinProofs.AF.PDW38.finalityCutoffAtParent_eq
#print axioms BitcoinProofs.AF.PDW38.finalityCutoffAtParent_none
#print axioms BitcoinProofs.AF.PDW38.finalityCutoffAtParent_iff
#print axioms BitcoinProofs.AF.PDW38.feeAccumInRange_iff
#print axioms BitcoinProofs.AF.PDW38.feeAccumInRange_reject_neg
#print axioms BitcoinProofs.AF.PDW38.feeAccumInRange_reject_high
