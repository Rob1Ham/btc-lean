import Bitcoin.Block.Index
import Bitcoin.Capstone.Pow

/-! # PDW24.lean — chainwork and tip-selection row faces

Five sorry-free promotion theorems, one per claimed rules.yaml
row — the **chainwork/tip band** (workOf / chainWork /
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

/-! ## BLK-113 — the sign-aware decode (`fNegative`) and full GetBlockProof

Core's `arith_uint256::SetCompact` computes `pfNegative` from the
*post-shift* word (`nWord >>= 8*(3-nSize)` on the `nSize ≤ 3` branch), and
`GetBlockProof` (chain.cpp:120-133) rejects `fNegative || fOverflow ||
target == 0` before applying `(~target / (target + 1)) + 1`.  It does
**not** compare the decoded target against `powLimit`; that comparison
belongs to `CheckProofOfWork`.

`workOfSigned` below is the Core-faithful model.  The imported
`Bitcoin.Block.Index.workOf` retains an extra `powLimit` gate, so the two
agree only under the hypotheses of
`workOfSigned_eq_workOf_of_nonneg`, and `workOf_powLimit_diverges` records
the residual divergence.  Keeping the corrected model here (rather than
rewriting the shared core definition) preserves the rest of the index
surface. -/

/-- Core `SetCompact`'s `fNegative` flag (`arith_uint256.cpp:188`):
`nWord != 0 && (nCompact & 0x00800000) != 0`, where `nWord` is the
post-right-shift word.  Testing the unshifted mantissa would flag
`0x02800001` as negative even though Core's shifted `nWord` is zero. -/
@[rule "BLK-113"]
def compactNegative (bits : UInt32) : Bool :=
  Bitcoin.Capstone.Pow.setCompactWord bits != 0 && (bits &&& 0x00800000) != 0

/-- Core `SetCompact`'s `fOverflow` flag (`arith_uint256.cpp:190-192`). -/
@[rule "BLK-113"]
def compactOverflow (bits : UInt32) : Bool :=
  (Bitcoin.Capstone.Pow.setCompactFull bits).overflow

/-- **BLK-113**: `GetBlockProof` (chain.cpp:120-133) — zero for a
negative-flagged, overflowing, or zero compact target; the
complement-division formula otherwise.  There is no `powLimit` gate. -/
@[rule "BLK-113"]
def workOfSigned (bits : UInt32) : Nat :=
  if compactNegative bits = true ∨ compactOverflow bits = true ∨
      compactTarget bits = 0 then 0
  else (2 ^ 256 - 1 - compactTarget bits) / (compactTarget bits + 1) + 1

/-- **BLK-113** (negative branch): a negative-flagged nBits carries zero
work, exactly Core's `fNegative ⇒ 0`. -/
@[rule "BLK-113"]
theorem workOfSigned_negative_zero (bits : UInt32)
    (h : compactNegative bits = true) : workOfSigned bits = 0 := by
  unfold workOfSigned
  rw [if_pos (Or.inl h)]

/-- **BLK-113** (overflow branch): an overflowing nBits carries zero
work, exactly Core's `fOverflow ⇒ 0`. -/
@[rule "BLK-113"]
theorem workOfSigned_overflow_zero (bits : UInt32)
    (h : compactOverflow bits = true) : workOfSigned bits = 0 := by
  unfold workOfSigned
  rw [if_pos (Or.inr (Or.inl h))]

/-- **BLK-113** (agreement with the gated projection): when the decode is
non-negative, non-overflowing, and at most `powLimit`, the faithful model
equals the imported `workOf`.  The extra `powLimit` hypothesis is exactly
the gate the core projection adds. -/
@[rule "BLK-113"]
theorem workOfSigned_eq_workOf_of_nonneg (bits : UInt32)
    (hn : compactNegative bits = false)
    (ho : compactOverflow bits = false)
    (hl : compactTarget bits ≤ powLimit) : workOfSigned bits = workOf bits := by
  have hpl : ¬ powLimit < compactTarget bits := Nat.not_lt.mpr hl
  unfold workOfSigned workOf
  rw [hn, ho]
  simp only [Bool.false_eq_true, false_or]
  by_cases h0 : compactTarget bits = 0
  · simp [h0]
  · simp [h0, hpl]

/-- **BLK-113** (valid branch): a non-negative, non-overflowing, nonzero
decode has the complement-division work `(~target / (target + 1)) + 1`. -/
@[rule "BLK-113"]
theorem workOfSigned_valid_formula (bits : UInt32)
    (hn : compactNegative bits = false) (ho : compactOverflow bits = false)
    (h0 : compactTarget bits ≠ 0) :
    workOfSigned bits =
      (2 ^ 256 - 1 - compactTarget bits) / (compactTarget bits + 1) + 1 := by
  have hv : ¬ (compactNegative bits = true ∨ compactOverflow bits = true ∨
      compactTarget bits = 0) := by
    intro h
    rcases h with h | h | h
    · rw [hn] at h; exact Bool.noConfusion h
    · rw [ho] at h; exact Bool.noConfusion h
    · exact h0 h
  unfold workOfSigned
  rw [if_neg hv]

/-- **BLK-113** (full two-branch sign-aware form). -/
@[rule "BLK-113"]
theorem workOfSigned_eq (bits : UInt32) :
    workOfSigned bits =
      (if compactNegative bits = true ∨ compactOverflow bits = true ∨
          compactTarget bits = 0 then 0
       else (2 ^ 256 - 1 - compactTarget bits) / (compactTarget bits + 1) + 1) := rfl

/-- **BLK-113** witnesses the sign divergence: `0x04801234` has a nonzero
post-shift word and the compact sign bit set (`fNegative`), so Core returns
0 while the core `workOf` (which masks the sign) computes positive work. -/
@[rule "BLK-113"]
theorem workOf_negative_diverges :
    compactNegative 0x04801234 = true ∧ workOfSigned 0x04801234 = 0 ∧
      workOf 0x04801234 ≠ 0 := by
  refine ⟨by decide, workOfSigned_negative_zero _ (by decide), ?_⟩
  decide

/-- **BLK-113** regression (shifted mantissa): `0x02800001` has the sign
bit set and a nonzero *unshifted* mantissa, but Core shifts the mantissa
to zero (`nSize = 2`), so `fNegative` is false. -/
@[rule "BLK-113"]
theorem compactNegative_shifted_word_regression :
    Bitcoin.Capstone.Pow.setCompactWord 0x02800001 = 0 ∧
      (0x02800001 &&& 0x00800000) ≠ 0 ∧
      compactNegative 0x02800001 = false := by
  decide

/-- **BLK-113** regression (negative target): a sign-flagged nonzero word
is rejected before the division. -/
@[rule "BLK-113"]
theorem workOfSigned_negative_regression :
    compactNegative 0x03800123 = true ∧ workOfSigned 0x03800123 = 0 ∧
      workOf 0x03800123 ≠ 0 := by
  decide

/-- **BLK-113** regression (overflow): an exponent above 34 sets
`fOverflow`, so the work is zero regardless of the magnitude. -/
@[rule "BLK-113"]
theorem workOfSigned_overflow_regression :
    compactOverflow 0x23000001 = true ∧ workOfSigned 0x23000001 = 0 := by
  decide

/-- **BLK-113** regression (no `powLimit` gate): `0x1f00ffff` decodes to a
target above mainnet's `powLimit`.  Core's `GetBlockProof` still computes
positive work; the gated `workOf` projection returns zero. -/
@[rule "BLK-113"]
theorem workOf_powLimit_diverges :
    workOf 0x1f00ffff = 0 ∧ 0 < workOfSigned 0x1f00ffff := by
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
