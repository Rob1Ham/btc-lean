import Bitcoin.Block.Index
import Bitcoin.Activation.Interface
import Bitcoin.RuleAttr

/-!
# Bitcoin.Invariants.RC12 — acceptance-spine invariants INV-134/INV-142 (RC12)

Rule-Closure suite. Ground truth: research/05-core-inventory.md
(rows INV-134, INV-142; Core pin @cce32b168). Sister rows INV-133/135/136/138
are aliased onto existing declarations;
INV-139/140/141/143/144 live in the block-validation module's Block-layer files (blocked-on-the block-validation module for
the attribute alias); INV-137 is non-consensus (obsolete).

## INV-134 — BIP113 MTP gate on CSV deployment

`ContextualCheckBlock` (validation.cpp:4141-4150) computes the lock-time
cutoff for the block's finality sweep:

```
nLockTimeCutoff = (STANDARD_LOCKTIME_VERIFY_FLAGS & LOCKTIME_MEDIAN_TIME_PAST) != 0
    ? pindexPrev->GetMedianTimePast() : pindex->GetBlockTime();
```

Post-CSV the block's script flags carry `LOCKTIME_MEDIAN_TIME_PAST`
(buried at `CSV_HEIGHT = 419328`, `getBlockScriptFlagsP` csv arm), so the
cutoff is the PREVIOUS block's median-time-past; before CSV it is the
block's own time. Values cross-checked with a Python mirror of the exact
Core lines.

## INV-142 — GetBlockProofEquivalentTime (assumevalid 2-week guard)

`GetBlockProofEquivalentTime` (chain.cpp:135-149, declared chain.h:311,
used from validation.cpp:2363 for the assumevalid sanity check) returns
**signed seconds**: `|to.nChainWork − from.nChainWork| * nPowTargetSpacing
/ GetBlockProof(tip)`, saturated at `int64_t::max`. It is not a time-window
work sum. The work terms reuse the block-validation module's `Bitcoin.Block.Index.workOf`
(BLK-113, `GetBlockProof` port) — imported, not edited. A historical
`proofEquivalentWork` walk is retained below as a separate auxiliary.
-/

namespace Bitcoin.Invariants.RC12

/-! ## INV-134: the BIP113 cutoff gate -/

/-- **INV-134** (BIP113, validation.cpp:4141-4150): the block-level
lock-time cutoff — the previous block's median-time-past once CSV is
deployed (buried height `419328`), else the block's own time. -/
@[rule "INV-134"]
def bip113Cutoff (height blockTime prevMtp : UInt32) : UInt32 :=
  if Bitcoin.Activation.CSV_HEIGHT ≤ height then prevMtp else blockTime

/-- Cutoff flips to MTP exactly AT the CSV activation height (boundary
`≥`, matching the buried-deployment `since ≤ height` gate). -/
theorem bip113Cutoff_active (blockTime prevMtp : UInt32) :
    bip113Cutoff 419328 blockTime prevMtp = prevMtp := by
  unfold bip113Cutoff
  rw [if_pos (by decide : (Bitcoin.Activation.CSV_HEIGHT : UInt32) ≤ 419328)]

/-- One block below the CSV height the cutoff is still the block time. -/
theorem bip113Cutoff_pre (blockTime prevMtp : UInt32) :
    bip113Cutoff 419327 blockTime prevMtp = blockTime := by
  unfold bip113Cutoff
  rw [if_neg (by decide : ¬ ((Bitcoin.Activation.CSV_HEIGHT : UInt32) ≤ 419327))]

/-- INV-134 vector (python3 mirror cross-check, RC12):
cutoff grid `(height, blockTime, prevMtp) ↦ cutoff` for the heights
419327 / 419328 / 500000 with (1000, 900) — `blockTime, prevMtp, prevMtp`. -/
theorem bip113Cutoff_vector :
    bip113Cutoff 419327 1000 900 = 1000 ∧
    bip113Cutoff 419328 1000 900 = 900 ∧
    bip113Cutoff 500000 1000 900 = 900 := by decide

