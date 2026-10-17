import Bitcoin.Block.Pow
import Bitcoin.Block.Index
import Bitcoin.Block.Params
import Bitcoin.Invariants.RC12

/-! # PDW46.lean — proof-promotion review RC27, items TOP-226..230
(PDW46, 2026-10-17; claim 2f2008c).

D-POW difficulty transitions + testnet walk-back
(`Bitcoin/Block/Pow.lean`), D-INDEX invalid-chain work bound
(`Bitcoin/Block/Index.lean`), D-PARAMS constant-space merkle path
replay (`Bitcoin/Block/Params.lean`). Route B: zero core writes, tags
ride THESE theorems, pins ⊆ [propext, Classical.choice, Quot.sound]. -/

namespace BitcoinProofs.AF.PDW46

open Bitcoin.Block.Pow
open Bitcoin.Block.Index
open Bitcoin.Block.Params
open Bitcoin.Chain (compactTarget)

/-! ## BLK-050 / INV-098: `PermittedDifficultyTransition` -/

/-- **BLK-050**: on a period boundary (and without testnet
min-difficulty), a passing transition has the observed decode inside the
rounded clamp-endpoint window `[smallest, largest]`. -/
@[rule "BLK-050"]
theorem permittedDifficultyTransition_bounds (P : PowParams) (height : Nat)
    (oldBits newBits : UInt32)
    (hmin : P.fPowAllowMinDifficultyBlocks = false)
    (hb : height % difficultyAdjustmentInterval P = 0)
    (h : permittedDifficultyTransition P height oldBits newBits = true) :
    compactTarget newBits ≤
        compactTarget (getCompact (min (compactTarget oldBits *
          (P.powTargetTimespan * 4) / P.powTargetTimespan) P.powLimit)) ∧
      compactTarget (getCompact (min (compactTarget oldBits *
        (P.powTargetTimespan / 4) / P.powTargetTimespan) P.powLimit)) ≤
        compactTarget newBits := by
  unfold permittedDifficultyTransition at h
  rw [ite_eq_right (by simp [hmin])] at h
  rw [ite_eq_left (by simp [hb])] at h
  simpa only [Bool.and_eq_true, decide_eq_true_eq] using h

/-- **INV-098**: the audit-side exact face — off a period boundary (and
without min-difficulty) acceptance is literally nBits equality. -/
@[rule "INV-098"]
theorem permittedDifficultyTransition_nonboundary (P : PowParams) (height : Nat)
    (oldBits newBits : UInt32)
    (hmin : P.fPowAllowMinDifficultyBlocks = false)
    (hb : height % difficultyAdjustmentInterval P ≠ 0)
    (h : permittedDifficultyTransition P height oldBits newBits = true) :
    oldBits = newBits := by
  unfold permittedDifficultyTransition at h
  rw [ite_eq_right (by simp [hmin])] at h
  rw [ite_eq_right (by simp [hb])] at h
  exact beq_iff_eq.mp h

