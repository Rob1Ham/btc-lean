import Bitcoin.TxValidation.Interface

/-!
# INV009PrevoutCor — T7/INV-009 + TXV-009 promotion proof (P11)

PDW4 (proof-promotion review), recovery review 3, 2026-10-17.
Rows INV-009 / TXV-009 (non-coinbase: no null prevout,
`bad-txns-prevout-null`; core anchor tx_check.cpp:62-64
@cce32b168). Claim: `spec/db/findings-af/PDW4.md` @ 5fe77cf
(rank 18 = T7). Statement P11 (bound dir) restated 1:1 verbatim
from `PD03-stmtcheck.lean:105-109` (elaborated green in
`PDW4Check.lean`).

Semantics: acceptance + non-coinbase implies every input's prevout
is non-null (gate 6 = `tx.vin.any (·.prevout.isNull)`; Core's
`bad-txns-prevout-null`). Proof = the 6-gate X09 skeleton
(`checkTransaction_ok_no_dup_prevouts`-shaped): gates 1..5
gate-herded (coinbase branch dies on `hcb` vs `hncb` = Bool
disjointness), gate 6 crushed by `List.any_eq_true` contra
`hi`/`hpo`. No mathlib, no decide, no induction.

Axiom-pinned in-file (D2 L3); zero sorryAx expected.
-/

namespace BitcoinProofs.AF.PDW4

open Bitcoin.Data (Tx TxIn)
open Bitcoin.Consensus (checkTransaction)

/-- T7/INV-009+TXV-009 (bound dir): an accepted non-coinbase has no
null prevouts (`bad-txns-prevout-null`). -/
@[rule "INV-009", rule "TXV-009"]
theorem checkTransaction_ok_prevoutNotNull (tx : Tx)
    (h : checkTransaction tx = none) (hncb : tx.isCoinBase = false)
    (i : TxIn) (hi : i ∈ tx.vin) : i.prevout.isNull = false := by
  cases hpo : i.prevout.isNull with
  | false => rfl
  | true =>
    exfalso
    unfold checkTransaction at h
    split at h; · exact absurd h (by simp)
    split at h; · exact absurd h (by simp)
    split at h; · exact absurd h (by simp)
    split at h
    · exact absurd h (by simp)
    · split at h
      · exact absurd h (by simp)
      · split at h
        · next hcb =>
          rw [hcb] at hncb
          nomatch hncb
        · next hany =>
          cases hcoin : tx.isCoinBase with
          | true =>
            rw [hcoin] at hany
            nomatch hany
          | false =>
            cases hout : (tx.vin.any fun i => i.prevout.isNull) with
            | true =>
              have hall : ∀ x ∈ tx.vin, x.prevout.isNull = false := by
                rw [hout] at h
                simp at h
              have := hall i hi
              rw [hpo] at this
              nomatch this
            | false =>
              have hcontra : (tx.vin.any fun i => i.prevout.isNull) = true :=
                List.any_eq_true.mpr ⟨i, hi, hpo⟩
              have hne : ¬(tx.vin.any fun i => i.prevout.isNull) = true := by
                rw [hout]
                intro hcc
                nomatch hcc
              exact hne hcontra

end BitcoinProofs.AF.PDW4
