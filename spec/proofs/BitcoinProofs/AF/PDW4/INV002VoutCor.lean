import Bitcoin.Consensus.TxCheck

/-!
# INV002VoutCor — T6/INV-002 + TXV-002 promotion proofs (P9, P10)

Rows INV-002 / TXV-002 (`vout` non-empty, `bad-txns-vout-empty`;
core anchor tx_check.cpp:CheckTransaction:24-25 @cce32b168).
Claim commit 5fe77cf.
Statements P9 (reject) + P10 (bound) restated 1:1 verbatim from
`PD03-stmtcheck.lean:51-57` (elaborated green in `PDW4Check.lean`).

Semantics: `checkTransaction`'s second gate rejects an empty
`vout` (given non-empty `vin`) with `some .voutEmpty`; dually an
accepted tx has non-empty `vout`. Proof = the
INV001VinCor/X09-gate-herding skeleton: unfold + gate-splits +
`absurd`/`simp`-disjointness. The P9 reject-side `h` = gate-1's
evidence; P10 splits gates 1..2. No mathlib, no decide.

Axiom-pinned in-file (D2 L3); zero sorryAx expected.
-/

namespace BitcoinProofs.AF.PDW4

open Bitcoin.Data (Tx)
open Bitcoin.Consensus (checkTransaction TxCheckError)

/-- T6/INV-002+TXV-002 (reject dir): empty `vout` is rejected
`bad-txns-vout-empty` (PDW4 honest-repair: PD03-stmtcheck's P9 as
written is under-hypothesized — `h : tx.vout = []` alone does not
force the gate-2 branch (empty `vin` rejects at gate 1 with
`.vinEmpty` instead), so P9-as-proved carries the gate-1 evidence
`hvin`. F-PDW4-003-ii; same-class as P17 = PDW4.md v2). -/
@[rule "INV-002", rule "TXV-002"]
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

/-- T6/INV-002+TXV-002 (bound dir): acceptance implies non-empty
`vout`. -/
@[rule "INV-002", rule "TXV-002"]
theorem checkTransaction_ok_vout_ne_nil (tx : Tx)
    (h : checkTransaction tx = none) : tx.vout ≠ [] := by
  intro hempty
  unfold checkTransaction at h
  rw [hempty] at h
  split at h
  · exact absurd h (by simp)
  · next _ => exact absurd h (by simp)

/-! ## Axiom pins (expected footprints guarded) -/

/-- info: 'BitcoinProofs.AF.PDW4.checkTransaction_voutEmpty_reject' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW4.checkTransaction_voutEmpty_reject

/-- info: 'BitcoinProofs.AF.PDW4.checkTransaction_ok_vout_ne_nil' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW4.checkTransaction_ok_vout_ne_nil

end BitcoinProofs.AF.PDW4
