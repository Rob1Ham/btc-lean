import Bitcoin.Consensus.TxCheck

/-!
# INV008CbLengthCor — T8/INV-008 promotion proof (P12)

Row INV-008 (coinbase scriptSig length ∈ [2,100],
`bad-cb-length`; core anchor tx_check.cpp:55-58 @cce32b168).
Claim commit 5fe77cf.
Statement P12 (bound dir) restated 1:1 verbatim from
`PD03-stmtcheck.lean:97-103` (elaborated green in `PDW4Check.lean`).

Semantics: acceptance + coinbase + `tx.vin = [i]` implies the
scriptSig length bounds (gate 5). Proof = P11's gate-herding
skeleton up to the coinbase branch; the `[i]`-match-`Eq.refl`
branch reduces `h` to the cbLength bounds (`simp_all` on the
`len < MIN || len > MAX`-decide), gate 6's outer `¬(tx.isCoinBase
= true)`-twin dies on `hcb`; the core-only `¬(A ∧ B)` wrap:
`And`-goal-by-`by_cases`-split (`hle`/`hge`), `key`-contradiction
closures by `omega` (Nat-only goals).

Axiom-pinned in-file (D2 L3); zero sorryAx expected.
-/

namespace BitcoinProofs.AF.PDW4

open Bitcoin.Data (Tx TxIn)
open Bitcoin.Consensus (checkTransaction MIN_CB_LENGTH MAX_CB_LENGTH)

/-- T8/INV-008 (bound dir): an accepted coinbase has scriptSig
length in [2, 100] (`bad-cb-length`). -/
@[rule "INV-008"]
theorem checkTransaction_ok_cbLength (tx : Tx)
    (h : checkTransaction tx = none) (hcb : tx.isCoinBase = true)
    (i : TxIn) (hvin : tx.vin = [i]) :
    MIN_CB_LENGTH ≤ i.scriptSig.bytes.size ∧
      i.scriptSig.bytes.size ≤ MAX_CB_LENGTH := by
  have key : ¬(Bitcoin.Consensus.MIN_CB_LENGTH ≤ i.scriptSig.bytes.size ∧
      i.scriptSig.bytes.size ≤ Bitcoin.Consensus.MAX_CB_LENGTH) → False := by
    intro hbad
    have hbad : ¬(MIN_CB_LENGTH ≤ i.scriptSig.bytes.size ∧
        i.scriptSig.bytes.size ≤ MAX_CB_LENGTH) := hbad
    unfold checkTransaction at h
    split at h; · exact absurd h (by simp)
    split at h; · exact absurd h (by simp)
    split at h; · exact absurd h (by simp)
    split at h
    · exact absurd h (by simp)
    · split at h
      · exact absurd h (by simp)
      · split at h
        · next hcoin =>
          rw [hvin] at hcoin
          cases hcoin
          · have hb : MIN_CB_LENGTH ≤ i.scriptSig.bytes.size ∧ i.scriptSig.bytes.size ≤ MAX_CB_LENGTH := by simpa using h
            exact hbad hb
        · next hany =>
          have habs := hany i hvin
          nomatch habs
  by_cases hle : MIN_CB_LENGTH ≤ i.scriptSig.bytes.size
  · by_cases hge : i.scriptSig.bytes.size ≤ MAX_CB_LENGTH
    · exact And.intro hle hge
    · exact False.elim (key (fun hcc => by
        have hlt : i.scriptSig.bytes.size > MAX_CB_LENGTH := by omega
        have := hcc.2
        omega))
  · exact False.elim (key (fun hcc => by
      have hlt : MIN_CB_LENGTH > i.scriptSig.bytes.size := by omega
      have := hcc.1
      omega))

/-! ## Axiom pins (expected footprints guarded) -/

/-- info: 'BitcoinProofs.AF.PDW4.checkTransaction_ok_cbLength' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW4.checkTransaction_ok_cbLength

end BitcoinProofs.AF.PDW4
