import Bitcoin.Invariants.RC12
import Bitcoin.Block.Index
import BitcoinProofs.AF.PDW30.PDW30b

/-! # PDW29.lean

Route B (PDW16/PDW27 pattern): zero core writes; `@[rule]` tags ride the
theorems below; core defs/theorems imported read-only.
Part 1: RC12 chain-selection rows INV-142 / INV-143 / INV-144.
Pins ⊆ [propext, Classical.choice, Quot.sound] (see PDW29Guards.lean). -/

namespace BitcoinProofs.AF.PDW29

open Bitcoin.Block.Index Bitcoin.Invariants.RC12

/-! ## INV-142 — GetBlockProofEquivalentTime (chain.h:311) -/

/-- The recursive step: an in-window sample adds `workOf bits`, and an
out-of-window sample truncates the whole walk to 0 (Core `break`). -/
@[rule "INV-142"]
theorem proofEquivalentWork_cons (tipTime : Int32) (bits : UInt32) (time : Int32)
    (rest : List (UInt32 × Int32)) :
    proofEquivalentWork tipTime ((bits, time) :: rest) =
      if tipTime - twoWeekSeconds ≤ time then
        Bitcoin.Block.Index.workOf bits + proofEquivalentWork tipTime rest
      else 0 := rfl

/-- Boundary-inclusive: a sample at exactly `tipTime − 1209600` counts. -/
@[rule "INV-142"]
theorem proofEquivalentWork_boundary_in (tipTime : Int32) (bits : UInt32)
    (time : Int32) (h : tipTime - twoWeekSeconds ≤ time) :
    proofEquivalentWork tipTime [(bits, time)] = Bitcoin.Block.Index.workOf bits := by
  rw [proofEquivalentWork_cons, if_pos h]
  exact Nat.add_zero _

/-- One second outside the window stops the walk at 0, ignoring `rest`. -/
@[rule "INV-142"]
theorem proofEquivalentWork_stop (tipTime : Int32) (bits : UInt32) (time : Int32)
    (rest : List (UInt32 × Int32)) (h : time < tipTime - twoWeekSeconds) :
    proofEquivalentWork tipTime ((bits, time) :: rest) = 0 := by
  rw [proofEquivalentWork_cons, if_neg (Int32.not_le.mpr h)]

/-- Work sum over a list of `(nBits, nTime)` samples, in walk order. -/
def prefixWork : List (UInt32 × Int32) → Nat
  | [] => 0
  | (bits, _) :: rest => Bitcoin.Block.Index.workOf bits + prefixWork rest

/-- **INV-142**, general semantics: the tip-first walk equals the work
sum over the MAXIMAL in-window prefix — Core's `break` on the first
sample below `tipTime − 1209600` (chain.h:311, validation.cpp:2363). -/
@[rule "INV-142"]
theorem proofEquivalentWork_eq_prefixWork (tipTime : Int32) :
    ∀ l : List (UInt32 × Int32),
      proofEquivalentWork tipTime l =
        prefixWork (l.takeWhile (fun p => tipTime - twoWeekSeconds ≤ p.2))
  | [] => rfl
  | (bits, time) :: rest => by
      by_cases h : tipTime - twoWeekSeconds ≤ time
      · simp [proofEquivalentWork, prefixWork,
          proofEquivalentWork_eq_prefixWork tipTime rest, h]
      · simp [proofEquivalentWork, h, prefixWork]

/-- INV-142 vector (python3 mirror): boundary-in
4295032833, one second out 0, 3-block walk = 2 in + 1 out = 8590065666. -/
@[rule "INV-142"]
theorem proofEquivalentWork_row_vector :
    proofEquivalentWork 1463184400 [(0x1d00ffff, 1461974800)] = 4295032833 ∧
    proofEquivalentWork 1463184400 [(0x1d00ffff, 1461974799)] = 0 ∧
    proofEquivalentWork 1463184400
        [(0x1d00ffff, 1463184400), (0x1d00ffff, 1461974800),
          (0x1d00ffff, 1461974799)] = 8590065666 := by decide

