import Bitcoin.Wallet.Spend.Selection
import Bitcoin.Conservation.Interface

/-!
# Funding and selection laws

The cheap, universal facts about the wallet spend model: value
conservation, non-negativity of fee and change, the change policy, the
equal-split accounting for subtract-fee-from-outputs, and the validity
of the two deterministic selection strategies.

The conservation statement is phrased in the existing
`Bitcoin.Conservation` vocabulary: a `Funded` value conserves exactly
when `Bitcoin.Numeric.feeOf totalIn totalOut` equals the fee, and
non-negativity then follows from the same `totalOut ≤ totalIn`
hypothesis used by `Bitcoin.Conservation.single_tx_conservation`
(`src/consensus/tx_verify.cpp:186-205`).

## What is not claimed

These are arithmetic laws, not policy theorems.  They do not claim that
a selection is optimal, that a fee rate is sufficient for relay, that a
change output is economical, or that a signature will be valid.  The
worked examples at the end pin concrete integer results against Core's
own unit-test values.
-/

namespace Bitcoin.Wallet.Spend

open Bitcoin.Data

/-! ## Private arithmetic helpers

`omega` does not see through the reducible abbreviation `Amount` in this
toolchain, so the linear identities below are stated over `Int`
explicitly and then applied to `Amount` terms by definitional equality. -/

private theorem int_conserves_change (A B F : Int) :
    A = B + (A - B - F) + F := by omega

private theorem int_conserves_nochange (A B : Int) :
    A = B + (A - B) := by omega

private theorem int_add_sub_assoc (a b c : Int) :
    a + (b - c) = a + b - c := by omega

private theorem int_sub_add_sub (a b c d : Int) :
    (a - b) + (c - d) = a + c - (b + d) := by omega

private theorem int_sffo_conserve (I P F : Int) :
    I = P - (F - (I - P)) + F := by omega

private theorem int_fee_ge (A B F : Int) (h : B + F ≤ A) :
    F ≤ A - B := by omega

private theorem int_nochange_fee_nonneg (A B F : Int) (hf : 0 ≤ F)
    (h : B + F ≤ A) : 0 ≤ A - B := by omega

private theorem int_sub_le_of_le_add (t a r : Int) (h : t ≤ a + r) :
    t - a ≤ r := by omega

private theorem int_sub_nonneg_of_le (t a : Int) (h : a ≤ t) :
    0 ≤ t - a := by omega

private theorem int_le_of_add_le (b f a : Int) (hf : 0 ≤ f) (h : b + f ≤ a) :
    b ≤ a := by omega

private theorem int_le_add_of_sub_le (t a r : Int) (h : t - a ≤ r) :
    t ≤ a + r := by omega

private theorem int_feeOf_forward (I O F : Int) (h : I = O + F) :
    I - O = F := by omega

private theorem int_feeOf_backward (I O F : Int) (h : I - O = F) :
    I = O + F := by omega

/-! ## Sums -/

@[simp] theorem total_nil : total ([] : List Amount) = 0 := rfl

@[simp] theorem total_cons (a : Amount) (l : List Amount) :
    total (a :: l) = a + total l := rfl

/-- Sum distributes over append. -/
theorem total_append (l₁ l₂ : List Amount) :
    total (l₁ ++ l₂) = total l₁ + total l₂ := by
  induction l₁ with
  | nil => simp [total]
  | cons a as ih =>
      simp only [List.cons_append, total_cons, ih, Int.add_assoc]

/-- Sum of a constant list. -/
theorem total_replicate (k : Nat) (v : Amount) :
    total (List.replicate k v) = (k : Amount) * v := by
  induction k with
  | zero => simp [total]
  | succ k ih =>
      rw [List.replicate_succ, total_cons, ih, Int.natCast_add, Int.add_mul]
      simpa [Int.one_mul] using Int.add_comm v ((k : Amount) * v)

/-- Sum is invariant under permutation. -/
theorem total_perm {l₁ l₂ : List Amount} (h : l₁.Perm l₂) :
    total l₁ = total l₂ := by
  unfold total
  exact h.foldr_eq' (fun x _ y _ z => Int.add_left_comm y x z) 0

/-- The descending insertion preserves the multiset. -/
theorem insertDesc_perm (a : Amount) (l : List Amount) :
    (insertDesc a l).Perm (a :: l) := by
  induction l with
  | nil => simp [insertDesc]
  | cons b bs ih =>
      by_cases h : a ≥ b
      · simp [insertDesc, h]
      · simp only [insertDesc, h, ite_false]
        exact (List.Perm.cons b ih).trans (List.Perm.swap a b bs)

