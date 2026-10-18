import Bitcoin.Consensus.TxCheck

/-! # PDW59b.lean — TOP-318..320: `checkOutputs` value-loop checks

PDW59 (RC29), claim `da681d5`. Route B, zero core writes.
Row faces for `checkTransaction.checkOutputs` (TxCheck.lean:101,
`tx_check.cpp:31-42` @ cce32b168): per-output non-negativity
(`bad-txns-vout-negative`, CVE-2010-5139), per-output MAX_MONEY bound
(`bad-txns-vout-toolarge`), and the cumulative MoneyRange gate
(`bad-txns-txouttotal-toolarge`). -/

namespace BitcoinProofs.AF.PDW59

open Bitcoin.Data (Amount TxOut)
open Bitcoin.Consensus (checkTransaction TxCheckError)

/-- TXV-004+TXV-005: acceptance ⇒ every output value is in
`[0, MAX_MONEY]`. -/
theorem checkOutputs_none_bounds (l : List TxOut) (acc : Amount)
    (h : checkTransaction.checkOutputs l acc = none) :
    ∀ o ∈ l, 0 ≤ o.value ∧ o.value ≤ Bitcoin.Data.MAX_MONEY := by
  induction l generalizing acc with
  | nil => intro o ho; simp at ho
  | cons o rest ih =>
    simp only [checkTransaction.checkOutputs] at h
    split at h
    · simp at h
    · next hneg =>
      split at h
      · simp at h
      · next hbig =>
        split at h
        · simp at h
        · next _ =>
          intro x hx
          rcases List.mem_cons.mp hx with rfl | hx'
          · exact ⟨Int.not_lt.mp hneg, Int.not_lt.mp hbig⟩
          · exact ih (acc + o.value) h x hx'

/-- TXV-004 (bound): acceptance ⇒ no negative output value. -/
@[rule "TXV-004"]
theorem checkOutputs_none_nonneg (l : List TxOut) (acc : Amount)
    (h : checkTransaction.checkOutputs l acc = none) :
    ∀ o ∈ l, 0 ≤ o.value :=
  fun o ho => (checkOutputs_none_bounds l acc h o ho).1

/-- TXV-004 (reject): a negative output anywhere forces rejection. -/
@[rule "TXV-004"]
theorem checkOutputs_neg_reject (l : List TxOut) (acc : Amount)
    (h : ∃ o ∈ l, o.value < 0) :
    checkTransaction.checkOutputs l acc ≠ none := by
  intro hnone
  obtain ⟨o, ho, hneg⟩ := h
  have hnn := checkOutputs_none_nonneg l acc hnone o ho
  exact absurd hneg (Int.not_lt.mpr hnn)

/-- TXV-005 (bound): acceptance ⇒ every output value ≤ MAX_MONEY. -/
@[rule "TXV-005"]
theorem checkOutputs_none_le_MAX (l : List TxOut) (acc : Amount)
    (h : checkTransaction.checkOutputs l acc = none) :
    ∀ o ∈ l, o.value ≤ Bitcoin.Data.MAX_MONEY :=
  fun o ho => (checkOutputs_none_bounds l acc h o ho).2

/-- TXV-005 (reject): an over-MAX output anywhere forces rejection. -/
@[rule "TXV-005"]
theorem checkOutputs_tooLarge_reject (l : List TxOut) (acc : Amount)
    (h : ∃ o ∈ l, o.value > Bitcoin.Data.MAX_MONEY) :
    checkTransaction.checkOutputs l acc ≠ none := by
  intro hnone
  obtain ⟨o, ho, hbig⟩ := h
  have hle := checkOutputs_none_le_MAX l acc hnone o ho
  exact absurd hbig (Int.not_lt.mpr hle)

/-- TXV-006 (bound): a MoneyRange'd accumulator stays MoneyRange through
the whole accepted fold — the checked-accumulation discipline. -/
@[rule "TXV-006"]
theorem checkOutputs_none_total_moneyRange (l : List TxOut) (acc : Amount)
    (hacc : Bitcoin.Data.MoneyRange acc = true)
    (h : checkTransaction.checkOutputs l acc = none) :
    Bitcoin.Data.MoneyRange (l.foldl (fun a o => a + o.value) acc) = true := by
  induction l generalizing acc with
  | nil => simpa using hacc
  | cons o rest ih =>
    simp only [checkTransaction.checkOutputs] at h
    split at h
    · simp at h
    · next hneg =>
      split at h
      · simp at h
      · next hbig =>
        split at h
        · simp at h
        · next hmr =>
          have hmr' : Bitcoin.Data.MoneyRange (acc + o.value) = true := by
            simpa using hmr
          simpa using ih (acc + o.value) hmr' h

/-- TXV-006 (reject): a head prefix escaping MoneyRange with in-range
value yields exactly `bad-txns-txouttotal-toolarge`. -/
@[rule "TXV-006"]
theorem checkOutputs_prefix_overflow (o : TxOut) (rest : List TxOut) (acc : Amount)
    (h1 : 0 ≤ o.value) (h2 : o.value ≤ Bitcoin.Data.MAX_MONEY)
    (hmr : Bitcoin.Data.MoneyRange (acc + o.value) = false) :
    checkTransaction.checkOutputs (o :: rest) acc = some TxCheckError.txoutTotalTooLarge := by
  simp only [checkTransaction.checkOutputs]
  rw [ite_eq_right (Int.not_lt.mpr h1), ite_eq_right (Int.not_lt.mpr h2)]
  simp [hmr]

end BitcoinProofs.AF.PDW59