/-- info: 'Bitcoin.Invariants.RC12.bip113Cutoff_vector' does not depend on any axioms -/
#guard_msgs in
#print axioms bip113Cutoff_vector

/-! ## INV-142: `GetBlockProofEquivalentTime` — signed seconds

Core (`chain.cpp:135-149`, declared `chain.h:311`) does **not** sum work
over a time window. It takes the absolute chainwork difference between
`to` and `from`, multiplies by `nPowTargetSpacing`, divides by
`GetBlockProof(tip)`, and returns a **signed number of seconds** (the sign
is positive iff `to.nChainWork > from.nChainWork`), saturating at
`int64_t` max. The assumevalid call site (`validation.cpp:2363`) is the
comparison `... <= TWO_WEEKS_IN_SECONDS`.

The `proofEquivalentWork` walk below is retained as a separate
work-window auxiliary; it is not the Core function. -/

/-- The assumevalid window: 2 weeks in seconds (validation.cpp:2363's
`60 * 60 * 24 * 7 * 2`). -/
abbrev twoWeekSeconds : Int32 := 1209600

/-- **INV-142** (`GetBlockProofEquivalentTime`, chain.cpp:135-149): the
signed equivalent time in seconds.

`|to − from|` is the absolute `nChainWork` difference, `spacing` is
`nPowTargetSpacing`, and `workOf tipBits` is `GetBlockProof(tip)`. The
division is unsigned (both operands are nonnegative), then the sign is
applied. Core's `r.bits() > 63` saturation is exactly `2^63 ≤ r`, in
which case the result is `±int64_t::max`. -/
@[rule "INV-142"]
def proofEquivalentTime (toWork fromWork spacing : Nat) (tipBits : UInt32) : Int :=
  let sign : Int := if toWork > fromWork then 1 else -1
  let r : Nat :=
    (if toWork > fromWork then toWork - fromWork else fromWork - toWork)
      * spacing / Bitcoin.Block.Index.workOf tipBits
  if 2 ^ 63 ≤ r then sign * Int.ofNat (2 ^ 63 - 1) else sign * Int.ofNat r

/-- The exact value form: signed `min(|Δwork|·spacing / GetBlockProof(tip),
int64_max)`. This is the whole Core construction in one equation. -/
@[rule "INV-142"]
theorem proofEquivalentTime_eq_abs (toWork fromWork spacing : Nat)
    (tipBits : UInt32) :
    proofEquivalentTime toWork fromWork spacing tipBits =
      (if toWork > fromWork then (1 : Int) else -1) *
        Int.ofNat
          (min
            ((if toWork > fromWork then toWork - fromWork else fromWork - toWork)
              * spacing / Bitcoin.Block.Index.workOf tipBits)
            (2 ^ 63 - 1)) := by
  unfold proofEquivalentTime
  by_cases h : toWork > fromWork
  · simp only [if_pos h]
    by_cases hs : 2 ^ 63 ≤ (toWork - fromWork) * spacing /
        Bitcoin.Block.Index.workOf tipBits
    · have hlt : ¬ (toWork - fromWork) * spacing /
          Bitcoin.Block.Index.workOf tipBits ≤ 2 ^ 63 - 1 := by omega
      simp [min, hs, hlt]
    · have hle : (toWork - fromWork) * spacing /
          Bitcoin.Block.Index.workOf tipBits ≤ 2 ^ 63 - 1 := by omega
      simp [min, hs, hle]
  · simp only [if_neg h]
    by_cases hs : 2 ^ 63 ≤ (fromWork - toWork) * spacing /
        Bitcoin.Block.Index.workOf tipBits
    · have hlt : ¬ (fromWork - toWork) * spacing /
          Bitcoin.Block.Index.workOf tipBits ≤ 2 ^ 63 - 1 := by omega
      simp [min, hs, hlt]
    · have hle : (fromWork - toWork) * spacing /
          Bitcoin.Block.Index.workOf tipBits ≤ 2 ^ 63 - 1 := by omega
      simp [min, hs, hle]

