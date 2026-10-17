import Bitcoin.Block.Index

/-! # PDW24.lean — proof-promotion review, items TOP-116..120
(PDW24, review RC22, 2026-10-17; claim v1 = 5f12442).

Five sorry-free promotion theorems, one per claimed rules.yaml
row — the **X08-B3 chainwork/tip band** (workOf / chainWork /
mostWork?, core `Bitcoin/Block/Index.lean`):

* **BLK-113** `workOf` (Index.lean:50) → `workOf_zero_invalid`
  (invalid-decode → 0) + `workOf_difficulty_one` (genesis
  nBits 0x1d00ffff carries positive work).
* **BLK-114** `chainWork` (Index.lean:70) →
  `chainWork_cons_eq` (the nChainWork fold equation) +
  `chainWork_genesis` (genesis = own work, accumulator-0).
* **INV-141** `workOf` (chain.h:305→GetBitsProof) →
  `workOf_zero_invalid` + `workOf_pos_of_inRange` (the
  GetBlockProof-compact bounds→positive-work law).
* **INV-140** `mostWork?` (V:3199) →
  `mostWork?_pair_maximality` (the 2-candidate
  ActivateBestChainStep work-comparison verdict).
* **BLK-115** `mostWork?` (Index.lean:125) →
  `mostWork?_maximality` (the selected tip's work ≥ every
  candidate's) + `mostWork?_mem_verdict` (the member
  work-comparison face).

Route B (PDW11..16 pattern): zero core writes, tags `@[rule
"row"]` ride THESE theorems (the core tags sit on the DEFS =
the PD02 DEF-tagged class = thm+attr+flip gap); all pins ⊆ the
charter trio `[propext, Classical.choice, Quot.sound]`; zero
`sorryAx`. -/

namespace BitcoinProofs.AF.PDW24

open Bitcoin.Block.Index
open Bitcoin.Chain

/-! ## BLK-113 / INV-141: the work function (GetBitsProof) -/

/-- **BLK-113**: an out-of-range decode (zero or above-powLimit
compact target) carries zero work (chain.cpp:127's
`negative || overflow || target == 0` → 0 gate). -/
@[rule "BLK-113"]
theorem workOf_zero_invalid (bits : UInt32)
    (h : compactTarget bits = 0 ∨ powLimit < compactTarget bits) :
    workOf bits = 0 := by
  unfold workOf
  split
  · rfl
  · next hg => exact absurd h hg

/-- **BLK-113** (valid-decode branch): in range, the work is exactly
`(~target / (target + 1)) + 1`, where `~target = 2^256 − 1 − target`. -/
@[rule "BLK-113"]
theorem workOf_valid_formula (bits : UInt32)
    (h0 : compactTarget bits ≠ 0) (hl : ¬ powLimit < compactTarget bits) :
    workOf bits =
      (2 ^ 256 - 1 - compactTarget bits) / (compactTarget bits + 1) + 1 := by
  have hv : ¬ (compactTarget bits = 0 ∨ powLimit < compactTarget bits) := by
    intro h
    rcases h with h | h
    · exact h0 h
    · exact hl h
  unfold workOf
  rw [ite_eq_right hv]

/-- **BLK-113** (full row): unconditional two-branch form of
`GetBlockProof` — zero for an invalid decode, the complement-division
formula otherwise. -/
@[rule "BLK-113"]
theorem workOf_eq (bits : UInt32) :
    workOf bits =
      (if compactTarget bits = 0 ∨ powLimit < compactTarget bits then 0
       else (2 ^ 256 - 1 - compactTarget bits) / (compactTarget bits + 1) + 1) := rfl

/-! ## BLK-113 — the sign-aware decode (`fNegative`)

The core `compactTarget` masks the compact sign bit `0x00800000` (it keeps
only `0x007fffff`), so `workOf` alone cannot see Core's `fNegative` gate.
The following sign-aware model is stated here because the decode lives in
`Bitcoin/Chain/Basic.lean` and `workOf` in `Bitcoin/Block/Index.lean`,
neither of which is in this lane's edit surface.  `workOfSigned` extends
the existing gate with exactly the missing negative branch; on every
non-negative nBits it is definitionally the core `workOf`. -/