/-- Descending sort preserves the multiset. -/
theorem sortDesc_perm (coins : List Amount) :
    (sortDesc coins).Perm coins := by
  induction coins with
  | nil => simp [sortDesc]
  | cons a as ih =>
      exact (insertDesc_perm a (sortDesc as)).trans (List.Perm.cons a ih)

/-- The ascending insertion preserves the multiset. -/
theorem insertAsc_perm (a : Amount) (l : List Amount) :
    (insertAsc a l).Perm (a :: l) := by
  induction l with
  | nil => simp [insertAsc]
  | cons b bs ih =>
      by_cases h : a ≤ b
      · simp [insertAsc, h]
      · simp only [insertAsc, h, ite_false]
        exact (List.Perm.cons b ih).trans (List.Perm.swap a b bs)

/-- Ascending sort preserves the multiset. -/
theorem sortAsc_perm (coins : List Amount) :
    (sortAsc coins).Perm coins := by
  induction coins with
  | nil => simp [sortAsc]
  | cons a as ih =>
      exact (insertAsc_perm a (sortAsc as)).trans (List.Perm.cons a ih)

/-- Sum is invariant under descending sort. -/
theorem total_sortDesc (coins : List Amount) :
    total (sortDesc coins) = total coins :=
  total_perm (sortDesc_perm coins)

/-- Sum is invariant under ascending sort. -/
theorem total_sortAsc (coins : List Amount) :
    total (sortAsc coins) = total coins :=
  total_perm (sortAsc_perm coins)

/-! ## Equal fee shares -/

/-- The number of shares in an equal split is the number of recipients. -/
theorem feeShares_length (fee : Amount) (k : Nat) :
    (feeShares fee k).length = k := by
  cases k with
  | zero => simp [feeShares]
  | succ k => simp [feeShares, List.length_replicate]

/-- The shares add up to the fee, for a positive number of recipients.
This is the accounting identity behind Core's `to_reduce / k` plus
remainder loop (`src/wallet/spend.cpp:1371-1376`). -/
theorem total_feeShares (fee : Amount) (k : Nat) :
    total (feeShares fee (k + 1)) = fee := by
  simp only [feeShares, total_cons, total_replicate]
  exact Int.sub_add_cancel fee ((k : Amount) * (fee / ((k + 1 : Nat) : Amount)))

