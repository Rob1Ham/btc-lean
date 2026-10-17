import Bitcoin.Invariants.RC08

/-! # PDW44RC08Yield.lean — YIELDED RC08 band (F-PDW44-002)
(PDW44, 2026-10-17; claim v2 was this band, released to PDW55).
Rows {INV-085, INV-086, INV-094, INV-095, INV-096} belong to PDW55
(TOP-271..275 v1.1 + `1281389`); this file only keeps my row-face
development buildable as the yield trail. Not part of PDW44's count.

D-RC08 block-acceptance spine of `Bitcoin/Invariants/RC08.lean`
(`validation.cpp::CheckBlock/ContextualCheckBlock`, `pow.cpp` @
`cce32b168`):

* **INV-085** `checkBlockTxs` — the per-tx gate: pass iff EVERY tx
  passes `CheckTransaction` (first failure wins).
* **INV-086** `signetBlockOk` — BIP325 gate skipped off-signet; on
  signet with POW, pass iff the solution validates.
* **INV-094** `blockBitsOk` — nBits continuity: the required
  `GetNextWorkRequired` value is accepted and any other is
  `bad-diffbits`; mid-period, boundary, and min-difficulty faces.
* **INV-095** `atRetargetBoundary` — periodic retarget only at interval
  multiples; mid-period blocks copy the previous nBits, while the
  testnet min-difficulty rule is the documented mid-period exception.
* **INV-096** `clampedTimespan` — clamp window `[T/4, 4T]` and identity
  inside it.

Route B: zero core writes, tags ride THESE row-face theorems (in-tree
sorry-free refinements restated; pins ⊆ [propext, Classical.choice,
Quot.sound]). `PDW44Yield.lean` keeps the yielded D-SIGOPS helper
(F-PDW44-001). -/

namespace BitcoinProofs.AF.PDW44

open Bitcoin.Invariants.RC08 Bitcoin.Data Bitcoin.Block.Pow

/-! ## INV-085 — CheckBlock runs CheckTransaction on every tx -/

@[rule "INV-085"]
theorem checkBlockTxs_row_iff (txs : List Tx) :
    checkBlockTxs txs = none ↔
      ∀ t ∈ txs, Bitcoin.Consensus.checkTransaction t = none :=
  checkBlockTxs_none_iff txs

@[rule "INV-085"]
theorem checkBlockTxs_row_first (t : Tx) (rest : List Tx)
    (e : Bitcoin.Consensus.TxCheckError)
    (h : Bitcoin.Consensus.checkTransaction t = some e) :
    checkBlockTxs (t :: rest) = some e := by
  simp [checkBlockTxs, h]

/-! ## INV-086 — signet solution gate -/

@[rule "INV-086"]
theorem signetBlockOk_row_skip (fCheckPOW solutionOk : Bool) :
    signetBlockOk false fCheckPOW solutionOk = true :=
  signetBlockOk_skip fCheckPOW solutionOk

@[rule "INV-086"]
theorem signetBlockOk_row_gate (solutionOk : Bool) :
    (signetBlockOk true true solutionOk = true) ↔ solutionOk = true :=
  signetBlockOk_gate solutionOk

/-! ## INV-094/095 — nBits continuity and retarget boundary -/

@[rule "INV-094"]
theorem blockBitsOk_row_midperiod (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = true)
    (hnomin : P.fPowAllowMinDifficultyBlocks = false) :
    blockBitsOk P get lastHeight newTime last.bits = true :=
  blockBitsOk_midperiod P get lastHeight newTime last hget hnb hnomin

@[rule "INV-094"]
theorem blockBitsOk_row_reject (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime bits : UInt32) (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = true)
    (hnomin : P.fPowAllowMinDifficultyBlocks = false)
    (hne : bits ≠ last.bits) :
    blockBitsOk P get lastHeight newTime bits = false :=
  blockBitsOk_badDiffbits P get lastHeight newTime bits last hget hnb hnomin hne

@[rule "INV-094"]
theorem blockBitsOk_row_accept (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime bits : UInt32)
    (h : nextWorkRequired P get lastHeight newTime = some bits) :
    blockBitsOk P get lastHeight newTime bits = true :=
  blockBitsOk_required P get lastHeight newTime bits h

@[rule "INV-094"]
theorem blockBitsOk_row_iff (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime bits : UInt32) :
    blockBitsOk P get lastHeight newTime bits = true ↔
      nextWorkRequired P get lastHeight newTime = some bits :=
  blockBitsOk_iff P get lastHeight newTime bits

@[rule "INV-094"]
theorem blockBitsOk_row_boundary (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) (last first : IndexNode)
    (hgetL : get lastHeight = some last)
    (hb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = false)
    (hgetF : get (lastHeight - (difficultyAdjustmentInterval P - 1)) = some first) :
    blockBitsOk P get lastHeight newTime
      (calculateNextWorkRequired P last.bits last.time first.time first.bits) = true :=
  blockBitsOk_boundary P get lastHeight newTime last first hgetL hb hgetF