/-- **INV-142** row face (Core `GetBlockProofEquivalentTime`,
chain.cpp:135-149): signed seconds, `±min(|ΔchainWork| * nPowTargetSpacing
/ GetBlockProof(tip), int64_t::max)`. The sign is positive iff `to` has
more chainwork than `from`. -/
@[rule "INV-142"]
theorem proofEquivalentTime_row (toWork fromWork spacing : Nat)
    (tipBits : UInt32) :
    proofEquivalentTime toWork fromWork spacing tipBits =
      (if toWork > fromWork then (1 : Int) else -1) *
        Int.ofNat
          (min
            ((if toWork > fromWork then toWork - fromWork else fromWork - toWork)
              * spacing / Bitcoin.Block.Index.workOf tipBits)
            (2 ^ 63 - 1)) :=
  proofEquivalentTime_eq_abs toWork fromWork spacing tipBits

/-- **INV-142**, assumevalid call-site shape (validation.cpp:2363): the
guard compares the signed equivalent time against the 2-week constant
`TWO_WEEKS_IN_SECONDS = 60*60*24*7*2`; in the positive non-saturated arm
this is exactly the seconds inequality. -/
@[rule "INV-142"]
theorem proofEquivalentTime_assumevalid_guard (toWork fromWork spacing : Nat)
    (tipBits : UInt32) (h : fromWork ≤ toWork)
    (hlt : (toWork - fromWork) * spacing / Bitcoin.Block.Index.workOf tipBits
      < 2 ^ 63) :
    proofEquivalentTime toWork fromWork spacing tipBits ≤ 1209600 ↔
      (toWork - fromWork) * spacing / Bitcoin.Block.Index.workOf tipBits
        ≤ 1209600 :=
  proofEquivalentTime_le_twoWeeks_iff toWork fromWork spacing tipBits h hlt

/-- INV-142 vector at the real difficulty-1 spacing (600 s):
one difficulty-1 block of chainwork = 600 s, 2016 blocks = 1209600 s,
and reversing the arguments negates the result. -/
@[rule "INV-142"]
theorem proofEquivalentTime_row_vector :
    proofEquivalentTime 4295032833 0 600 0x1d00ffff = 600 ∧
    proofEquivalentTime 0 4295032833 600 0x1d00ffff = -600 ∧
    proofEquivalentTime (2016 * 4295032833) 0 600 0x1d00ffff = 1209600 := by
  decide

/-! ## INV-143 — descendant pruning (InvalidateBlock / SetBlockFailureFlags) -/

/-- Every descendant of the failed height is removed by the pure filter. -/
@[rule "INV-143"]
theorem prunedCandidates_descendant {parentOf : Nat → Option Nat} {failed fuel h : Nat}
    {candidates : List Nat}
    (hd : isDescendantOf parentOf fuel failed h = true) :
    h ∉ prunedCandidates parentOf failed fuel candidates := by
  intro hm
  unfold prunedCandidates at hm
  have hkeep := of_mem_filter
    (p := fun x => !isDescendantOf parentOf fuel failed x)
    (a := h) (l := candidates) hm
  simp [hd] at hkeep

/-- The descendant relation is monotone in its fuel bound. -/
theorem isDescendantOf_mono (parentOf : Nat → Option Nat) :
    ∀ (fuel anc t : Nat), isDescendantOf parentOf fuel anc t = true →
      isDescendantOf parentOf (fuel + 1) anc t = true
  | 0, anc, t, h => by simp [isDescendantOf] at h
  | n + 1, anc, t, h => by
      change ((anc == t) ||
        (match parentOf t with
         | none => false
         | some p => isDescendantOf parentOf n anc p)) = true at h
      change ((anc == t) ||
        (match parentOf t with
         | none => false
         | some p => isDescendantOf parentOf (n + 1) anc p)) = true
      rcases Bool.or_eq_true_iff.mp h with heq | hp
      · have hEq : anc = t := by simpa using heq
        subst hEq
        simp
      · cases hpar : parentOf t with
        | none => rw [hpar] at hp; cases hp
        | some p =>
            rw [hpar] at hp
            change ((anc == t) || isDescendantOf parentOf (n + 1) anc p) = true
            exact Bool.or_eq_true_iff.mpr
              (Or.inr (isDescendantOf_mono parentOf n anc p hp))

