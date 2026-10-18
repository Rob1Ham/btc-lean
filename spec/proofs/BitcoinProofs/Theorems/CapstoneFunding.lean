import BitcoinProofs.Theorems.CapstonePipelineCor

/-!
R02: the live transaction loop carries checked fees and bounds the coinbase.
These are symbolic kernel proofs; executable boundary fixtures live in
core/Test/Capstone/BlockFunding.lean.
-/

namespace BitcoinProofs.Theorems.CapstoneFunding

-- Script flags are threaded uniformly through every compared execution.
variable {flags : Bitcoin.Activation.ScriptFlags}

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Conservation Bitcoin.TxValidation
open Bitcoin.Capstone.Block Bitcoin.Serialization

local macro "reduceExcept" "at" h:ident : tactic =>
  `(tactic| simp_all [Bind.bind, Except.bind, Functor.map, Except.map, pure, Except.pure])

/-- The returned fee is zero for a coinbase, or the very fee checked
against this transaction's current view, accepted by the budget callback. -/
theorem applyTxWithFeeCheck_fee {height : UInt32} {tx : Tx} {i : Nat}
    {l : List (OutPoint × Coin)} {checkFee : Amount → Except CapError Unit}
    {result : List (OutPoint × Coin) × Nat × Nat} {fee : Amount}
    (h : applyTxWithFeeCheck height tx i l checkFee flags = .ok (result, fee)) :
    (tx.isCoinBase = true ∧ fee = 0) ∨
      (tx.isCoinBase = false ∧ checkTxInputs tx (viewOf l) height = .ok fee ∧
        checkFee fee = .ok ()) := by
  rw [applyTxWithFeeCheck_unfold] at h
  cases hc : Bitcoin.Consensus.checkTransaction tx with
  | some e => simp [hc] at h
  | none =>
    cases hb : tx.isCoinBase with
    | true =>
      cases hs : applyTxStepL l tx (txidKey tx) height <;> reduceExcept at h
    | false =>
      cases hm : checkTxInputs tx (viewOf l) height with
      | error e => simp [hc, hb, hm] at h
      | ok checkedFee =>
        cases hf : checkFee checkedFee with
        | error e => simp [hc, hb, hm, hf] at h
        | ok unit =>
          cases unit
          cases hv : verifyTxInputs height tx i l flags with
          | error e => simp [hc, hb, hm, hf, hv] at h
          | ok counts =>
            obtain ⟨a, b⟩ := counts
            cases hs : applyTxStepL l tx (txidKey tx) height <;> reduceExcept at h

/-- Every successfully returned cumulative fee is in MoneyRange, provided
the initial prefix was in range. This follows the actual sequential fold. -/
theorem applyTxsWithFees_range {height : UInt32} {txs : List Tx} {i : Nat}
    {l : List (OutPoint × Coin)} {a b : Nat} {fees total : Amount}
    {result : List (OutPoint × Coin) × Nat × Nat}
    (hinit : MoneyRange fees = true)
    (h : applyTxsWithFees height txs i l a b fees flags = .ok (result, total)) :
    MoneyRange total = true := by
  induction txs generalizing i l a b fees with
  | nil =>
    simp only [applyTxsWithFees, Except.ok.injEq, Prod.mk.injEq] at h
    simpa [← h.2] using hinit
  | cons tx rest ih =>
    simp only [applyTxsWithFees] at h
    cases hs : applyTxWithFeeCheck height tx i l (checkFeeTotal fees) flags with
    | error e => simp [hs] at h
    | ok p =>
      obtain ⟨⟨l', x, y⟩, fee⟩ := p
      simp only [hs, Bind.bind, Except.bind] at h
      apply ih (fees := fees + fee) (i := i+1) (l := l') (a := a+x) (b := b+y) ?_ h
      rcases applyTxWithFeeCheck_fee hs with ⟨_, rfl⟩ | ⟨_, _, hf⟩
      · simpa using hinit
      · cases hr : MoneyRange (fees + fee) with
        | false => simp [checkFeeTotal, hr] at hf
        | true => rfl

/-- The funded stage exposes its actual checked total and subsidy bound;
it also preserves exactly the reported UTXO and script counters. -/
theorem applyBlockTransactions_funding {height : UInt32} {txs : List Tx}
    {l : List (OutPoint × Coin)} {result : List (OutPoint × Coin) × Nat × Nat}
    (h : applyBlockTransactions height txs l flags = .ok result) :
    ∃ fees, applyTxsWithFees height txs 0 l 0 0 0 flags = .ok (result, fees) ∧
      MoneyRange fees = true ∧
      (txs.getD 0 dummyTx).getValueOut ≤ fees + blockSubsidy height := by
  unfold applyBlockTransactions at h
  cases hf : applyTxsWithFees height txs 0 l 0 0 0 flags with
  | error e => simp [hf] at h
  | ok p =>
    obtain ⟨r, fees⟩ := p
    simp only [hf, Bind.bind, Except.bind] at h
    split at h
    · simp at h
    · rename_i budget
      simp only [pure, Except.pure, Except.ok.injEq] at h
      subst r
      refine ⟨fees, rfl, applyTxsWithFees_range (by decide) hf, ?_⟩
      simpa [coinbaseRewardOk] using budget

/-- The actual serialized-block entry point only succeeds with a
MoneyRange checked fee total funding its coinbase. The fee-bearing fold
returns the exact UTXO and script counters in that public report. -/
theorem validateBlock_funding (raw : ByteArray) (st : CapState) (report : CapReport)
    (h : validateBlock raw st = .ok report) :
    ∃ header txs fees,
      decodeBlock raw = .ok (header, txs) ∧
      applyTxsWithFees st.height txs 0 st.utxo 0 0 0 (candidateScriptFlags st.height header) =
        .ok ((report.state.utxo, report.scriptOk, report.scriptUnjudged), fees) ∧
      MoneyRange fees = true ∧
      (txs.getD 0 dummyTx).getValueOut ≤ fees + blockSubsidy st.height := by
  obtain ⟨header, txs, u', a, b, hdec, _, _, _, _, _, _, _, _, hfund,
    hstate, _, ha, hb⟩ :=
    BitcoinProofs.Theorems.CapstonePipeline.validateBlock_ok_funded_shape raw st report h
  obtain ⟨fees, hfold, hrange, hbudget⟩ := applyBlockTransactions_funding hfund
  refine ⟨header, txs, fees, hdec, ?_, hrange, hbudget⟩
  simpa only [hstate, ha, hb] using hfold

/-- info: 'BitcoinProofs.Theorems.CapstoneFunding.applyTxWithFeeCheck_fee' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms applyTxWithFeeCheck_fee
/-- info: 'BitcoinProofs.Theorems.CapstoneFunding.applyTxsWithFees_range' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms applyTxsWithFees_range
/-- info: 'BitcoinProofs.Theorems.CapstoneFunding.applyBlockTransactions_funding' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms applyBlockTransactions_funding
/-- info: 'BitcoinProofs.Theorems.CapstoneFunding.validateBlock_funding' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms validateBlock_funding

end BitcoinProofs.Theorems.CapstoneFunding
