import Bitcoin.Consensus.TxCheck

/-! # PDW59.lean — TOP-316/317: stateless `CheckTransaction` empty-vector gates

PDW59 (review RC29), claim `da681d5`. Route B, zero core writes.
Row faces for `Bitcoin.Consensus.checkTransaction`
(TxCheck.lean:85, `tx_check.cpp:22-27` @ cce32b168): gate 1 rejects
`vin = []` with `bad-txns-vin-empty`; gate 2 rejects `vout = []` with
`bad-txns-vout-empty`. Each row: exact reject lane + acceptance-bound
direction. No mathlib, no decide on the tx, no induction.
-/

namespace BitcoinProofs.AF.PDW59

open Bitcoin.Data (Tx)
open Bitcoin.Consensus (checkTransaction TxCheckError)

/-- TXV-001 (reject): empty `vin` ⇒ `bad-txns-vin-empty`. -/
@[rule "TXV-001"]
theorem checkTransaction_vinEmpty_reject (tx : Tx) (h : tx.vin = []) :
    checkTransaction tx = some TxCheckError.vinEmpty := by
  unfold checkTransaction
  rw [h]
  rfl

/-- TXV-001 (bound): acceptance implies non-empty `vin`. -/
@[rule "TXV-001"]
theorem checkTransaction_ok_vin_ne_nil (tx : Tx)
    (h : checkTransaction tx = none) : tx.vin ≠ [] := by
  intro hempty
  rw [checkTransaction_vinEmpty_reject tx hempty] at h
  simp at h

/-- TXV-002 (reject): non-empty `vin` + empty `vout` ⇒
`bad-txns-vout-empty` (gate 1 must be passed first — the honest
hypothesis the PDW4 P9 repair identified). -/
@[rule "TXV-002"]
theorem checkTransaction_voutEmpty_reject (tx : Tx)
    (hvin : tx.vin ≠ []) (h : tx.vout = []) :
    checkTransaction tx = some TxCheckError.voutEmpty := by
  unfold checkTransaction
  rw [h]
  split
  · next h1 => simp at h1; exact absurd h1 hvin
  · next _ =>
    split
    · rfl
    · next h2 => exact absurd (by simp) h2

/-- TXV-002 (bound): acceptance implies non-empty `vout`. -/
@[rule "TXV-002"]
theorem checkTransaction_ok_vout_ne_nil (tx : Tx)
    (h : checkTransaction tx = none) : tx.vout ≠ [] := by
  intro hempty
  have hvin : tx.vin ≠ [] := checkTransaction_ok_vin_ne_nil tx h
  rw [checkTransaction_voutEmpty_reject tx hvin hempty] at h
  simp at h

end BitcoinProofs.AF.PDW59
