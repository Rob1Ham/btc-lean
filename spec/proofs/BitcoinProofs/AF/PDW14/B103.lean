import Bitcoin.TxValidation.Interface

/-! # B103 — PDW14, row BLK-103 (TOP-69).
`Bitcoin.TxValidation.checkTxInputs` (TxValidation/Interface.lean:232).
S-evidence: core `checkTxInputs_ok_conservation` (:895), sorry-free,
`#guard_msgs`-pinned [propext, Classical.choice, Quot.sound] (:1122)
= the THM-036 fee-contract over the exact gate (PD02 Table-1
BT:352 anchor via CapstoneConservationCor:232) = the promotion target
(PDW11 F-PD02-002 route). THIS module = the AF companion: the
bad-txns-in-belowout reject-lane (the row's own error face,
validation.cpp:170-220), on the PDW14 tag.

F-PDW14-001 (honest note): the :895 restatement is NOT portable —
its lambda-bearing statement re-elaborates `match u i.prevout` in
this file's own matcher constant, which is not definitional-equal to
the olean's (core's own bridge comment, Interface.lean:880-883) —
the S-evidence itself is the core theorem, flipped onto. -/

namespace BitcoinProofs.AF.PDW14

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Consensus Bitcoin.Numeric
open Bitcoin.TxValidation

@[rule "BLK-103"]
theorem checkTxInputs_in_belowout_reject (tx : Tx) (u : UtxoSet)
    (spendHeight : UInt32) (valueIn : Amount)
    (hi : haveInputs tx u = true)
    (hl : inputValuesLoop u spendHeight tx.vin 0 = .ok valueIn)
    (hb : valueIn < tx.getValueOut) :
    checkTxInputs tx u spendHeight = .error .badTxnsInBelowout := by
  simp only [checkTxInputs, if_pos hi, hl, if_pos hb]

end BitcoinProofs.AF.PDW14