/-- `to` ahead of `from`: positive elapsed equivalent time. -/
@[rule "INV-142"]
theorem proofEquivalentTime_of_gt (toWork fromWork spacing : Nat)
    (tipBits : UInt32) (h : fromWork < toWork)
    (hlt : (toWork - fromWork) * spacing / Bitcoin.Block.Index.workOf tipBits
      < 2 ^ 63) :
    proofEquivalentTime toWork fromWork spacing tipBits =
      Int.ofNat
        ((toWork - fromWork) * spacing / Bitcoin.Block.Index.workOf tipBits) := by
  unfold proofEquivalentTime
  simp only [if_pos h, Nat.not_le.mpr hlt, ite_false]
  simp

/-- `from` ahead of `to`: negative elapsed equivalent time (Core's
`sign = -1` arm). -/
@[rule "INV-142"]
theorem proofEquivalentTime_of_lt (toWork fromWork spacing : Nat)
    (tipBits : UInt32) (h : toWork < fromWork)
    (hlt : (fromWork - toWork) * spacing / Bitcoin.Block.Index.workOf tipBits
      < 2 ^ 63) :
    proofEquivalentTime toWork fromWork spacing tipBits =
      - Int.ofNat
        ((fromWork - toWork) * spacing / Bitcoin.Block.Index.workOf tipBits) := by
  unfold proofEquivalentTime
  simp only [if_neg (Nat.not_lt.mpr (Nat.le_of_lt h)),
    Nat.not_le.mpr hlt, ite_false]
  simp

/-- Equal chainwork gives zero seconds (Core takes the else branch with
`r = 0` and sign `-1`, whose product is still zero). -/
@[rule "INV-142"]
theorem proofEquivalentTime_eq_zero (work spacing : Nat) (tipBits : UInt32) :
    proofEquivalentTime work work spacing tipBits = 0 := by
  unfold proofEquivalentTime
  simp only [Nat.lt_irrefl, if_false, Nat.sub_self, Nat.zero_mul, Nat.zero_div]
  simp

/-- Saturation arm, positive direction: `r.bits() > 63` returns
`int64_t::max`. -/
@[rule "INV-142"]
theorem proofEquivalentTime_saturate_gt (toWork fromWork spacing : Nat)
    (tipBits : UInt32) (h : fromWork < toWork)
    (hsat : 2 ^ 63 ≤
      (toWork - fromWork) * spacing / Bitcoin.Block.Index.workOf tipBits) :
    proofEquivalentTime toWork fromWork spacing tipBits =
      Int.ofNat (2 ^ 63 - 1) := by
  unfold proofEquivalentTime
  simp only [if_pos h, hsat, ite_true]
  simp

/-- Saturation arm, negative direction: `sign * int64_t::max`. -/
@[rule "INV-142"]
theorem proofEquivalentTime_saturate_lt (toWork fromWork spacing : Nat)
    (tipBits : UInt32) (h : toWork < fromWork)
    (hsat : 2 ^ 63 ≤
      (fromWork - toWork) * spacing / Bitcoin.Block.Index.workOf tipBits) :
    proofEquivalentTime toWork fromWork spacing tipBits =
      - Int.ofNat (2 ^ 63 - 1) := by
  unfold proofEquivalentTime
  simp only [if_neg (Nat.not_lt.mpr (Nat.le_of_lt h)), hsat, ite_true]
  simp

/-- **INV-142**, assumevalid guard shape (validation.cpp:2363): for a
tip at least as heavy as the queried block, the 2-week comparison is
exactly the seconds inequality
`|ΔchainWork| · nPowTargetSpacing / GetBlockProof(tip) ≤ 1209600`
(no saturation in this branch). -/
@[rule "INV-142"]
theorem proofEquivalentTime_le_twoWeeks_iff (toWork fromWork spacing : Nat)
    (tipBits : UInt32) (h : fromWork ≤ toWork)
    (hlt : (toWork - fromWork) * spacing / Bitcoin.Block.Index.workOf tipBits
      < 2 ^ 63) :
    proofEquivalentTime toWork fromWork spacing tipBits ≤ 1209600 ↔
      (toWork - fromWork) * spacing / Bitcoin.Block.Index.workOf tipBits
        ≤ 1209600 := by
  by_cases heq : toWork = fromWork
  · subst heq
    simp [proofEquivalentTime_eq_zero]
  · have hgt : fromWork < toWork := by omega
    rw [proofEquivalentTime_of_gt toWork fromWork spacing tipBits hgt hlt]
    exact Int.ofNat_le

