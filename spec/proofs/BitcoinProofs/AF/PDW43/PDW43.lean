import Bitcoin.Block.Pow
import Bitcoin.Block.Index
import Bitcoin.Block.Params
import Bitcoin.DataLaws.Interface

/-! # PDW43.lean — proof-promotion review RC27, items TOP-211..215

Claim `30897db`. Route B (zero core writes). Part A: the D-INDEX /
D-PARAMS status-debt tail.

* **BLK-121** `bestInvalidWork` (Block/Index.lean:295,
  validation.cpp:1963-1984) — max over the invalid-chain work set.
  In-tree lemma covers only the lower bound (`ge_mem`); the new work here
  is the **least upper bound** lane: if every recorded work is ≤ m then
  the fold is ≤ m (and `nil = 0`).
* **BLK-065** `cachedVerdict` (Block/Params.lean:80,
  validation.cpp:4205-4235) — genesis exempt from all header checks, and
  a known hash short-circuits to its cached verdict. New work: the
  **unknown-hash lane** (`none`) and the genesis-overrides-cache lane.

Pins ⊆ [propext, Classical.choice, Quot.sound] (guards in PDW43Guards).
-/

namespace BitcoinProofs.AF.PDW43

open Bitcoin.Block.Index
open Bitcoin.Block.Params

/-! ## BLK-121 — `bestInvalidWork` is the least upper bound -/

/-- The fold never exceeds an upper bound of all entries. -/
theorem foldl_max_le (xs : List (ByteArray × Nat)) (m : Nat)
    (hm : ∀ p ∈ xs, p.2 ≤ m) :
    xs.foldl (fun acc p => Nat.max acc p.2) 0 ≤ m := by
  have gen : ∀ (ys : List (ByteArray × Nat)) (init : Nat), init ≤ m →
      (∀ p ∈ ys, p.2 ≤ m) →
      ys.foldl (fun acc p => Nat.max acc p.2) init ≤ m := by
    intro ys
    induction ys with
    | nil => intro init hi _; simpa using hi
    | cons p rest ih =>
      intro init hi hmem
      simp only [List.foldl_cons]
      exact ih (Nat.max init p.2) (Nat.max_le.mpr ⟨hi, hmem p (by simp)⟩)
        (fun q hq => hmem q (by simp [hq]))
  exact gen xs 0 (Nat.zero_le m) hm

/-- BLK-121: the recorded invalid work set has no member above the fold. -/
@[rule "BLK-121"]
theorem bestInvalidWork_ge (invalid : List (ByteArray × Nat)) (p : ByteArray × Nat)
    (hp : p ∈ invalid) : p.2 ≤ bestInvalidWork invalid :=
  foldl_max_ge_mem invalid 0 p hp

/-- BLK-121 (upper lane): the fold is below every common upper bound. -/
@[rule "BLK-121"]
theorem bestInvalidWork_le (invalid : List (ByteArray × Nat)) (m : Nat)
    (hm : ∀ p ∈ invalid, p.2 ≤ m) : bestInvalidWork invalid ≤ m :=
  foldl_max_le invalid m hm

/-- BLK-121 base lane: the empty invalid set has zero best work. -/
@[rule "BLK-121"]
theorem bestInvalidWork_nil : bestInvalidWork [] = 0 := rfl

/-! ## BLK-065 — genesis exemption and cached verdict -/

/-- BLK-065: genesis is exempt — the verdict is `true` regardless of cache. -/
@[rule "BLK-065"]
theorem cachedVerdict_genesis_exempt (idx : Nat → Option IndexEntry) (self : Nat) :
    cachedVerdict idx self true = some true := rfl

/-- BLK-065: a known hash returns exactly its cached verdict. -/
@[rule "BLK-065"]
theorem cachedVerdict_known_verdict (idx : Nat → Option IndexEntry) (self : Nat)
    (e : IndexEntry) (hfound : idx self = some e) :
    cachedVerdict idx self false = some e.valid := by
  unfold cachedVerdict
  simp [hfound]

/-- BLK-065 (unknown lane): an absent hash produces no verdict. -/
@[rule "BLK-065"]
theorem cachedVerdict_unknown (idx : Nat → Option IndexEntry) (self : Nat)
    (hmiss : idx self = none) : cachedVerdict idx self false = none := by
  unfold cachedVerdict
  simp [hmiss]

/-! ## BLK-046/047 — the retarget scaling and the BIP94 base -/

open Bitcoin.Block.Pow
open Bitcoin.Chain

/-- The effective retarget timespan (Core's clamped `nActualTimespan`,
pow.cpp:66-76), as the `Int` the definition computes. -/
def clampedSpan (P : PowParams) (lastTime firstTime : UInt32) : Int :=
  let raw : Int := (lastTime.toNat : Int) - (firstTime.toNat : Int)
  if raw < ((P.powTargetTimespan / 4 : Nat) : Int) then ((P.powTargetTimespan / 4 : Nat) : Int)
  else if raw > ((P.powTargetTimespan * 4 : Nat) : Int) then ((P.powTargetTimespan * 4 : Nat) : Int)
  else raw