theorem isDescendantOf_mono_add (parentOf : Nat → Option Nat) (k fuel anc t : Nat)
    (h : isDescendantOf parentOf fuel anc t = true) :
    isDescendantOf parentOf (fuel + k) anc t = true := by
  induction k with
  | zero => simpa using h
  | succ k ih =>
      have hstep := isDescendantOf_mono parentOf (fuel + k) anc t ih
      simpa [Nat.add_assoc] using hstep

/-- One parent edge: if `mid`'s parent is `p`, a walk from `mid` can be
prefixed by `p`. -/
theorem isDescendantOf_step (parentOf : Nat → Option Nat) (p mid : Nat)
    (hpar : parentOf mid = some p) :
    ∀ (f2 t : Nat), isDescendantOf parentOf f2 mid t = true →
      isDescendantOf parentOf (f2 + 1) p t = true
  | 0, t, h => by simp [isDescendantOf] at h
  | g + 1, t, h => by
      change ((mid == t) ||
        (match parentOf t with
         | none => false
         | some q => isDescendantOf parentOf g mid q)) = true at h
      change ((p == t) ||
        (match parentOf t with
         | none => false
         | some q => isDescendantOf parentOf (g + 1) p q)) = true
      rcases Bool.or_eq_true_iff.mp h with heq | hq
      · have hEq : mid = t := by simpa using heq
        subst hEq
        change ((p == mid) ||
          (match parentOf mid with
           | none => false
           | some q => isDescendantOf parentOf (g + 1) p q)) = true
        rw [hpar]
        change ((p == mid) || isDescendantOf parentOf (g + 1) p p) = true
        exact Bool.or_eq_true_iff.mpr (Or.inr (isDescendantOf_refl parentOf g p))
      · cases hqt : parentOf t with
        | none => rw [hqt] at hq; cases hq
        | some q =>
            rw [hqt] at hq
            change isDescendantOf parentOf g mid q = true at hq
            change ((p == t) || isDescendantOf parentOf (g + 1) p q) = true
            exact Bool.or_eq_true_iff.mpr
              (Or.inr (isDescendantOf_step parentOf p mid hpar g q hq))

/-- Transitivity of the descendant walk. -/
theorem isDescendantOf_trans (parentOf : Nat → Option Nat) :
    ∀ (f1 f2 anc mid t : Nat),
      isDescendantOf parentOf f1 anc mid = true →
      isDescendantOf parentOf f2 mid t = true →
      isDescendantOf parentOf (f1 + f2) anc t = true
  | 0, f2, anc, mid, t, h1, _ => by simp [isDescendantOf] at h1
  | n + 1, f2, anc, mid, t, h1, h2 => by
      change ((anc == mid) ||
        (match parentOf mid with
         | none => false
         | some p => isDescendantOf parentOf n anc p)) = true at h1
      rcases Bool.or_eq_true_iff.mp h1 with heq | hp
      · have hEq : anc = mid := by simpa using heq
        subst hEq
        have hstep := isDescendantOf_mono_add parentOf (n + 1) f2 anc t h2
        simpa [Nat.add_comm] using hstep
      · cases hpar : parentOf mid with
        | none => rw [hpar] at hp; cases hp
        | some p =>
            rw [hpar] at hp
            have hpt := isDescendantOf_step parentOf p mid hpar f2 t h2
            have ih := isDescendantOf_trans parentOf n (f2 + 1) anc p t hp hpt
            simpa [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using ih

/-- **INV-143**: after `failed` is marked, `failed` and every block whose
parent chain reaches it are invalid.  `invalidMarked` is the marking
predicate; the theorem is the propagation law "descendants of invalid are
invalid" (validation.cpp `SetBlockFailureFlags`/`InvalidBlockFound`;
abstracted over the parent-height map, as in BLK-119). -/
def invalidMarked (parentOf : Nat → Option Nat) (failed fuel h : Nat) : Bool :=
  isDescendantOf parentOf fuel failed h

