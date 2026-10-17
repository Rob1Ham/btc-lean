import Bitcoin.Consensus.TxCheck

/-! # PDW22.lean — proof-promotion review, items TOP-106..110
D-STEP TxCheck statement-grade head (claim 5b22617). Route B: zero core
writes, row-face theorems tagged on this file, axiom pins ⊆ charter trio. -/

open Bitcoin.Consensus Bitcoin.Data

namespace BitcoinProofs.AF.PDW22

/-- INV-001 reject lane: an empty input list is `bad-txns-vin-empty`. -/
@[rule "INV-001"]
theorem checkTransaction_vin_empty_reject (tx : Tx) (h : tx.vin = []) :
    checkTransaction tx = some .vinEmpty := by
  simp [checkTransaction, h]

/-- INV-001 pass lane: a passing tx has a non-empty input list. -/
@[rule "INV-001"]
theorem checkTransaction_ok_vin_nonempty (tx : Tx)
    (h : checkTransaction tx = none) : tx.vin ≠ [] := by
  intro hv
  rw [checkTransaction_vin_empty_reject tx hv] at h
  exact absurd h (by simp)

/-- INV-002 reject lane: with inputs present, empty outputs is `bad-txns-vout-empty`. -/
@[rule "INV-002"]
theorem checkTransaction_vout_empty_reject (tx : Tx) (hvin : tx.vin ≠ [])
    (h : tx.vout = []) : checkTransaction tx = some .voutEmpty := by
  simp [checkTransaction, hvin, h]

/-- INV-002 pass lane: a passing tx has a non-empty output list. -/
@[rule "INV-002"]
theorem checkTransaction_ok_vout_nonempty (tx : Tx)
    (h : checkTransaction tx = none) : tx.vout ≠ [] := by
  intro hv
  by_cases hvin : tx.vin = []
  · rw [checkTransaction_vin_empty_reject tx hvin] at h
    exact absurd h (by simp)
  · rw [checkTransaction_vout_empty_reject tx hvin hv] at h
    exact absurd h (by simp)

/-- The output loop preserves non-negativity along a passing run. -/
theorem checkOutputs_none_nonneg (outs : List TxOut) (acc : Amount)
    (h : checkTransaction.checkOutputs outs acc = none) :
    ∀ o ∈ outs, 0 ≤ o.value := by
  induction outs generalizing acc with
  | nil => intro o ho; simp at ho
  | cons o rest ih =>
      intro o' ho'
      by_cases hneg : o.value < 0
      · simp [checkTransaction.checkOutputs, hneg] at h
      · by_cases hbig : MAX_MONEY < o.value
        · simp [checkTransaction.checkOutputs, hneg, hbig] at h
        · by_cases hr : MoneyRange (acc + o.value) = false
          · simp [checkTransaction.checkOutputs, hneg, hbig, hr] at h
          · simp only [checkTransaction.checkOutputs, hneg, hbig, hr, ite_false] at h
            rcases List.mem_cons.mp ho' with rfl | hmem
            · exact Int.not_lt.mp hneg
            · exact ih (acc + o.value) h o' hmem

/-- A passing `checkTransaction` has a passing output loop. -/
theorem checkTransaction_ok_checkOutputs (tx : Tx) (h : checkTransaction tx = none) :
    checkTransaction.checkOutputs tx.vout 0 = none := by
  unfold checkTransaction at h
  repeat' split at h
  all_goals
    rcases hc : checkTransaction.checkOutputs tx.vout 0 with _ | e
    · rfl
    · simp_all

/-- INV-004: a passing tx never contains a negative output value. -/
@[rule "INV-004"]
theorem checkTransaction_ok_outputs_nonneg (tx : Tx)
    (h : checkTransaction tx = none) : ∀ o ∈ tx.vout, 0 ≤ o.value :=
  checkOutputs_none_nonneg tx.vout 0 (checkTransaction_ok_checkOutputs tx h)

/-- The output loop preserves the `MAX_MONEY` upper bound along a passing run. -/
theorem checkOutputs_none_le_MAX_MONEY (outs : List TxOut) (acc : Amount)
    (h : checkTransaction.checkOutputs outs acc = none) :
    ∀ o ∈ outs, o.value ≤ MAX_MONEY := by
  induction outs generalizing acc with
  | nil => intro o ho; simp at ho
  | cons o rest ih =>
      intro o' ho'
      by_cases hneg : o.value < 0
      · simp [checkTransaction.checkOutputs, hneg] at h
      · by_cases hbig : MAX_MONEY < o.value
        · simp [checkTransaction.checkOutputs, hneg, hbig] at h
        · by_cases hr : MoneyRange (acc + o.value) = false
          · simp [checkTransaction.checkOutputs, hneg, hbig, hr] at h
          · simp only [checkTransaction.checkOutputs, hneg, hbig, hr, ite_false] at h
            rcases List.mem_cons.mp ho' with rfl | hmem
            · exact Int.not_lt.mp hbig
            · exact ih (acc + o.value) h o' hmem

/-- INV-005: a passing tx never contains an output value above `MAX_MONEY`. -/
@[rule "INV-005"]
theorem checkTransaction_ok_outputs_le_MAX_MONEY (tx : Tx)
    (h : checkTransaction tx = none) : ∀ o ∈ tx.vout, o.value ≤ MAX_MONEY :=
  checkOutputs_none_le_MAX_MONEY tx.vout 0 (checkTransaction_ok_checkOutputs tx h)

/-- INV-009: a passing non-coinbase tx has no null prevout. -/
@[rule "INV-009"]
theorem checkTransaction_ok_no_null_prevout (tx : Tx)
    (h : checkTransaction tx = none) (hnc : tx.isCoinBase = false) :
    ∀ i ∈ tx.vin, i.prevout.isNull = false := by
  intro i hi
  unfold checkTransaction at h
  repeat' split at h
  all_goals simp_all

end BitcoinProofs.AF.PDW22


/-! ## Axiom pins — all subset [propext, Classical.choice, Quot.sound]. -/
/-- info: 'BitcoinProofs.AF.PDW22.checkTransaction_vin_empty_reject' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW22.checkTransaction_vin_empty_reject

/-- info: 'BitcoinProofs.AF.PDW22.checkTransaction_ok_vin_nonempty' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW22.checkTransaction_ok_vin_nonempty

/-- info: 'BitcoinProofs.AF.PDW22.checkTransaction_vout_empty_reject' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW22.checkTransaction_vout_empty_reject

/-- info: 'BitcoinProofs.AF.PDW22.checkTransaction_ok_vout_nonempty' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW22.checkTransaction_ok_vout_nonempty

/-- info: 'BitcoinProofs.AF.PDW22.checkTransaction_ok_outputs_nonneg' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW22.checkTransaction_ok_outputs_nonneg

/-- info: 'BitcoinProofs.AF.PDW22.checkTransaction_ok_outputs_le_MAX_MONEY' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW22.checkTransaction_ok_outputs_le_MAX_MONEY

/-- info: 'BitcoinProofs.AF.PDW22.checkTransaction_ok_no_null_prevout' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW22.checkTransaction_ok_no_null_prevout

