import Bitcoin.TxValidation.Interface

/-! # PDW100 — TXV-032: every tx in a block must be final (`bad-txns-nonfinal`)

Row face of `Bitcoin.TxValidation.validateTx` (validation.cpp:4153-4156):
stateless prefix → `IsFinalTx` → coinbase early-exit → BIP68 height gate →
`checkTxInputs`. A failed `IsFinalTx` and a failed BIP68 height gate both
collapse onto `.badTxnsNonfinal` (validation.cpp:2556). -/

namespace BitcoinProofs.AF.PDW100

open Bitcoin.Data Bitcoin.DataLaws Bitcoin.TxValidation

/-- TXV-032 reject face: after the stateless prefix, a non-final tx is
rejected as `bad-txns-nonfinal` (before coinbase early-exit). -/
@[rule "TXV-032"]
theorem validateTx_nonfinal (tx : Tx) (u : Bitcoin.Ledger.UtxoSet)
    (height mtp : UInt32) (flags : Bitcoin.Activation.ScriptFlags)
    (hc : Bitcoin.Consensus.checkTransaction tx = none)
    (hf : isFinalTx tx height mtp = false) :
    validateTx tx u height mtp flags = .error .badTxnsNonfinal := by
  unfold validateTx
  rw [hc]
  simp [hf]

/-- TXV-032 accept face: a successful verdict (coinbase included, since the
finality gate precedes the coinbase early-exit) implies finality. -/
@[rule "TXV-032"]
theorem validateTx_ok_final (tx : Tx) (u : Bitcoin.Ledger.UtxoSet)
    (height mtp : UInt32) (flags : Bitcoin.Activation.ScriptFlags)
    (fee : Amount)
    (h : validateTx tx u height mtp flags = .ok fee) :
    isFinalTx tx height mtp = true := by
  unfold validateTx at h
  by_cases hc : Bitcoin.Consensus.checkTransaction tx = none
  · rw [hc] at h
    by_cases hf : isFinalTx tx height mtp = true
    · exact hf
    · simp only [hf] at h
      exact absurd h (by simp)
  · rcases he : Bitcoin.Consensus.checkTransaction tx with _ | e
    · exact absurd hc (by rw [he]; simp)
    · rw [he] at h
      exact absurd h (by simp)

/-- TXV-032 collapse face: a final non-coinbase whose BIP68 height gate
fails also lands on `bad-txns-nonfinal` (validation.cpp:2556). -/
@[rule "TXV-032"]
theorem validateTx_bip68_nonfinal (tx : Tx) (u : Bitcoin.Ledger.UtxoSet)
    (height mtp : UInt32) (flags : Bitcoin.Activation.ScriptFlags)
    (hc : Bitcoin.Consensus.checkTransaction tx = none)
    (hf : isFinalTx tx height mtp = true)
    (hcb : tx.isCoinBase = false)
    (hb : bip68HeightOk tx u flags.csv (height.toNat : Int) = false) :
    validateTx tx u height mtp flags = .error .badTxnsNonfinal := by
  unfold validateTx
  rw [hc]
  simp [hf, hcb, hb]

/-- TXV-032 block face: if every tx of a block validates, every tx of the
block is final at `(height, mtp)` — the per-tx gate composes to the block
quantifier (`bad-txns-nonfinal`). -/
@[rule "TXV-032"]
theorem block_all_final (txs : List Tx) (u : Bitcoin.Ledger.UtxoSet)
    (height mtp : UInt32) (flags : Bitcoin.Activation.ScriptFlags)
    (h : ∀ t ∈ txs, (validateTx t u height mtp flags).isOk) :
    ∀ t ∈ txs, isFinalTx t height mtp = true := by
  intro t ht
  rcases hv : validateTx t u height mtp flags with _ | fee
  · have hok := h t ht
    rw [hv] at hok
    cases hok
  · exact validateTx_ok_final t u height mtp flags fee hv

/-- TXV-032 block loop (validation.cpp:4153-4156): `ContextualCheckBlock`
walks **every** transaction in the block and rejects it with
`bad-txns-nonfinal` as soon as one is non-final. This is the block-level
quantifier the per-tx `validateTx` faces above compose into; the finality
loop itself takes no UTXO/script input. -/
@[rule "TXV-032"]
def checkBlockFinal (txs : List Tx) (height mtp : UInt32) :
    Except TxError Unit :=
  if txs.all (fun t => isFinalTx t height mtp) then .ok () else .error .badTxnsNonfinal

/-- TXV-032: the block loop accepts exactly when every tx is final. -/
@[rule "TXV-032"]
theorem checkBlockFinal_ok_iff (txs : List Tx) (height mtp : UInt32) :
    checkBlockFinal txs height mtp = .ok () ↔
      ∀ t ∈ txs, isFinalTx t height mtp = true := by
  unfold checkBlockFinal
  by_cases h : txs.all (fun t => isFinalTx t height mtp) = true
  · rw [if_pos h]
    exact ⟨fun _ => List.all_eq_true.mp h, fun _ => rfl⟩
  · rw [if_neg h]
    refine ⟨fun hok => ?_, fun hall => ?_⟩
    · cases hok
    · exact absurd (List.all_eq_true.mpr hall) h

/-- TXV-032: a single non-final tx makes the block loop report exactly
`bad-txns-nonfinal` (the row's "else" branch). -/
@[rule "TXV-032"]
theorem checkBlockFinal_nonfinal (txs : List Tx) (t : Tx) (height mtp : UInt32)
    (ht : t ∈ txs) (hf : isFinalTx t height mtp = false) :
    checkBlockFinal txs height mtp = .error .badTxnsNonfinal := by
  unfold checkBlockFinal
  have hall : txs.all (fun u => isFinalTx u height mtp) = false := by
    cases hv : txs.all (fun u => isFinalTx u height mtp) with
    | false => rfl
    | true =>
      have hfin := List.all_eq_true.mp hv t ht
      rw [hfin] at hf
      cases hf
  rw [if_neg (by rw [hall]; simp)]

/-- TXV-032: if every tx validates, the block finality loop accepts. -/
@[rule "TXV-032"]
theorem checkBlockFinal_of_all_validate (txs : List Tx)
    (u : Bitcoin.Ledger.UtxoSet) (height mtp : UInt32)
    (flags : Bitcoin.Activation.ScriptFlags)
    (h : ∀ t ∈ txs, (validateTx t u height mtp flags).isOk) :
    checkBlockFinal txs height mtp = .ok () :=
  (checkBlockFinal_ok_iff txs height mtp).mpr
    (block_all_final txs u height mtp flags h)

end BitcoinProofs.AF.PDW100

/-! ## Axiom pins (subset [propext, Classical.choice, Quot.sound]) -/
#print axioms BitcoinProofs.AF.PDW100.validateTx_nonfinal
#print axioms BitcoinProofs.AF.PDW100.validateTx_ok_final
#print axioms BitcoinProofs.AF.PDW100.validateTx_bip68_nonfinal
#print axioms BitcoinProofs.AF.PDW100.block_all_final
#print axioms BitcoinProofs.AF.PDW100.checkBlockFinal_ok_iff
#print axioms BitcoinProofs.AF.PDW100.checkBlockFinal_nonfinal
#print axioms BitcoinProofs.AF.PDW100.checkBlockFinal_of_all_validate