/-- Applying shares subtracts exactly their sum, provided every flagged
output has a matching share. -/
theorem total_assignShares (outs : List Amount) (flags : List Bool)
    (shares : List Amount) (hlen : shares.length = countTrue flags)
    (hflags : flags.length ≤ outs.length) :
    total (assignShares outs flags shares) = total outs - total shares := by
  induction outs generalizing flags shares with
  | nil =>
      have hflags0 : flags.length = 0 := by simpa using hflags
      have hfl : flags = [] := List.eq_nil_of_length_eq_zero hflags0
      subst hfl
      have hs : shares = [] := List.eq_nil_of_length_eq_zero (by simpa [countTrue] using hlen)
      subst hs
      simp [assignShares, total]
  | cons o os ih =>
      cases flags with
      | nil =>
          have hs : shares = [] := List.eq_nil_of_length_eq_zero (by simpa [countTrue] using hlen)
          subst hs
          simp only [assignShares, total_cons, total_nil]
          rw [ih [] [] (by simp [countTrue]) (by simp)]
          simp
      | cons b fs =>
          cases b with
          | false =>
              cases shares with
              | nil =>
                  simp only [assignShares, total_cons]
                  rw [ih fs [] (by simpa [countTrue] using hlen)
                    (by simpa using hflags)]
                  exact int_add_sub_assoc o (total os) (total ([] : List Amount))
              | cons s ss =>
                  have hlen' : (s :: ss).length = countTrue fs := by
                    simpa [countTrue] using hlen
                  simp only [assignShares, total_cons]
                  rw [ih fs (s :: ss) hlen' (by simpa using hflags)]
                  simpa only [total_cons] using
                    int_add_sub_assoc o (total os) (total (s :: ss))
          | true =>
              cases shares with
              | nil =>
                  have hc : countTrue fs + 1 = 0 := by
                    simpa [countTrue] using hlen.symm
                  omega
              | cons s ss =>
                  have hlen' : ss.length = countTrue fs := by
                    simpa [countTrue] using hlen
                  have hfl : fs.length ≤ os.length := by
                    simpa using hflags
                  simp only [assignShares, total_cons]
                  rw [ih fs ss hlen' hfl]
                  simpa only [total_cons] using
                    int_sub_add_sub o s (total os) (total ss)

/-- Applying the equal split subtracts exactly the fee, provided at least
one output is flagged and every flag has an output. -/
theorem total_subtractFeeFromOutputs (outputs : List Amount) (flags : List Bool)
    (fee : Amount) (hpos : 0 < countTrue flags)
    (hflags : flags.length ≤ outputs.length) :
    total (subtractFeeFromOutputs outputs flags fee) = total outputs - fee := by
  obtain ⟨k, hk⟩ := Nat.exists_eq_succ_of_ne_zero (Nat.ne_of_gt hpos)
  unfold subtractFeeFromOutputs
  have hlen : (feeShares fee (countTrue flags)).length = countTrue flags :=
    feeShares_length fee (countTrue flags)
  rw [total_assignShares outputs flags (feeShares fee (countTrue flags)) hlen hflags]
  rw [hk, total_feeShares]

/-! ## Change-to-source funding -/

/-- Change-to-source funding conserves value, unconditionally: either the
change output absorbs the exact surplus, or the surplus becomes fee. -/
theorem fundWithChange_conserves (inputs outputs : List Amount)
    (feeNeeded minViableChange : Amount) :
    (fundWithChange inputs outputs feeNeeded minViableChange).Conserves := by
  by_cases h : minViableChange ≤ total inputs - total outputs - feeNeeded
  · simp [fundWithChange, Funded.Conserves, Funded.totalIn, Funded.totalOut, h,
      total_append, total_cons, total_nil]
    exact int_conserves_change (total inputs) (total outputs) feeNeeded
  · simp [fundWithChange, Funded.Conserves, Funded.totalIn, Funded.totalOut, h]
    exact int_conserves_nochange (total inputs) (total outputs)

/-- Change-to-source funding never creates negative change when the
minimum viable change is non-negative. -/
theorem fundWithChange_change_nonneg (inputs outputs : List Amount)
    (feeNeeded minViableChange : Amount) (hmin : 0 ≤ minViableChange) :
    (fundWithChange inputs outputs feeNeeded minViableChange).ChangeNonneg := by
  intro c hc
  unfold fundWithChange at hc
  by_cases h : minViableChange ≤ total inputs - total outputs - feeNeeded
  · simp only [h, ite_true] at hc
    have hc' : total inputs - total outputs - feeNeeded = c := Option.some.inj hc
    rw [← hc']
    exact Int.le_trans hmin h
  · simp only [h, ite_false] at hc
    simp at hc

/-- Change-to-source funding never creates change below `minViable`. -/
theorem fundWithChange_change_at_least (inputs outputs : List Amount)
    (feeNeeded minViableChange : Amount) :
    (fundWithChange inputs outputs feeNeeded minViableChange).ChangeAtLeast minViableChange := by
  intro c hc
  unfold fundWithChange at hc
  by_cases h : minViableChange ≤ total inputs - total outputs - feeNeeded
  · simp only [h, ite_true] at hc
    have hc' : total inputs - total outputs - feeNeeded = c := Option.some.inj hc
    rw [← hc']
    exact h
  · simp only [h, ite_false] at hc
    simp at hc

/-- If the minimum viable change is at least the dust threshold, created
change is not dust. -/
theorem fundWithChange_no_dust_change (inputs outputs : List Amount)
    (feeNeeded minViableChange dust : Amount) (hdust : dust ≤ minViableChange) :
    (fundWithChange inputs outputs feeNeeded minViableChange).NoDustChange dust := by
  intro c hc
  have hmin := fundWithChange_change_at_least inputs outputs feeNeeded minViableChange c hc
  exact Int.le_trans hdust hmin

/-- If the minimum viable change is at least dust and non-negative, a
created change output satisfies both conditions. -/
theorem fundWithChange_change_policy (inputs outputs : List Amount)
    (feeNeeded minViableChange dust : Amount) (_hmin : 0 ≤ minViableChange)
    (hdust : dust ≤ minViableChange) :
    (fundWithChange inputs outputs feeNeeded minViableChange).ChangePolicy minViableChange dust := by
  intro c hc
  exact ⟨fundWithChange_change_at_least inputs outputs feeNeeded minViableChange c hc,
    fundWithChange_no_dust_change inputs outputs feeNeeded minViableChange dust hdust c hc⟩

/-- Change-to-source funding pays a non-negative fee whenever the inputs
cover the requested outputs and the requested fee. -/
theorem fundWithChange_fee_nonneg (inputs outputs : List Amount)
    (feeNeeded minViableChange : Amount) (hfee : 0 ≤ feeNeeded)
    (hcover : total outputs + feeNeeded ≤ total inputs) :
    (fundWithChange inputs outputs feeNeeded minViableChange).FeeNonneg := by
  by_cases h : minViableChange ≤ total inputs - total outputs - feeNeeded
  · simp [fundWithChange, Funded.FeeNonneg, h]
    exact hfee
  · simp [fundWithChange, Funded.FeeNonneg, h]
    exact int_le_of_add_le (total outputs) feeNeeded (total inputs) hfee hcover

/-- When the inputs cover the requested outputs and fee, change-to-source
funding pays at least the requested fee.  With no change output the
excess is added to the fee, never subtracted from it. -/
theorem fundWithChange_fee_ge_needed (inputs outputs : List Amount)
    (feeNeeded minViableChange : Amount) (_hfee : 0 ≤ feeNeeded)
    (hcover : total outputs + feeNeeded ≤ total inputs) :
    feeNeeded ≤ (fundWithChange inputs outputs feeNeeded minViableChange).fee := by
  by_cases h : minViableChange ≤ total inputs - total outputs - feeNeeded
  · simp [fundWithChange, h]
  · simp [fundWithChange, h]
    exact int_fee_ge (total inputs) (total outputs) feeNeeded hcover

/-! ## Subtract-fee-from-outputs funding -/

/-- SFFO funding conserves value: the preliminary outputs are reduced by
`to_reduce`, and `to_reduce` is exactly the gap between the requested
fee and the fee already implied by the preliminary outputs. -/
theorem fundSubtractFee_conserves (inputs outputs : List Amount)
    (flags : List Bool) (feeNeeded minViableChange : Amount)
    (hpos : 0 < countTrue flags) (hflags : flags.length ≤ outputs.length) :
    (fundSubtractFee inputs outputs flags feeNeeded minViableChange).Conserves := by
  unfold fundSubtractFee Funded.Conserves Funded.totalIn Funded.totalOut
  dsimp only
  by_cases h : minViableChange ≤ total inputs - total outputs
  · have hflags' : flags.length ≤ (outputs ++ [total inputs - total outputs]).length := by
      simp only [List.length_append, List.length_cons, List.length_nil]
      omega
    simp only [h, ite_true]
    rw [total_subtractFeeFromOutputs (outputs ++ [total inputs - total outputs]) flags
      (feeNeeded - (total inputs - total (outputs ++ [total inputs - total outputs])))
      hpos hflags']
    rw [total_append, total_cons, total_nil]
    simpa using int_sffo_conserve (total inputs)
      (total outputs + (total inputs - total outputs)) feeNeeded
  · simp only [h, ite_false]
    rw [total_subtractFeeFromOutputs outputs flags
      (feeNeeded - (total inputs - total outputs)) hpos hflags]
    exact int_sffo_conserve (total inputs) (total outputs) feeNeeded

/-- SFFO funding pays exactly the requested fee. -/
theorem fundSubtractFee_fee_eq (inputs outputs : List Amount)
    (flags : List Bool) (feeNeeded minViableChange : Amount) :
    (fundSubtractFee inputs outputs flags feeNeeded minViableChange).fee = feeNeeded := rfl

/-- SFFO funding never creates negative change when the minimum viable
change is non-negative. -/
theorem fundSubtractFee_change_nonneg (inputs outputs : List Amount)
    (flags : List Bool) (feeNeeded minViableChange : Amount)
    (hmin : 0 ≤ minViableChange) :
    (fundSubtractFee inputs outputs flags feeNeeded minViableChange).ChangeNonneg := by
  intro c hc
  unfold fundSubtractFee at hc
  dsimp only at hc
  by_cases h : minViableChange ≤ total inputs - total outputs
  · simp only [h, ite_true] at hc
    have hc' : total inputs - total outputs = c := Option.some.inj hc
    rw [← hc']
    exact Int.le_trans hmin h
  · simp only [h, ite_false] at hc
    simp at hc

/-- SFFO funding never creates change below `minViable`. -/
theorem fundSubtractFee_change_at_least (inputs outputs : List Amount)
    (flags : List Bool) (feeNeeded minViableChange : Amount) :
    (fundSubtractFee inputs outputs flags feeNeeded minViableChange).ChangeAtLeast
      minViableChange := by
  intro c hc
  unfold fundSubtractFee at hc
  dsimp only at hc
  by_cases h : minViableChange ≤ total inputs - total outputs
  · simp only [h, ite_true] at hc
    have hc' : total inputs - total outputs = c := Option.some.inj hc
    rw [← hc']
    exact h
  · simp only [h, ite_false] at hc
    simp at hc

/-- If the minimum viable change is at least dust, SFFO change is not
dust. -/
theorem fundSubtractFee_no_dust_change (inputs outputs : List Amount)
    (flags : List Bool) (feeNeeded minViableChange dust : Amount)
    (hdust : dust ≤ minViableChange) :
    (fundSubtractFee inputs outputs flags feeNeeded minViableChange).NoDustChange dust := by
  intro c hc
  have hmin := fundSubtractFee_change_at_least inputs outputs flags feeNeeded
    minViableChange c hc
  exact Int.le_trans hdust hmin

/-- The equal split never subtracts a negative share from an output when
the amount to reduce is non-negative. -/
theorem feeShares_nonneg (fee : Amount) (k : Nat) (hfee : 0 ≤ fee) :
    ∀ s ∈ feeShares fee k, 0 ≤ s := by
  cases k with
  | zero => simp [feeShares]
  | succ k =>
      intro s hs
      simp only [feeShares, List.mem_cons, List.mem_replicate] at hs
      rcases hs with hhead | ⟨_, htail⟩
      · subst s
        have hq : 0 ≤ fee / ((k + 1 : Nat) : Amount) := by
          apply Int.ediv_nonneg hfee
          exact Int.natCast_nonneg _
        have hden : (((k + 1 : Nat) : Amount) ≠ 0) := by
          exact_mod_cast Nat.succ_ne_zero k
        have hqle : ((k + 1 : Nat) : Amount) * (fee / ((k + 1 : Nat) : Amount)) ≤ fee := by
          simpa [Int.mul_comm] using
            Int.ediv_mul_le fee hden
        have hk_le : (k : Amount) ≤ ((k + 1 : Nat) : Amount) := by
          exact_mod_cast Nat.le_succ k
        have hkq_le : (k : Amount) * (fee / ((k + 1 : Nat) : Amount)) ≤
            ((k + 1 : Nat) : Amount) * (fee / ((k + 1 : Nat) : Amount)) :=
          Int.mul_le_mul_of_nonneg_right hk_le hq
        exact Int.sub_nonneg.mpr (Int.le_trans hkq_le hqle)
      · subst s
        exact Int.ediv_nonneg hfee (Int.natCast_nonneg _)

/-- With no shares available, `assignShares` returns its inputs unchanged. -/
theorem assignShares_nil (outs : List Amount) (flags : List Bool) :
    assignShares outs flags [] = outs := by
  induction outs generalizing flags with
  | nil => rfl
  | cons o os ih =>
      cases flags with
      | nil => simp [assignShares, ih]
      | cons b fs => cases b <;> simp [assignShares, ih]

/-- If every preliminary output is at least every fee share, then the
SFFO-adjusted outputs are all non-negative.  This is the arithmetic core
of Core's per-output dust/negative check at
`src/wallet/spend.cpp:1379-1386`; the check itself remains a policy
precondition supplied by the caller. -/
theorem assignShares_all_nonneg (outs : List Amount) (flags : List Bool)
    (shares : List Amount)
    (houts : ∀ a ∈ outs, 0 ≤ a)
    (hshare : ∀ s ∈ shares, 0 ≤ s)
    (hbig : ∀ a ∈ outs, ∀ s ∈ shares, s ≤ a) :
    ∀ a ∈ assignShares outs flags shares, 0 ≤ a := by
  induction outs generalizing flags shares with
  | nil => simp [assignShares]
  | cons o os ih =>
      cases flags with
      | nil =>
          have ho : 0 ≤ o := houts o (by simp)
          have hos : ∀ a ∈ os, 0 ≤ a := fun a ha => houts a (by simp [ha])
          have hbigos : ∀ a ∈ os, ∀ s ∈ shares, s ≤ a :=
            fun a ha s hs => hbig a (by simp [ha]) s hs
          simp only [assignShares, List.mem_cons]
          intro a ha
          rcases ha with rfl | ha
          · exact ho
          · exact ih [] [] hos (by simp) (by simp) a ha
      | cons b fs =>
          cases shares with
          | nil =>
              rw [assignShares_nil]
              exact houts
          | cons s ss =>
              have ho : 0 ≤ o := houts o (by simp)
              have hs0 : 0 ≤ s := hshare s (by simp)
              have hso : s ≤ o := hbig o (by simp) s (by simp)
              have hos : ∀ a ∈ os, 0 ≤ a := fun a ha => houts a (by simp [ha])
              have hss : ∀ s' ∈ ss, 0 ≤ s' := fun s' hs' => hshare s' (by simp [hs'])
              have hbigos : ∀ a ∈ os, ∀ s' ∈ ss, s' ≤ a :=
                fun a ha s' hs' => hbig a (by simp [ha]) s' (by simp [hs'])
              have hbig' : ∀ a ∈ os, ∀ s' ∈ s :: ss, s' ≤ a :=
                fun a ha s' hs' => hbig a (by simp [ha]) s' (by simp [hs'])
              by_cases hb : b
              · simp only [hb, assignShares, List.mem_cons]
                intro a ha
                rcases ha with rfl | ha
                · exact int_sub_nonneg_of_le o s hso
                · exact ih fs ss hos hss hbigos a ha
              · simp only [hb, assignShares, List.mem_cons]
                intro a ha
                rcases ha with rfl | ha
                · exact ho
                · exact ih fs (s :: ss) hos hshare hbig' a ha

/-! ## Selection -/

/-- `takeUntilCovered` only returns amounts from its input. -/
theorem takeUntilCovered_subset (target : Amount) (coins : List Amount) :
    Subset (takeUntilCovered target coins) coins := by
  induction coins generalizing target with
  | nil => simp [takeUntilCovered, Subset]
  | cons a rest ih =>
      by_cases h : target ≤ a
      · simp only [takeUntilCovered, h, ite_true, Subset]
        intro x hx
        rcases List.mem_singleton.mp hx with rfl
        exact List.mem_cons_self
      · simp only [takeUntilCovered, h, ite_false, Subset]
        intro x hx
        rcases List.mem_cons.mp hx with rfl | hx
        · exact List.mem_cons_self
        · exact List.mem_cons_of_mem _ (ih (target - a) x hx)

/-- `takeUntilCovered` covers any non-negative target that the whole pool
covers. -/
theorem takeUntilCovered_covers (target : Amount) (coins : List Amount)
    (htarget : 0 ≤ target) (hcov : target ≤ total coins) :
    target ≤ total (takeUntilCovered target coins) := by
  induction coins generalizing target with
  | nil =>
      simp only [total_nil] at hcov ⊢
      exact hcov
  | cons a rest ih =>
      by_cases h : target ≤ a
      · simp only [takeUntilCovered, h, ite_true, total_cons, total_nil]
        simpa using h
      · have hlt : a < target := Int.lt_of_not_ge h
        have htarget' : 0 ≤ target - a := int_sub_nonneg_of_le target a (Int.le_of_lt hlt)
        have hcov' : target - a ≤ total rest :=
          int_sub_le_of_le_add target a (total rest) (by simpa [total] using hcov)
        have hrec := ih (target - a) htarget' hcov'
        simp only [takeUntilCovered, h, ite_false, total_cons]
        exact int_le_add_of_sub_le target a
          (total (takeUntilCovered (target - a) rest)) hrec

/-- Largest-first selection is valid whenever the pool covers a
non-negative target. -/
theorem largestFirst_valid (target : Amount) (coins : List Amount)
    (htarget : 0 ≤ target) (hcov : target ≤ total coins) :
    SelectionValid target coins (largestFirst target coins) := by
  unfold SelectionValid largestFirst
  constructor
  · intro a ha
    have hsub := takeUntilCovered_subset target (sortDesc coins) a ha
    exact (sortDesc_perm coins).mem_iff.mp hsub
  · apply takeUntilCovered_covers
    · exact htarget
    · rw [total_sortDesc]
      exact hcov

/-- A found covering amount is in the list and covers the target. -/
theorem firstCover_some {target a : Amount} {coins : List Amount}
    (h : firstCover target coins = some a) :
    a ∈ coins ∧ target ≤ a := by
  induction coins with
  | nil => simp [firstCover] at h
  | cons b rest ih =>
      by_cases hb : target ≤ b
      · simp only [firstCover, hb, ite_true, Option.some.injEq] at h
        subst h
        exact ⟨List.mem_cons_self, hb⟩
      · simp only [firstCover, hb, ite_false] at h
        obtain ⟨hmem, hcov⟩ := ih h
        exact ⟨List.mem_cons_of_mem _ hmem, hcov⟩

/-- If no single amount covers the target, every amount is below it. -/
theorem firstCover_none {target : Amount} {coins : List Amount}
    (h : firstCover target coins = none) :
    ∀ a ∈ coins, ¬ target ≤ a := by
  induction coins with
  | nil => simp
  | cons b rest ih =>
      by_cases hb : target ≤ b
      · simp only [firstCover, hb, ite_true] at h
        exact absurd h (by simp)
      · simp only [firstCover, hb, ite_false] at h
        intro a ha
        rcases List.mem_cons.mp ha with rfl | ha
        · exact hb
        · exact ih h a ha

/-- Smallest-fit selection is valid whenever the pool covers a
non-negative target. -/
theorem smallestFit_valid (target : Amount) (coins : List Amount)
    (htarget : 0 ≤ target) (hcov : target ≤ total coins) :
    SelectionValid target coins (smallestFit target coins) := by
  unfold SelectionValid smallestFit
  dsimp only
  have hperm : (sortAsc coins).Perm coins := sortAsc_perm coins
  cases hfind : firstCover target (sortAsc coins) with
  | some a =>
      have hs := firstCover_some hfind
      constructor
      · intro x hx
        rcases List.mem_singleton.mp hx with rfl
        exact hperm.mem_iff.mp hs.1
      · simpa [Covers, total_cons, total_nil] using hs.2
  | none =>
      constructor
      · intro a ha
        exact hperm.mem_iff.mp (takeUntilCovered_subset target (sortAsc coins) a ha)
      · apply takeUntilCovered_covers
        · exact htarget
        · rw [total_sortAsc]
          exact hcov

/-! ## Conservation vocabulary -/

/-- A funded result's equation is the existing
`Bitcoin.Numeric.feeOf` equation. -/
theorem conserves_iff_feeOf (f : Funded) :
    f.Conserves ↔ Bitcoin.Numeric.feeOf f.totalIn f.totalOut = f.fee := by
  unfold Funded.Conserves Bitcoin.Numeric.feeOf
  constructor
  · intro h
    exact int_feeOf_forward f.totalIn f.totalOut f.fee h
  · intro h
    exact int_feeOf_backward f.totalIn f.totalOut f.fee h

/-- Under the same `outputs ≤ inputs` hypothesis as
`Bitcoin.Conservation.single_tx_conservation`, a conserving funding result
has a non-negative fee. -/
theorem conserves_fee_nonneg (f : Funded) (hcons : f.Conserves)
    (hle : f.totalOut ≤ f.totalIn) : f.FeeNonneg := by
  have hfee : Bitcoin.Numeric.feeOf f.totalIn f.totalOut = f.fee :=
    (conserves_iff_feeOf f).mp hcons
  unfold Funded.FeeNonneg
  rw [← hfee]
  exact (Bitcoin.Numeric.feeOf_nonneg_iff f.totalIn f.totalOut).mpr hle

/-! ## Worked numeric examples

The fee-vector values are from `src/test/amount_tests.cpp:26-58`: at
123 sat/kvB, `GetFee(8) = 1`, `GetFee(9) = 2`, `GetFee(121) = 15`,
`GetFee(122) = 16`, `GetFee(999) = 123`, `GetFee(1000) = 123`.

The dust values are the two worked cases in
`src/policy/policy.cpp:33-42`: a 34-byte legacy output costs
`182 * 3000 / 1000 = 546` satoshis, and a 31-byte P2WPKH output costs
`98 * 3000 / 1000 = 294` satoshis.

The funding examples exercise the same residual arithmetic as
`src/wallet/coinselection.cpp:1043-1060` and the SFFO split at
`src/wallet/spend.cpp:1357-1394`. -/

example : (FeeRate.ofSatPerKvB 123).getFee 8 = 1 := by decide

example : (FeeRate.ofSatPerKvB 123).getFee 9 = 2 := by decide

example : (FeeRate.ofSatPerKvB 123).getFee 121 = 15 := by decide

example : (FeeRate.ofSatPerKvB 123).getFee 122 = 16 := by decide

example : (FeeRate.ofSatPerKvB 123).getFee 999 = 123 := by decide

example : (FeeRate.ofSatPerKvB 123).getFee 1000 = 123 := by decide

/-- The default 5 sat/vB effective rate charges 155 satoshis for a
31-vbyte P2WPKH change output
(`src/wallet/test/coinselection_tests.cpp:54-55`). -/
example : (FeeRate.ofSatPerKvB 5000).getFee 31 = 155 := by decide

/-- 204 satoshis is the discard-rate cost of spending a 68-vbyte
P2WPKH input at 3 sat/vB
(`src/wallet/test/coinselection_tests.cpp:54-55`). -/
example : (FeeRate.ofSatPerKvB 3000).getFee 68 = 204 := by decide

example : dustThreshold (FeeRate.ofSatPerKvB 3000) 34 false = 546 := by decide

example : dustThreshold (FeeRate.ofSatPerKvB 3000) 31 true = 294 := by decide

/-- Production's minimum viable change for a P2WPKH change output at a
3 sat/vB discard rate is the dust threshold, 294 satoshis
(`src/wallet/spend.cpp:1188-1193`). -/
example : minViableChange (FeeRate.ofSatPerKvB 3000) 68
    (dustThreshold (FeeRate.ofSatPerKvB 3000) 31 true) = 294 := by decide

/-- Change-to-source: 50,000 in, 30,000 out, 200 fee, 1,000 minimum
change yields 19,800 change and an exact 200 fee. -/
example :
    (fundWithChange [50000] [30000] 200 1000).outputs = [30000, 19800]
      ∧ (fundWithChange [50000] [30000] 200 1000).fee = 200
      ∧ (fundWithChange [50000] [30000] 200 1000).change = some 19800 := by
  decide

/-- No viable change: 50,000 in, 49,000 out, 600 requested fee, 1,000
minimum change.  The 400-satoshi surplus is added to the fee, so the
actual fee is 1,000 and there is no change output. -/
example :
    (fundWithChange [50000] [49000] 600 1000).outputs = [49000]
      ∧ (fundWithChange [50000] [49000] 600 1000).fee = 1000
      ∧ (fundWithChange [50000] [49000] 600 1000).change = none := by
  decide

/-- SFFO with an even split: 50,000 in, 30,000 + 20,000 out, 300 fee.
Both recipients pay 150, the change residual is zero, and the fee is
exactly 300. -/
example :
    (fundSubtractFee [50000] [30000, 20000] [true, true] 300 1000).outputs =
        [29850, 19850]
      ∧ (fundSubtractFee [50000] [30000, 20000] [true, true] 300 1000).fee = 300 := by
  decide

/-- SFFO with a remainder: 301 satoshis over two recipients gives shares
151 and 150 (first recipient pays the remainder). -/
example :
    (fundSubtractFee [50000] [30000, 20000] [true, true] 301 1000).outputs =
        [29849, 19850] := by
  decide

/-- SFFO with change: 50,000 in, 30,000 out, 300 fee, 1,000 minimum
change.  Change is 20,000 and the sole recipient pays the 300 fee. -/
example :
    (fundSubtractFee [50000] [30000] [true] 300 1000).outputs = [29700, 20000]
      ∧ (fundSubtractFee [50000] [30000] [true] 300 1000).change = some 20000 := by
  decide

/-- Largest-first covers 4,000 from {1,000, 3,000, 5,000} by taking the
5,000 coin.  This is the shape of Core's "Select biggest UTXO" case at
`src/wallet/test/coinselection_tests.cpp:155`, but the algorithm is
greedy, not BnB. -/
example : largestFirst 4000 [1000, 3000, 5000] = [5000] := by decide

/-- Largest-first also covers 4,000 by taking 5,000, 3,000 after the
1,000 coin is insufficient singly; here the greedy order takes 5,000
first, so the selection is the singleton. -/
example : largestFirst 4000 [1000, 3000] = [3000, 1000] := by decide

/-- Smallest-fit picks the smallest single coin that covers: 5,000. -/
example : smallestFit 4000 [1000, 3000, 5000] = [5000] := by decide

/-- Smallest-fit accumulates ascending when no single coin covers:
1,000 + 3,000 covers 3,500 when the pool has no 5,000 coin. -/
example : smallestFit 3500 [1000, 3000] = [1000, 3000] := by decide

end Bitcoin.Wallet.Spend