/-- Core `SetCompact`'s `fNegative` flag (`arith_uint256.cpp:188`):
`nWord != 0 && (nCompact & 0x00800000) != 0`. -/
@[rule "BLK-113"]
def compactNegative (bits : UInt32) : Bool :=
  (bits &&& 0x007fffff) != 0 && (bits &&& 0x00800000) != 0

/-- **BLK-113**: `GetBitsProof` with the `fNegative` gate restored —
zero for a negative-flagged or zero/above-`powLimit` compact target, the
complement-division formula otherwise (chain.cpp:125-133:
`if (fNegative || fOverflow || bnTarget == 0) return 0;`). -/
@[rule "BLK-113"]
def workOfSigned (bits : UInt32) : Nat :=
  if compactNegative bits = true ∨ compactTarget bits = 0 ∨
      powLimit < compactTarget bits then 0
  else (2 ^ 256 - 1 - compactTarget bits) / (compactTarget bits + 1) + 1

/-- **BLK-113** (negative branch): a negative-flagged nBits carries zero
work, exactly Core's `fNegative ⇒ 0`. -/
@[rule "BLK-113"]
theorem workOfSigned_negative_zero (bits : UInt32)
    (h : compactNegative bits = true) : workOfSigned bits = 0 := by
  unfold workOfSigned
  rw [if_pos (Or.inl h)]

/-- **BLK-113** (non-negative agreement): on nBits whose sign bit is not
set, the sign-aware model is exactly the core `workOf`; the correction
only adds Core's missing negative branch. -/
@[rule "BLK-113"]
theorem workOfSigned_eq_workOf_of_nonneg (bits : UInt32)
    (h : compactNegative bits = false) : workOfSigned bits = workOf bits := by
  unfold workOfSigned workOf
  rw [h]
  simp only [Bool.false_eq_true, false_or]

/-- **BLK-113** (valid branch): in range and non-negative, the work is
exactly `(~target / (target + 1)) + 1`. -/
@[rule "BLK-113"]
theorem workOfSigned_valid_formula (bits : UInt32)
    (hn : compactNegative bits = false) (h0 : compactTarget bits ≠ 0)
    (hl : ¬ powLimit < compactTarget bits) :
    workOfSigned bits =
      (2 ^ 256 - 1 - compactTarget bits) / (compactTarget bits + 1) + 1 := by
  have hv : ¬ (compactNegative bits = true ∨ compactTarget bits = 0 ∨
      powLimit < compactTarget bits) := by
    intro h
    rcases h with h | h | h
    · rw [hn] at h; exact Bool.noConfusion h
    · exact h0 h
    · exact hl h
  unfold workOfSigned
  rw [if_neg hv]

/-- **BLK-113** (full two-branch sign-aware form). -/
@[rule "BLK-113"]
theorem workOfSigned_eq (bits : UInt32) :
    workOfSigned bits =
      (if compactNegative bits = true ∨ compactTarget bits = 0 ∨
          powLimit < compactTarget bits then 0
       else (2 ^ 256 - 1 - compactTarget bits) / (compactTarget bits + 1) + 1) := rfl

/-- **BLK-113** witnesses the Core divergence: `0x04801234` has the
compact sign bit set (`fNegative`), so Core returns 0 while the core
`workOf` (which masks the sign) computes positive work. -/
@[rule "BLK-113"]
theorem workOf_negative_diverges :
    compactNegative 0x04801234 = true ∧ workOfSigned 0x04801234 = 0 ∧
      workOf 0x04801234 ≠ 0 := by
  refine ⟨by decide, workOfSigned_negative_zero _ (by decide), ?_⟩
  decide

/-- **INV-141**: difficulty-1 (genesis, nBits 0x1d00ffff)
carries positive work (chain.cpp:132-133's in-range successor
division face). -/
@[rule "INV-141"]
theorem workOf_difficulty_one : 0 < workOf 0x1d00ffff := by
  exact workOf_difficulty_one_pos