@[rule "INV-143"]
theorem invalidMarked_descendant {parentOf : Nat → Option Nat} {failed fuel g h t : Nat}
    (hh : invalidMarked parentOf failed fuel h = true)
    (ht : isDescendantOf parentOf g h t = true) :
    invalidMarked parentOf failed (fuel + g) t = true :=
  isDescendantOf_trans parentOf fuel g failed h t hh ht

/-- **INV-143**: an invalid-marked block is pruned from the candidate set
(the failure-flag marking and the descendant filter agree). -/
@[rule "INV-143"]
theorem invalidMarked_pruned {parentOf : Nat → Option Nat} {failed fuel h : Nat}
    {candidates : List Nat}
    (hh : invalidMarked parentOf failed fuel h = true) :
    h ∉ prunedCandidates parentOf failed fuel candidates :=
  prunedCandidates_descendant hh

/-! ### INV-143 state face: `nStatus` flags and `SetBlockFailureFlags`

The pure parent relation above is lifted to the actual `nStatus` mutation.
`IndexStatus` is the existing bit-projection model from AF/PDW30b
(`BLOCK_FAILED_VALID` / `BLOCK_FAILED_CHILD`, `markFailedValid`). -/

open BitcoinProofs.AF.PDW30 (IndexStatus markFailedValid)

/-- **INV-143** `SetBlockFailureFlags` (validation.cpp:3707-3717): every
index entry other than the invalid block whose ancestor at the invalid
block's height is that block gets `nStatus |= BLOCK_FAILED_VALID`; all
other entries keep their status. -/
@[rule "INV-143"]
def setBlockFailureFlags (parentOf : Nat → Option Nat) (invalidHeight fuel : Nat)
    (status : Nat → IndexStatus) : Nat → IndexStatus :=
  fun h =>
    if h ≠ invalidHeight ∧ isDescendantOf parentOf fuel invalidHeight h = true
    then markFailedValid (status h) else status h

/-- **INV-143** `InvalidBlockFound` followed by descendant propagation
(validation.cpp:1987-1995 then :3707-3717): the failed block itself is
marked `BLOCK_FAILED_VALID`, then `SetBlockFailureFlags` marks its
descendants. -/
@[rule "INV-143"]
def invalidBlockFoundFlags (parentOf : Nat → Option Nat) (failed fuel : Nat)
    (status : Nat → IndexStatus) : Nat → IndexStatus :=
  setBlockFailureFlags parentOf failed fuel
    (fun k => if k = failed then markFailedValid (status k) else status k)

/-- A descendant targeted by `SetBlockFailureFlags` is marked. -/
@[rule "INV-143"]
theorem setBlockFailureFlags_marks {parentOf : Nat → Option Nat}
    {invalidHeight fuel h : Nat} {status : Nat → IndexStatus}
    (hne : h ≠ invalidHeight)
    (hd : isDescendantOf parentOf fuel invalidHeight h = true) :
    (setBlockFailureFlags parentOf invalidHeight fuel status h).failedValid =
      true := by
  unfold setBlockFailureFlags
  simp [hne, hd, markFailedValid]

/-- An entry outside the descendant set is untouched. -/
@[rule "INV-143"]
theorem setBlockFailureFlags_other {parentOf : Nat → Option Nat}
    {invalidHeight fuel h : Nat} {status : Nat → IndexStatus}
    (hkeep : ¬ (h ≠ invalidHeight ∧
      isDescendantOf parentOf fuel invalidHeight h = true)) :
    setBlockFailureFlags parentOf invalidHeight fuel status h = status h := by
  unfold setBlockFailureFlags
  simp [hkeep]

/-- The failed block itself carries `BLOCK_FAILED_VALID`. -/
@[rule "INV-143"]
theorem invalidBlockFoundFlags_self {parentOf : Nat → Option Nat}
    {failed fuel : Nat} {status : Nat → IndexStatus} :
    (invalidBlockFoundFlags parentOf failed fuel status failed).failedValid =
      true := by
  unfold invalidBlockFoundFlags setBlockFailureFlags
  simp [markFailedValid]