/-- INV-142 vector against the difficulty-1 work value 4295032833:
one block of work at 600 s spacing is 600 s; reversing the arguments
negates it; equal chainwork is zero; 2016 blocks are exactly two weeks. -/
@[rule "INV-142"]
theorem proofEquivalentTime_row_vector :
    proofEquivalentTime 4295032833 0 600 0x1d00ffff = 600 ∧
    proofEquivalentTime 0 4295032833 600 0x1d00ffff = -600 ∧
    proofEquivalentTime 0 0 600 0x1d00ffff = 0 ∧
    proofEquivalentTime (2016 * 4295032833) 0 600 0x1d00ffff = 1209600 := by
  decide

/-- Retained work-window auxiliary (a different object from Core's
equivalent time; kept for its existing INV-142 row history, not cited as
the Core function): walking tip-first over a chain of `(nBits, nTime)`
samples, the accumulated work sums `GetBlockProof` while the block time
is at or above `tipTime − 1209600`, and stops at the first block outside
the window. -/
@[rule "INV-142"]
def proofEquivalentWork (tipTime : Int32) : List (UInt32 × Int32) → Nat
  | [] => 0
  | (bits, time) :: rest =>
      if tipTime - twoWeekSeconds ≤ time then
        Bitcoin.Block.Index.workOf bits + proofEquivalentWork tipTime rest
      else 0

/-- Empty chain: no walk, no work (Core returns immediately). -/
theorem proofEquivalentWork_nil (tipTime : Int32) :
    proofEquivalentWork tipTime [] = 0 := rfl

/-- A block INSIDE the window (boundary-inclusive: `tipTime − 1209600 ≤
time`) contributes its full `GetBlockProof` term. -/
theorem proofEquivalentWork_inside (tipTime : Int32) (bits : UInt32)
    (time : Int32) (h : tipTime - twoWeekSeconds ≤ time) :
    proofEquivalentWork tipTime [(bits, time)] =
      Bitcoin.Block.Index.workOf bits := by
  show (if tipTime - twoWeekSeconds ≤ time then
          Bitcoin.Block.Index.workOf bits + proofEquivalentWork tipTime []
        else 0) = Bitcoin.Block.Index.workOf bits
  rw [if_pos h, proofEquivalentWork_nil]
  exact Nat.add_zero _

/-- A block OUTSIDE the window truncates the walk to 0 (the `break`). -/
theorem proofEquivalentWork_outside (tipTime : Int32) (bits : UInt32)
    (time : Int32) (h : time < tipTime - twoWeekSeconds) :
    proofEquivalentWork tipTime [(bits, time)] = 0 := by
  show (if tipTime - twoWeekSeconds ≤ time then
          Bitcoin.Block.Index.workOf bits + proofEquivalentWork tipTime []
        else 0) = 0
  rw [if_neg (Int32.not_le.mpr h)]

/-- INV-142 vector (python3 mirror cross-check, RC12):
difficulty-1 blocks (`0x1d00ffff`) around tip time 1463184400
(window opens at 1461974800): the boundary block counts
`workOf 0x1d00ffff = 4295032833`, one second lower does not, and a
3-block walk = 2 in-window + 1 out = 8590065666. -/
theorem proofEquivalentWork_vector :
    proofEquivalentWork 1463184400 [(0x1d00ffff, 1461974800)] = 4295032833 ∧
    proofEquivalentWork 1463184400 [(0x1d00ffff, 1461974799)] = 0 ∧
    proofEquivalentWork 1463184400
        [(0x1d00ffff, 1463184400), (0x1d00ffff, 1461974800),
          (0x1d00ffff, 1461974799)] = 8590065666 := by decide

/-- info: 'Bitcoin.Invariants.RC12.proofEquivalentWork_vector' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms proofEquivalentWork_vector

end Bitcoin.Invariants.RC12