/-- **INV-141**: an in-range nonzero decode (the GetBlockProof
compact bounds) always carries positive work. -/
@[rule "INV-141"]
theorem workOf_pos_of_inRange (bits : UInt32)
    (h : 0 < compactTarget bits)
    (hl : compactTarget bits ≤ powLimit) : 0 < workOf bits := by
  exact workOf_pos_of_valid bits h hl

/-! ## BLK-114: chainwork accumulation (nChainWork) -/

/-- **BLK-114**: `nChainWork(B) = nChainWork(prev) +
work(B.nBits)` — the fold equation (chain.h's per-block
increment), as a rewrite lemma. -/
@[rule "BLK-114"]
theorem chainWork_cons_eq (b : UInt32) (rest : List UInt32) :
    chainWork (b :: rest) = workOf b + chainWork rest := by
  rfl

/-- **BLK-114**: the empty chain (pre-genesis) carries zero work
— the accumulator starts at 0. -/
@[rule "BLK-114"]
theorem chainWork_genesis : chainWork [] = 0 := by
  rfl

/-- **BLK-114** (genesis = own work): the singleton genesis chain
carries exactly its own block's `nBits` work. -/
@[rule "BLK-114"]
theorem chainWork_genesis_own (b : UInt32) : chainWork [b] = workOf b := by
  simp [chainWork]

/-! ## BLK-115 / INV-140: most-work tip selection -/

/-- **BLK-115** (maximality, my tagged restatement of the core
`mostWork_work_ge`): the selected tip's work is ≥ every candidate's
— `FindMostWorkChain`'s max-over-valid-candidates law. -/
@[rule "BLK-115"]
theorem mostWork?_maximality (tips : List Tip) (t : Tip) (ht : t ∈ tips)
    (sel : Tip) (h : mostWork? tips = some sel) :
    t.chainWork ≤ sel.chainWork :=
  mostWork_work_ge tips t ht sel h

/-- The selected winner is itself a member of the candidate list. -/
theorem mostWork?_mem : ∀ (tips : List Tip) (sel : Tip),
    mostWork? tips = some sel → sel ∈ tips := by
  intro tips
  induction tips with
  | nil =>
    intro sel h
    simp [mostWork?] at h
  | cons u rest ih =>
    intro sel h
    rw [mostWork?_cons] at h
    split at h
    · rename_i hnone
      simp only [Option.some.injEq] at h
      subst h
      exact List.mem_cons_self ..
    · rename_i b hb
      simp only [Option.some.injEq] at h
      unfold betterTip at h
      split at h
      · subst h
        exact List.mem_cons_self ..
      · subst h
        exact List.mem_cons_of_mem u (ih b hb)

/-- **BLK-115** (full row): the selected active tip is one of the
valid/data-complete candidates and has maximal `nChainWork` among them.
`ok` is the caller's validity + data-completeness gate (Core's
`IsValid`/`HaveTxsDownloaded` filter); `mostWork?` sees only the
post-filter candidate list, so the maximality is over that list. -/
@[rule "BLK-115"]
theorem mostWork?_filtered_maximality (ok : Tip → Bool) (tips : List Tip)
    (sel : Tip) (h : mostWork? (tips.filter ok) = some sel) :
    sel ∈ tips.filter ok ∧
      ∀ t : Tip, t ∈ tips.filter ok → t.chainWork ≤ sel.chainWork :=
  ⟨mostWork?_mem (tips.filter ok) sel h,
   fun t ht => mostWork_work_ge (tips.filter ok) t ht sel h⟩

/-- **INV-140** (the two-candidate ActivateBestChainStep verdict): on
`[a, b]` the selected tip dominates BOTH candidates' accumulated
work — the best-chain = most-accumulated-work comparison face. -/
@[rule "INV-140"]
theorem mostWork?_pair_maximality (a b : Tip) :
    ∀ sel : Tip, mostWork? [a, b] = some sel →
      a.chainWork ≤ sel.chainWork ∧ b.chainWork ≤ sel.chainWork := by
  intro sel h
  exact ⟨mostWork_work_ge [a, b] a (by simp) sel h,
    mostWork_work_ge [a, b] b (by simp) sel h⟩