/-- BLK-046: outside `fPowNoRetargeting` the new nBits is the truncated
scaled target, capped at `powLimit` and re-encoded with `GetCompact`. -/
@[rule "BLK-046"]
theorem calculateNextWorkRequired_scaled (P : PowParams)
    (lastBits lastTime firstTime firstBits : UInt32)
    (h : P.fPowNoRetargeting = false) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits
      = getCompact (min ((if P.enforceBIP94 = true then compactTarget firstBits
            else compactTarget lastBits)
            * (clampedSpan P lastTime firstTime).toNat / P.powTargetTimespan)
          P.powLimit) := by
  simp only [calculateNextWorkRequired, h, Bool.false_eq_true, ite_false,
    clampedSpan]

/-- BLK-046 bound: the clamped timespan never exceeds `4·T` (the upper
clamp), so the scaling never raises the target by more than 4×. -/
@[rule "BLK-046"]
theorem clampedSpan_le (P : PowParams) (lastTime firstTime : UInt32) :
    (clampedSpan P lastTime firstTime).toNat ≤ P.powTargetTimespan * 4 := by
  dsimp only [clampedSpan]
  split
  · simp only [Int.toNat_natCast]; omega
  · split
    · simp only [Int.toNat_natCast]; omega
    · rw [Int.toNat_le]; omega

/-- BLK-047: under BIP94 the retarget base is the first-of-period nBits. -/
@[rule "BLK-047"]
theorem calculateNextWorkRequired_bip94_base (P : PowParams)
    (lastBits lastTime firstTime firstBits : UInt32)
    (h : P.fPowNoRetargeting = false) (hb : P.enforceBIP94 = true) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits
      = getCompact (min (compactTarget firstBits
            * (clampedSpan P lastTime firstTime).toNat / P.powTargetTimespan)
          P.powLimit) := by
  rw [calculateNextWorkRequired_scaled P lastBits lastTime firstTime firstBits h, hb]
  simp

/-- BLK-047 coherence: BIP94 can change the result only when the
first-of-period bits differ from the last block's. -/
@[rule "BLK-047"]
theorem calculateNextWorkRequired_base_eq (P : PowParams)
    (lastBits lastTime firstTime firstBits : UInt32) (hb : firstBits = lastBits) :
    calculateNextWorkRequired P lastBits lastTime firstTime firstBits
      = calculateNextWorkRequired P lastBits lastTime firstTime lastBits := by
  cases P.fPowNoRetargeting <;> cases P.enforceBIP94 <;>
    simp [calculateNextWorkRequired, hb]

/-! ## BLK-054 — the testnet min-difficulty walk-back -/

/-- BLK-054 base: height 0 is the head of the walk. -/
@[rule "BLK-054"]
theorem minDiffWalkBack_zero (P : PowParams) (get : Nat → Option IndexNode) :
    minDiffWalkBack P get 0 = (get 0).map (·.bits) := rfl

/-- BLK-054: a period boundary is never walked past. -/
@[rule "BLK-054"]
theorem minDiffWalkBack_boundary_stops (P : PowParams) (get : Nat → Option IndexNode)
    (h : Nat) (hbound : (h + 1) % difficultyAdjustmentInterval P = 0) :
    minDiffWalkBack P get (h + 1) = (get (h + 1)).map (·.bits) := by
  cases hv : get (h + 1) with
  | none => simp [minDiffWalkBack, hv]
  | some idx => simp [minDiffWalkBack, hv, hbound]

/-- BLK-054: a non-min-difficulty block terminates the walk immediately. -/
@[rule "BLK-054"]
theorem minDiffWalkBack_stop_of_bits (P : PowParams) (get : Nat → Option IndexNode)
    (h : Nat) (idx : IndexNode) (hv : get (h + 1) = some idx)
    (hb : idx.bits ≠ getCompact P.powLimit) :
    minDiffWalkBack P get (h + 1) = some idx.bits := by
  simp [minDiffWalkBack, hv, hb]


/-! ## BLK-066 — `IsFinalTx` exact finality (swap-in for yielded BLK-065) -/

open Bitcoin.DataLaws

/-- BLK-066: `IsFinalTx` is exactly the three-arm disjunction of
tx_verify.cpp:23-43 (locktime 0, below the domain cutoff, or every input
`SEQUENCE_FINAL`). -/
@[rule "BLK-066"]
theorem isFinalTx_iff_row (tx : Bitcoin.Data.Tx) (height mtp : UInt32) :
    isFinalTx tx height mtp = true ↔
      tx.locktime = 0 ∨
        tx.locktime < (if locktimeIsTimeDomain tx.locktime then mtp else height) ∨
        ∀ i ∈ tx.vin, i.sequence = SEQUENCE_FINAL := by
  unfold isFinalTx
  simp [List.all_eq_true, beq_iff_eq, or_assoc]

/-- BLK-066 reject lane: a transaction is non-final exactly when its
locktime is nonzero, not below the cutoff, and some input is not
`SEQUENCE_FINAL`. -/
@[rule "BLK-066"]
theorem isFinalTx_false_iff (tx : Bitcoin.Data.Tx) (height mtp : UInt32) :
    isFinalTx tx height mtp = false ↔
      tx.locktime ≠ 0 ∧
        ¬ (tx.locktime < (if locktimeIsTimeDomain tx.locktime then mtp else height)) ∧
        ∃ i ∈ tx.vin, i.sequence ≠ SEQUENCE_FINAL := by
  unfold isFinalTx
  simp [beq_iff_eq, and_assoc]

end BitcoinProofs.AF.PDW43