@[rule "INV-094"]
theorem blockBitsOk_row_minDifficulty (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = true)
    (hmin : P.fPowAllowMinDifficultyBlocks = true)
    (hslow : newTime.toNat > last.time.toNat + P.powTargetSpacing * 2) :
    blockBitsOk P get lastHeight newTime (getCompact P.powLimit) = true :=
  blockBitsOk_minDifficulty P get lastHeight newTime last hget hnb hmin hslow

@[rule "INV-095"]
theorem atRetargetBoundary_row (P : PowParams) (h : Nat) :
    atRetargetBoundary P h =
      decide (h % difficultyAdjustmentInterval P = 0) :=
  atRetargetBoundary_def P h

@[rule "INV-095"]
theorem retargetOnlyAtBoundary_row (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = true)
    (hnomin : P.fPowAllowMinDifficultyBlocks = false) :
    nextWorkRequired P get lastHeight newTime = some last.bits :=
  retargetOnlyAtBoundary P get lastHeight newTime last hget hnb hnomin

/-- INV-095: at a boundary the next work is exactly
`CalculateNextWorkRequired` over the period window (pow.cpp:41-47). -/
@[rule "INV-095"]
theorem retargetAtBoundary_row (P : PowParams) (get : Nat → Option IndexNode)
    (lastHeight : Nat) (newTime : UInt32) (last first : IndexNode)
    (hgetL : get lastHeight = some last)
    (hb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = false)
    (hgetF : get (lastHeight - (difficultyAdjustmentInterval P - 1)) = some first) :
    nextWorkRequired P get lastHeight newTime =
      some (calculateNextWorkRequired P last.bits last.time first.time first.bits) :=
  retargetAtBoundary_calculate P get lastHeight newTime last first hgetL hb hgetF

/-- INV-095: the min-difficulty mid-period exception — a late block under
`fPowAllowMinDifficultyBlocks` gets the pow-limit compact (pow.cpp:22-28),
so "retarget only at boundaries" is stated only for the non-min-difficulty
rule. -/
@[rule "INV-095"]
theorem retargetMidPeriod_minDifficulty_row (P : PowParams)
    (get : Nat → Option IndexNode) (lastHeight : Nat) (newTime : UInt32)
    (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = true)
    (hmin : P.fPowAllowMinDifficultyBlocks = true)
    (hslow : newTime.toNat > last.time.toNat + P.powTargetSpacing * 2) :
    nextWorkRequired P get lastHeight newTime = some (getCompact P.powLimit) :=
  retargetMidPeriod_minDifficulty P get lastHeight newTime last hget hnb hmin hslow

/-- INV-095: the non-slow min-difficulty arm is Core's walk-back to the
last non-min-difficulty ancestor (pow.cpp:29-36). -/
@[rule "INV-095"]
theorem retargetMidPeriod_walkBack_row (P : PowParams)
    (get : Nat → Option IndexNode) (lastHeight : Nat) (newTime : UInt32)
    (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = true)
    (hmin : P.fPowAllowMinDifficultyBlocks = true)
    (hnotslow : ¬ newTime.toNat > last.time.toNat + P.powTargetSpacing * 2) :
    nextWorkRequired P get lastHeight newTime = minDiffWalkBack P get lastHeight :=
  retargetMidPeriod_minDifficulty_walkBack P get lastHeight newTime last
    hget hnb hmin hnotslow

/-! ## INV-096 — the timespan clamp -/

@[rule "INV-096"]
theorem clampedTimespan_row_bounds (T raw : Int) (hT : 0 < T) :
    T / 4 ≤ clampedTimespan T raw ∧ clampedTimespan T raw ≤ T * 4 :=
  clampedTimespan_bounds T raw hT

@[rule "INV-096"]
theorem clampedTimespan_row_window (T raw : Int)
    (hlo : T / 4 ≤ raw) (hhi : raw ≤ T * 4) :
    clampedTimespan T raw = raw :=
  clampedTimespan_window T raw hlo hhi

/-! ## Axiom pins for the strengthened INV-094/095 faces -/

/-- info: 'BitcoinProofs.AF.PDW44.blockBitsOk_row_accept' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms blockBitsOk_row_accept
/-- info: 'BitcoinProofs.AF.PDW44.blockBitsOk_row_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms blockBitsOk_row_iff
/-- info: 'BitcoinProofs.AF.PDW44.blockBitsOk_row_boundary' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms blockBitsOk_row_boundary
/-- info: 'BitcoinProofs.AF.PDW44.blockBitsOk_row_minDifficulty' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms blockBitsOk_row_minDifficulty
/-- info: 'BitcoinProofs.AF.PDW44.retargetAtBoundary_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms retargetAtBoundary_row
/-- info: 'BitcoinProofs.AF.PDW44.retargetMidPeriod_minDifficulty_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms retargetMidPeriod_minDifficulty_row
/-- info: 'BitcoinProofs.AF.PDW44.retargetMidPeriod_walkBack_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms retargetMidPeriod_walkBack_row

end BitcoinProofs.AF.PDW44
