import Bitcoin.Consensus.TxCheck

/-!
# INV001VinCor — T5/INV-001 + TXV-001 promotion proofs (P7, P8)

PDW4 (proof-promotion review), recovery review 3, 2026-10-17.
Rows INV-001 / TXV-001 (`vin` non-empty, `bad-txns-vin-empty`;
core anchor tx_check.cpp:CheckTransaction:22-23 @cce32b168).
Claim: `spec/db/findings-af/PDW4.md` @ 5fe77cf (rank 16 = T5).
Statements P7 (reject) + P8 (bound) restated 1:1 verbatim from
`PD03-stmtcheck.lean:43-49` (elaborated green in
`PDW2Check`-pattern copy `PDW4Check.lean`, this lane).

Semantics: `checkTransaction`'s leading gate rejects an empty
`vin` with `some .vinEmpty` (reject dir), and dually an accepted
tx (result `none`) has non-empty `vin` (bound dir). Proof = the
X09 `checkTransaction_weight_reject`/`_bound` skeleton
(TxValidation/LocktimeSigOps.lean:498-531): unfold + gate-split +
`absurd`/`simp`-disjointness — no mathlib, no decide, no
induction.

Axiom-pinned in-file (D2 L3); zero sorryAx expected.
-/

namespace BitcoinProofs.AF.PDW4

open Bitcoin.Data (Tx)
open Bitcoin.Consensus (checkTransaction TxCheckError)

/-- T5/INV-001+TXV-001 (reject dir): empty `vin` is rejected
`bad-txns-vin-empty`. -/
@[rule "INV-001", rule "TXV-001"]
theorem checkTransaction_vinEmpty_reject (tx : Tx) (h : tx.vin = []) :
    checkTransaction tx = some TxCheckError.vinEmpty := by
  unfold checkTransaction
  rw [h]
  simp

/-- T5/INV-001+TXV-001 (bound dir): acceptance implies non-empty
`vin`. -/
@[rule "INV-001", rule "TXV-001"]
theorem checkTransaction_ok_vin_ne_nil (tx : Tx)
    (h : checkTransaction tx = none) : tx.vin ≠ [] := by
  intro hempty
  unfold checkTransaction at h
  rw [hempty] at h
  split at h
  · exact absurd h (by simp)
  · next hn => exact absurd hn (by simp)

/-! ## Axiom pins (expected footprints guarded) -/

/-- info: 'BitcoinProofs.AF.PDW4.checkTransaction_vinEmpty_reject' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW4.checkTransaction_vinEmpty_reject

/-- info: 'BitcoinProofs.AF.PDW4.checkTransaction_ok_vin_ne_nil' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW4.checkTransaction_ok_vin_ne_nil

end BitcoinProofs.AF.PDW4