/-- Every `invalidMarked` descendant (and the failed block) carries
`BLOCK_FAILED_VALID` after the mutation. -/
@[rule "INV-143"]
theorem invalidBlockFoundFlags_descendant {parentOf : Nat → Option Nat}
    {failed fuel h : Nat} {status : Nat → IndexStatus}
    (hd : invalidMarked parentOf failed fuel h = true) :
    (invalidBlockFoundFlags parentOf failed fuel status h).failedValid =
      true := by
  unfold invalidBlockFoundFlags setBlockFailureFlags
  by_cases hne : h = failed
  · subst hne
    simp [markFailedValid]
  · have hdesc : isDescendantOf parentOf fuel failed h = true := by
      simpa [invalidMarked] using hd
    simp [hne, hdesc, markFailedValid]

/-- **INV-143** (state propagation): a block marked invalid and all of
its descendants are flagged in the post-failure state; the state-level
counterpart of `invalidMarked_descendant`. -/
@[rule "INV-143"]
theorem failureFlags_propagate {parentOf : Nat → Option Nat}
    {failed fuel g h t : Nat} {status : Nat → IndexStatus}
    (hh : invalidMarked parentOf failed fuel h = true)
    (ht : isDescendantOf parentOf g h t = true) :
    (invalidBlockFoundFlags parentOf failed (fuel + g) status t).failedValid =
      true :=
  invalidBlockFoundFlags_descendant (invalidMarked_descendant hh ht)

/-- INV-143 state vector: chain 3→2→1, fail height 1. Heights 1, 2, 3
carry `BLOCK_FAILED_VALID`; unrelated height 4 does not. -/
@[rule "INV-143"]
theorem invalidBlockFoundFlags_row_vector :
    (invalidBlockFoundFlags
        (fun n => if n = 3 then some 2 else if n = 2 then some 1 else none)
        1 3 (fun _ => {}) 1).failedValid = true ∧
    (invalidBlockFoundFlags
        (fun n => if n = 3 then some 2 else if n = 2 then some 1 else none)
        1 3 (fun _ => {}) 2).failedValid = true ∧
    (invalidBlockFoundFlags
        (fun n => if n = 3 then some 2 else if n = 2 then some 1 else none)
        1 3 (fun _ => {}) 3).failedValid = true ∧
    (invalidBlockFoundFlags
        (fun n => if n = 3 then some 2 else if n = 2 then some 1 else none)
        1 3 (fun _ => {}) 4).failedValid = false := by
  decide

/-- A non-descendant survives exactly when it was a candidate (pure filter). -/
@[rule "INV-143"]
theorem prunedCandidates_survivor {parentOf : Nat → Option Nat} {failed fuel h : Nat}
    {candidates : List Nat}
    (hn : isDescendantOf parentOf fuel failed h = false) :
    h ∈ prunedCandidates parentOf failed fuel candidates ↔ h ∈ candidates := by
  unfold prunedCandidates
  rw [List.mem_filter]
  simp [hn]

/-- INV-143 vector: chain 3→2→1, fail height 1, candidates [1,2,3,4]
⇒ only the unrelated height 4 survives. -/
@[rule "INV-143"]
theorem prunedCandidates_row_vector :
    prunedCandidates (fun n => if n = 3 then some 2 else if n = 2 then some 1 else none)
      1 3 [1, 2, 3, 4] = [4] := by decide

/-! ## INV-144 — cached-invalid re-submission (AcceptBlockHeader) -/

/-- A cached-failed hash re-submits as `duplicate-invalid`, iff cached. -/
@[rule "INV-144"]
theorem submitVerdict_cached_iff (failedCache : ByteArray → Bool) (h : ByteArray) :
    submitVerdict failedCache h = some "duplicate-invalid" ↔ failedCache h = true := by
  unfold submitVerdict
  by_cases hf : failedCache h = true <;> simp [hf]

/-- An uncached hash is not rejected by the cache (returns `none`). -/
@[rule "INV-144"]
theorem submitVerdict_uncached (failedCache : ByteArray → Bool) (h : ByteArray)
    (hf : failedCache h = false) : submitVerdict failedCache h = none := by
  unfold submitVerdict
  rw [if_neg (by simp [hf])]

end BitcoinProofs.AF.PDW29
