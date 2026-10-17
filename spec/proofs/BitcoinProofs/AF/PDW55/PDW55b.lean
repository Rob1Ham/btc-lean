import Bitcoin.Invariants.RC08

/-! # PDW55b — TOP-271..275: difficulty continuity (INV-094/095/096)

Row-face theorems for `Bitcoin/Invariants/RC08.lean`:

* **INV-094** `blockBitsOk` — mid-period the header nBits must equal the
  previous block's nBits; any mismatch is `bad-diffbits`.
* **INV-095** `atRetargetBoundary` — retarget only at period boundaries:
  mid-period copies last nBits, boundary computes the period retarget.
* **INV-096** `clampedTimespan` — the observed timespan is clamped to
  `[T/4, 4·T]` and is the identity inside that window.

Status-debt class: sorry-free in-tree, never flipped. Zero core writes. -/

namespace BitcoinProofs.AF.PDW55B

open Bitcoin.Invariants.RC08 Bitcoin.Block.Pow

/-- INV-094: a mid-period header whose nBits differs from the previous
block's is rejected (`bad-diffbits`, validation.cpp:4096-4097). -/
@[rule "INV-094"]
theorem blockBitsOk_badDiffbits_row (P : PowParams)
    (get : Nat → Option IndexNode) (lastHeight : Nat)
    (newTime bits : UInt32) (last : IndexNode)
    (hget : get lastHeight = some last)
    (hnb : ((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = true)
    (hnomin : P.fPowAllowMinDifficultyBlocks = false) (hne : bits ≠ last.bits) :
    blockBitsOk P get lastHeight newTime bits = false :=
  blockBitsOk_badDiffbits P get lastHeight newTime bits last hget hnb hnomin hne

/-- INV-095: both retarget branches — mid-period copies the previous
nBits verbatim (pow.cpp:26-27); at a boundary the result is exactly
`calculateNextWorkRequired` over the period window (pow.cpp:33-35). -/
@[rule "INV-095"]
theorem retarget_boundary_row (P : PowParams)
    (get : Nat → Option IndexNode) (lastHeight : Nat) (newTime : UInt32)
    (last first : IndexNode) (hgetL : get lastHeight = some last)
    (hgetF : get (lastHeight - (difficultyAdjustmentInterval P - 1)) = some first) :
    (((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = true →
        P.fPowAllowMinDifficultyBlocks = false →
        nextWorkRequired P get lastHeight newTime = some last.bits) ∧
    (((lastHeight + 1) % difficultyAdjustmentInterval P != 0) = false →
        nextWorkRequired P get lastHeight newTime =
          some (calculateNextWorkRequired P last.bits last.time first.time first.bits)) := by
  refine ⟨?_, ?_⟩
  · intro hnb hnomin
    exact retargetOnlyAtBoundary P get lastHeight newTime last hgetL hnb hnomin
  · intro hb
    exact retargetAtBoundary_calculate P get lastHeight newTime last first hgetL hb hgetF

/-- INV-096: the clamp never escapes `[T/4, 4·T]` and is the identity
inside the window (pow.cpp:57-60). -/
@[rule "INV-096"]
theorem clampedTimespan_bounds_window_row (T raw : Int) (hT : 0 < T) :
    T / 4 ≤ clampedTimespan T raw ∧ clampedTimespan T raw ≤ T * 4 ∧
      (T / 4 ≤ raw → raw ≤ T * 4 → clampedTimespan T raw = raw) := by
  refine ⟨(clampedTimespan_bounds T raw hT).1, (clampedTimespan_bounds T raw hT).2, ?_⟩
  intro hlo hhi
  exact clampedTimespan_window T raw hlo hhi

end BitcoinProofs.AF.PDW55B

/-- info: 'BitcoinProofs.AF.PDW55B.blockBitsOk_badDiffbits_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW55B.blockBitsOk_badDiffbits_row
/-- info: 'BitcoinProofs.AF.PDW55B.retarget_boundary_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW55B.retarget_boundary_row
/-- info: 'BitcoinProofs.AF.PDW55B.clampedTimespan_bounds_window_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW55B.clampedTimespan_bounds_window_row