/-- **INV-098**: the TOTAL face of `PermittedDifficultyTransition`
(pow.cpp:89-136). Without min-difficulty, a transition passes iff either
(i) the new height is a period boundary and the decoded target lies in the
rounded clamp-endpoint window `[smallest, largest]`, or (ii) it is off the
period boundary and nBits is unchanged. This is the full bounds law (both
branches), not the non-boundary branch alone. -/
@[rule "INV-098"]
theorem permittedDifficultyTransition_true_iff (P : PowParams) (height : Nat)
    (oldBits newBits : UInt32)
    (hmin : P.fPowAllowMinDifficultyBlocks = false) :
    permittedDifficultyTransition P height oldBits newBits = true ↔
      (height % difficultyAdjustmentInterval P = 0 ∧
        compactTarget newBits ≤
          compactTarget (getCompact (min (compactTarget oldBits *
            (P.powTargetTimespan * 4) / P.powTargetTimespan) P.powLimit)) ∧
        compactTarget (getCompact (min (compactTarget oldBits *
          (P.powTargetTimespan / 4) / P.powTargetTimespan) P.powLimit)) ≤
          compactTarget newBits)
      ∨ (height % difficultyAdjustmentInterval P ≠ 0 ∧ oldBits = newBits) := by
  unfold permittedDifficultyTransition
  rw [if_neg (by simp [hmin])]
  by_cases hb : height % difficultyAdjustmentInterval P = 0
  · rw [if_pos (by simp [hb])]
    constructor
    · intro h
      exact Or.inl ⟨hb, by
        simpa only [Bool.and_eq_true, decide_eq_true_eq] using h⟩
    · rintro (⟨_, h⟩ | ⟨hne, _⟩)
      · simpa only [Bool.and_eq_true, decide_eq_true_eq] using h
      · exact absurd hb hne
  · rw [if_neg (by simp [hb])]
    constructor
    · intro h
      exact Or.inr ⟨hb, beq_iff_eq.mp h⟩
    · rintro (⟨hb', _⟩ | ⟨_, he⟩)
      · exact absurd hb' hb
      · rw [he]
        simp

/-- **INV-098**: min-difficulty chains permit every transition
(unconditional accept lane, pow.cpp:96). -/
@[rule "INV-098"]
theorem permittedDifficultyTransition_minDiff (P : PowParams) (height : Nat)
    (oldBits newBits : UInt32) (hmin : P.fPowAllowMinDifficultyBlocks = true) :
    permittedDifficultyTransition P height oldBits newBits = true := by
  simp [permittedDifficultyTransition, hmin]

/-! ## BLK-121: `bestInvalidWork` -/

/-- **BLK-121**: every recorded invalid chain's work is dominated by the
folding maximum (the warning/UI `best_invalid` invariant). -/
@[rule "BLK-121"]
theorem bestInvalidWork_ge_mem (invalid : List (ByteArray × Nat))
    (p : ByteArray × Nat) (hp : p ∈ invalid) :
    p.2 ≤ bestInvalidWork invalid :=
  bestInvalidWork_ge invalid p hp

/-- **BLK-121**: the empty invalid-chain set carries zero work. -/
@[rule "BLK-121"]
theorem bestInvalidWork_nil : bestInvalidWork [] = 0 := rfl

/-- **BLK-121**: a singleton set's maximum is its own work. -/
@[rule "BLK-121"]
theorem bestInvalidWork_singleton (h : ByteArray) (w : Nat) :
    bestInvalidWork [(h, w)] = w := by
  simp [bestInvalidWork]

/-- The fold's maximum is attained by a member (for a nonempty family and
an arbitrary initial accumulator). -/
theorem foldl_max_achieved (xs : List (ByteArray × Nat)) (m : Nat)
    (hne : xs ≠ []) :
    ∃ p ∈ xs, xs.foldl (fun acc q => Nat.max acc q.2) m
      = Nat.max m p.2 := by
  induction xs generalizing m with
  | nil => exact absurd rfl hne
  | cons q rest ih =>
      cases rest with
      | nil =>
          exact ⟨q, by simp, by simp [List.foldl_cons]⟩
      | cons r rs =>
          obtain ⟨p, hp, hfold⟩ := ih (Nat.max m q.2) (by simp)
          simp only [List.foldl_cons] at hfold ⊢
          by_cases hpq : q.2 ≤ p.2
          · refine ⟨p, by simp [hp], ?_⟩
            rw [hfold]
            simp [Nat.max_assoc, Nat.max_eq_right hpq]
          · have hpq' : p.2 < q.2 := Nat.lt_of_not_ge hpq
            refine ⟨q, by simp, ?_⟩
            rw [hfold]
            simp [Nat.max_assoc, Nat.max_eq_left (Nat.le_of_lt hpq')]

/-- **BLK-121**: the tracked maximum is ATTAINED — some recorded invalid
chain has exactly the best work. Together with `bestInvalidWork_ge_mem`
(lower bound) and PDW43's `bestInvalidWork_le` (least upper bound) this
pins the `best_invalid` bookkeeping as the exact maximum of the invalid
family (validation.cpp:1963-1984). -/
@[rule "BLK-121"]
theorem bestInvalidWork_achieved (invalid : List (ByteArray × Nat))
    (hne : invalid ≠ []) :
    ∃ p ∈ invalid, p.2 = bestInvalidWork invalid := by
  obtain ⟨p, hp, hfold⟩ := foldl_max_achieved invalid 0 hne
  refine ⟨p, hp, ?_⟩
  unfold bestInvalidWork
  rw [hfold]
  simp

/-- **BLK-121** (record law): recording one more invalid chain updates the
tracked best work to the maximum of the old best and the new chain's work
— the bookkeeping never loses the highest-work entry. -/
@[rule "BLK-121"]
theorem bestInvalidWork_append_singleton (invalid : List (ByteArray × Nat))
    (p : ByteArray × Nat) :
    bestInvalidWork (invalid ++ [p]) = Nat.max (bestInvalidWork invalid) p.2 := by
  simp [bestInvalidWork, List.foldl_append]

/-! ## BLK-129: constant-space merkle path replay -/

/-- **BLK-129**: a replayed path verifies against the root it produces
(soundness of the constant-space replay). -/
@[rule "BLK-129"]
theorem merklePathRoot_sound (leaf : ByteArray)
    (path : List (Bool × ByteArray)) :
    merklePathVerify (merklePathRoot leaf path) leaf path = true :=
  Bitcoin.Block.Params.merklePathRoot_sound leaf path

/-- **BLK-129**: the empty path is the leaf itself (depth-0 replay). -/
@[rule "BLK-129"]
theorem merklePathRoot_nil (leaf : ByteArray) : merklePathRoot leaf [] = leaf := rfl

/-- **BLK-129**: one replay step — the sibling side selects the pair
order (`isLeftSibling` ⇒ `SHA256d(sib ‖ acc)`). -/
@[rule "BLK-129"]
theorem merklePathRoot_cons (leaf : ByteArray) (b : Bool) (sib : ByteArray)
    (path : List (Bool × ByteArray)) :
    merklePathRoot leaf ((b, sib) :: path) =
      merklePathRoot (if b then Bitcoin.Capstone.Merkle.pairHash sib leaf
        else Bitcoin.Capstone.Merkle.pairHash leaf sib) path := rfl

/-! ## BLK-054: `minDiffWalkBack` -/

/-- The descend condition at step-height `k`: off a period boundary, the
block's nBits is the min-difficulty encoding, and its parent exists. -/
def walkSkip (P : PowParams) (get : Nat → Option IndexNode) (k : Nat) : Bool :=
  k % difficultyAdjustmentInterval P != 0 &&
    (match get k with
     | some idx => idx.bits == getCompact P.powLimit
     | none => false) &&
    (get (k - 1)).isSome

/-- **BLK-054** step law: a skip height is consumed (the walk descends to
its parent's height, Core's `while` body). -/
@[rule "BLK-054"]
theorem minDiffWalkBack_step (P : PowParams) (get : Nat → Option IndexNode)
    (h : Nat) (idx : IndexNode) (hget : get (h + 1) = some idx)
    (hskip : walkSkip P get (h + 1) = true) :
    minDiffWalkBack P get (h + 1) = minDiffWalkBack P get h := by
  unfold walkSkip at hskip
  rw [show h + 1 - 1 = h by omega, hget] at hskip
  simp only [minDiffWalkBack, hget]
  rw [hskip]
  simp

/-- **BLK-054** stop law: the walk returns the nBits of the first ancestor
that is not (off-boundary ∧ min-difficulty ∧ parent-exists). -/
@[rule "BLK-054"]
theorem minDiffWalkBack_stop (P : PowParams) (get : Nat → Option IndexNode)
    (h : Nat) (idx : IndexNode) (hget : get (h + 1) = some idx)
    (hstop : walkSkip P get (h + 1) = false) :
    minDiffWalkBack P get (h + 1) = some idx.bits := by
  unfold walkSkip at hstop
  rw [show h + 1 - 1 = h by omega, hget] at hstop
  simp only [minDiffWalkBack, hget]
  rw [ite_eq_right (by simp [hstop])]

/-- **BLK-054** skip-run law: a run of `n` consecutive skip heights is
walked straight through (`GetNextWorkRequired`'s testnet loop). -/
@[rule "BLK-054"]
theorem minDiffWalkBack_skip_run (P : PowParams) (get : Nat → Option IndexNode) :
    ∀ (n h : Nat),
      (∀ k, h < k → k ≤ h + n → walkSkip P get k = true) →
      minDiffWalkBack P get (h + n) = minDiffWalkBack P get h := by
  intro n
  induction n with
  | zero => intro h _; simp
  | succ n ih =>
    intro h hall
    have hstep : minDiffWalkBack P get (h + n + 1) = minDiffWalkBack P get (h + n) := by
      have hk : h < h + n + 1 := by omega
      have hkl : h + n + 1 ≤ h + (n + 1) := by omega
      have hs := hall (h + n + 1) hk hkl
      cases hg : get (h + n + 1) with
      | none =>
        unfold walkSkip at hs
        rw [hg] at hs
        simp at hs
      | some idx =>
        rw [show h + n + 1 = (h + n) + 1 by omega] at hs hg ⊢
        exact minDiffWalkBack_step P get (h + n) idx hg hs
    rw [show h + (n + 1) = h + n + 1 by omega, hstep]
    exact ih h (by intro k hk hkl; exact hall k (by omega) (by omega))

/-- **BLK-054** nearest-ancestor corollary: a stopping ancestor `h+1`
with an all-skip window above it is exactly where the walk from the top
stops, returning that ancestor's nBits. -/
@[rule "BLK-054"]
theorem minDiffWalkBack_nearest (P : PowParams) (get : Nat → Option IndexNode)
    (n h : Nat) (idx : IndexNode) (hget : get (h + 1) = some idx)
    (hstop : walkSkip P get (h + 1) = false)
    (hall : ∀ k, h + 1 < k → k ≤ h + 1 + n → walkSkip P get k = true) :
    minDiffWalkBack P get (h + 1 + n) = some idx.bits := by
  rw [minDiffWalkBack_skip_run P get n (h + 1) hall]
  exact minDiffWalkBack_stop P get h idx hget hstop

/-! ## BLK-123: `assumevalidSkipped` (swap-in for the yielded BLK-129) -/

/-- **BLK-123**: with no assumevalid pin nothing is ever skipped. -/
@[rule "BLK-123"]
theorem assumevalidSkipped_none (inputHeight : Nat) (timeGuardOk : Bool) :
    assumevalidSkipped none inputHeight timeGuardOk = false := rfl

/-- **BLK-123**: at or above the pinned ancestor nothing is skipped. -/
@[rule "BLK-123"]
theorem assumevalidSkipped_at_or_above (a h : Nat) (g : Bool) (hle : a ≤ h) :
    assumevalidSkipped (some a) h g = false := by
  simp only [assumevalidSkipped, Option.map_some, Option.getD_some]
  rw [ite_eq_right (by simp [Nat.not_lt.mpr hle])]

/-- **BLK-123**: strictly below the ancestor but with a failing
equivalent-time guard nothing is skipped. -/
@[rule "BLK-123"]
theorem assumevalidSkipped_below_no_guard (a h : Nat) (hlt : h < a) :
    assumevalidSkipped (some a) h false = false := by
  simp only [assumevalidSkipped, Option.map_some, Option.getD_some]
  rw [ite_eq_left (by simp [hlt])]

/-- **BLK-123**: the positive lane - strictly below the ancestor with a
satisfied time guard skips script checks (trust parameterized). -/
@[rule "BLK-123"]
theorem assumevalidSkipped_below_guard (a h : Nat) (hlt : h < a) :
    assumevalidSkipped (some a) h true = true := by
  simp only [assumevalidSkipped, Option.map_some, Option.getD_some]
  rw [ite_eq_left (by simp [hlt])]

/-- **BLK-123** (full characterization): with an assumevalid pin `a`, the
skip holds iff the input is STRICTLY below the ancestor AND the
equivalent-time guard `g` holds. The guard is an explicit trust parameter
(the caller supplies the 2-week equivalent-time result); no skip is
possible without it. This quantifies over both the trust parameter and the
guard, not just the `h < a` instance. -/
@[rule "BLK-123"]
theorem assumevalidSkipped_some_iff (a h : Nat) (g : Bool) :
    assumevalidSkipped (some a) h g = true ↔ h < a ∧ g = true := by
  unfold assumevalidSkipped
  simp only [Option.map_some, Option.getD_some]
  by_cases hlt : h < a <;> simp [hlt]

/-! ## BLK-123 — the 2-week equivalent-time guard and the pin

Core does not take an arbitrary guard bit.  In `ConnectBlock` the
skip-eligible branch requires
`GetBlockProofEquivalentTime(best_header, pindex, best_header, params) >
TWO_WEEKS_IN_SECONDS` (validation.cpp:2363-2380); the comparison is
strict, and `TWO_WEEKS_IN_SECONDS = 60*60*24*7*2 = 1209600`
(validation.cpp:2348).  The following model derives the guard from the
work inputs (`GetBlockProofEquivalentTime`, chain.cpp:135-150) and states
the skip against the exact pin (`defaultAssumeValid`, block 966143,
kernel/chainparams.cpp:142). -/

/-- `TWO_WEEKS_IN_SECONDS` (validation.cpp:2348), tied definitionally to
RC12's `twoWeekSeconds` window constant (RC12.lean:80). -/
@[rule "BLK-123"]
def TWO_WEEKS_IN_SECONDS : Int :=
  (Bitcoin.Invariants.RC12.twoWeekSeconds).toInt

theorem TWO_WEEKS_IN_SECONDS_eq : TWO_WEEKS_IN_SECONDS = 1209600 := rfl

/-- The RC12 walk and the assumevalid guard are the same 2-week window. -/
theorem twoWeekSeconds_eq_guard_constant :
    (Bitcoin.Invariants.RC12.twoWeekSeconds).toInt = TWO_WEEKS_IN_SECONDS := rfl

/-- `GetBlockProofEquivalentTime` in the ancestor case
(chain.cpp:135-150): the work distance from `ancestor` to `tip`, scaled
by `nPowTargetSpacing` and divided by the tip block's own work.  The
sign/cap branches of Core are irrelevant to the assumevalid call, where
the first argument is the best header and the second is its ancestor
(the difference is non-negative). -/
@[rule "BLK-123"]
def blockProofEquivalentTime (tipWork ancestorWork tipBlockWork
    targetSpacing : Nat) : Nat :=
  (tipWork - ancestorWork) * targetSpacing / tipBlockWork

/-- Core's guard: script checks are skippable only when the equivalent
time is STRICTLY greater than two weeks (validation.cpp:2363-2364:
`<= TWO_WEEKS_IN_SECONDS` means "block too recent"). -/
@[rule "BLK-123"]
def equivTimeGuard (equivTime : Int) : Bool :=
  decide (TWO_WEEKS_IN_SECONDS < equivTime)

/-- **BLK-123**: the guard is exactly the strict 2-week threshold, not an
arbitrary bit. -/
@[rule "BLK-123"]
theorem equivTimeGuard_iff (equivTime : Int) :
    equivTimeGuard equivTime = true ↔ 1209600 < equivTime := by
  unfold equivTimeGuard
  rw [decide_eq_true_eq, TWO_WEEKS_IN_SECONDS_eq]

/-- **BLK-123** (derived guard): the guard consumed by the skip is
computed from the work distances via `GetBlockProofEquivalentTime`. -/
@[rule "BLK-123"]
def assumevalidGuard (tipWork ancestorWork tipBlockWork targetSpacing : Nat) :
    Bool :=
  equivTimeGuard (Int.ofNat
    (blockProofEquivalentTime tipWork ancestorWork tipBlockWork targetSpacing))

/-- **BLK-123** (integrated skip): the assumevalid skip at pin `a` with
the Core-derived guard. -/
@[rule "BLK-123"]
def assumevalidSkippedGuarded (a h : Nat) (equivTime : Int) : Bool :=
  assumevalidSkipped (some a) h (equivTimeGuard equivTime)

/-- **BLK-123** (full characterization against the derived guard):
with pin `a`, the skip holds iff the input is strictly below the
ancestor AND the equivalent time exceeds two weeks. -/
@[rule "BLK-123"]
theorem assumevalidSkippedGuarded_iff (a h : Nat) (equivTime : Int) :
    assumevalidSkippedGuarded a h equivTime = true ↔
      h < a ∧ 1209600 < equivTime := by
  unfold assumevalidSkippedGuarded
  rw [assumevalidSkipped_some_iff]
  rw [equivTimeGuard_iff]

/-- **BLK-123** (guard from the walk): the guard is true exactly when
the `GetBlockProofEquivalentTime` value clears two weeks. -/
@[rule "BLK-123"]
theorem assumevalidGuard_iff (tipWork ancestorWork tipBlockWork
    targetSpacing : Nat) :
    assumevalidGuard tipWork ancestorWork tipBlockWork targetSpacing = true ↔
      1209600 <
        (blockProofEquivalentTime tipWork ancestorWork tipBlockWork
          targetSpacing : Nat) := by
  unfold assumevalidGuard
  rw [equivTimeGuard_iff]
  exact Int.ofNat_lt

/-- **BLK-123** (boundary vector): one difficulty period (2016 blocks at
600 s) is exactly two weeks, so it is NOT enough; one more block clears
the strict guard.  This is the `<= TWO_WEEKS_IN_SECONDS` rejection at
validation.cpp:2364. -/
@[rule "BLK-123"]
theorem assumevalidGuard_two_weeks_boundary :
    assumevalidGuard 2016 0 1 600 = false ∧
      assumevalidGuard 2017 0 1 600 = true := by
  constructor <;> decide

/-- **BLK-123** (pin): `defaultAssumeValid` is mainnet block 966143
(kernel/chainparams.cpp:142), and the skip is exactly below it. -/
@[rule "BLK-123"]
theorem assumevalidSkipped_default_pin_iff (h : Nat) (equivTime : Int) :
    assumevalidSkippedGuarded assumevalidMainnetHeight h equivTime = true ↔
      h < 966143 ∧ 1209600 < equivTime := by
  rw [assumevalidSkippedGuarded_iff]
  have hpin : assumevalidMainnetHeight = 966143 := rfl
  rw [hpin]

/-- **BLK-123** (pin, positive lane): strictly below block 966143 with a
clearing equivalent time skips script checks. -/
@[rule "BLK-123"]
theorem assumevalidSkipped_default_below_guard (h : Nat) (equivTime : Int)
    (hlt : h < 966143) (hg : 1209600 < equivTime) :
    assumevalidSkippedGuarded assumevalidMainnetHeight h equivTime = true :=
  (assumevalidSkipped_default_pin_iff h equivTime).mpr ⟨hlt, hg⟩

/-- **BLK-123** (pin, negative lane): at or above block 966143 nothing is
skipped, regardless of the guard. -/
@[rule "BLK-123"]
theorem assumevalidSkipped_default_at_or_above (h : Nat) (equivTime : Int)
    (hle : 966143 ≤ h) :
    assumevalidSkippedGuarded assumevalidMainnetHeight h equivTime = false := by
  unfold assumevalidSkippedGuarded
  have hnot : ¬ h < assumevalidMainnetHeight := by
    have hpin : assumevalidMainnetHeight = 966143 := rfl
    rw [hpin]
    exact Nat.not_lt.mpr hle
  simp [assumevalidSkipped, hnot]

/-- **BLK-123** (walk link): RC12's window walk uses the same constant;
a block below `tipTime − 1209600` is outside the walk window and
contributes zero (the `break`). -/
@[rule "BLK-123"]
theorem proofEquivalentWork_window_link (tipTime : Int32) (bits : UInt32)
    (time : Int32) (h : time < tipTime - 1209600) :
    Bitcoin.Invariants.RC12.proofEquivalentWork tipTime [(bits, time)] = 0 := by
  have h' : time < tipTime - Bitcoin.Invariants.RC12.twoWeekSeconds := by
    simpa [Bitcoin.Invariants.RC12.twoWeekSeconds] using h
  exact Bitcoin.Invariants.RC12.proofEquivalentWork_outside tipTime bits time h'

end BitcoinProofs.AF.PDW46
