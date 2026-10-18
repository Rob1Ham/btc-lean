import BitcoinProofs.Theorems.CapstoneContext
import Bitcoin.Block.Connect

/-! R03: contextual finality and BIP68 on the actual input/fee/script fold.
These are symbolic kernel proofs. Runtime boundary and public-byte fixtures
are in core/Test/Capstone/Finality.lean. -/

namespace BitcoinProofs.Theorems.CapstoneSequence

open Bitcoin.Data Bitcoin.Ledger Bitcoin.TxValidation Bitcoin.Serialization
open Bitcoin.Capstone.Block Bitcoin.Capstone.Context
open BitcoinProofs.Theorems.CapstonePipeline

/-- The live BIP113/absolute-finality prelude is the existing block-rule
predicate with the actual activation height and parent-MTP cutoff. -/
theorem contextualFinality_eq (txs : List Tx) (height mtp time : UInt32) :
    blockFinalityAtHeight txs height mtp time =
      Bitcoin.Block.Connect.blockFinalityOk txs height
        (Bitcoin.Block.Connect.finalityCutoff (Bitcoin.Activation.CSV_HEIGHT ≤ height) mtp time) := by
  simp [blockFinalityAtHeight, finalityCutoffAtHeight, Bitcoin.Block.Connect.blockFinalityOk,
    Bitcoin.Block.Connect.finalityCutoff]

local macro "reduceExcept" : tactic =>
  `(tactic| simp_all [Bind.bind, Except.bind, Functor.map, Except.map, pure, Except.pure])

/-- Metadata in a successful engine result was produced by the actual
pre-script callback, using the fee returned by input validation. -/
theorem applyTxWithChecks_checked {α : Type} {height : UInt32} {tx : Tx} {i : Nat}
    {l : List (OutPoint × Coin)} {checks : Amount → Except CapError α}
    {result : List (OutPoint × Coin) × Nat × Nat} {fee : Amount} {checkedData : α}
    (h : applyTxWithChecks height tx i l checks = .ok ((result, fee), checkedData)) :
    checks fee = .ok checkedData := by
  unfold applyTxWithChecks at h
  cases hc : Bitcoin.Consensus.checkTransaction tx with
  | some e => simp [hc] at h
  | none =>
    cases hb : tx.isCoinBase with
    | true =>
      cases hf : checks 0 with
      | error e => simp [hc, hb, hf] at h
      | ok value =>
        cases hs : applyTxStepL l tx (txidKey tx) height <;> reduceExcept
    | false =>
      cases hm : checkTxInputs tx (viewOf l) height with
      | error e => simp [hc, hb, hm] at h
      | ok actualFee =>
        cases hf : checks actualFee with
        | error e => simp [hc, hb, hm, hf] at h
        | ok value =>
          cases hv : verifyTxInputs height tx i l with
          | error e => simp [hc, hb, hm, hf, hv] at h
          | ok counts =>
            obtain ⟨a, b⟩ := counts
            cases hs : applyTxStepL l tx (txidKey tx) height <;> reduceExcept

/-- Dropping an additional successful context check preserves the exact
UTXO, script counters and checked fee in the fee-only adapter. -/
theorem applyTxWithChecks_fee_projection {α : Type} {height : UInt32} {tx : Tx} {i : Nat}
    {l : List (OutPoint × Coin)} {checks : Amount → Except CapError α}
    {checkFee : Amount → Except CapError Unit}
    {result : List (OutPoint × Coin) × Nat × Nat} {fee : Amount} {checkedData : α}
    (budget : tx.isCoinBase = true ∨ checkFee fee = .ok ())
    (h : applyTxWithChecks height tx i l checks = .ok ((result, fee), checkedData)) :
    applyTxWithFeeCheck height tx i l checkFee = .ok (result, fee) := by
  rw [applyTxWithFeeCheck_unfold]
  unfold applyTxWithChecks at h
  cases hc : Bitcoin.Consensus.checkTransaction tx with
  | some e => simp [hc] at h
  | none =>
    cases hb : tx.isCoinBase with
    | true =>
      cases hf : checks 0 with
      | error e => simp [hc, hb, hf] at h
      | ok value =>
        cases hs : applyTxStepL l tx (txidKey tx) height <;> reduceExcept
    | false =>
      cases hm : checkTxInputs tx (viewOf l) height with
      | error e => simp [hc, hb, hm] at h
      | ok actualFee =>
        cases hf : checks actualFee with
        | error e => simp [hc, hb, hm, hf] at h
        | ok value =>
          cases hv : verifyTxInputs height tx i l with
          | error e => simp [hc, hb, hm, hf, hv] at h
          | ok counts =>
            obtain ⟨a, b⟩ := counts
            cases hs : applyTxStepL l tx (txidKey tx) height <;> reduceExcept

/-- Input checkedDatadata cannot silently truncate the vin/data zip. -/
theorem sequenceInputData_length {ctx : ChainContext} {mtp : UInt32} {u : UtxoSet}
    {vin : List TxIn} {data : List (Int × Int)}
    (h : sequenceInputData ctx mtp u vin = .ok data) : data.length = vin.length := by
  induction vin generalizing data with
  | nil => simp [sequenceInputData] at h; subst data; rfl
  | cons input rest ih =>
    simp only [sequenceInputData] at h
    cases hc : u input.prevout with
    | none => simp [hc] at h
    | some coin =>
      simp only [hc, ebind_ok] at h
      split at h
      · cases hm : medianTimePastStrict ctx (coin.height.toNat-1) with
        | error e => simp [hm] at h
        | ok time =>
          cases ht : sequenceInputData ctx mtp u rest with
          | error e => simp [hm, ht] at h
          | ok tail =>
            simp [hm, ht] at h
            subst data
            simpa using congrArg Nat.succ (ih ht)
      · cases ht : sequenceInputData ctx mtp u rest with
        | error e => simp [ht] at h
        | ok tail =>
          simp [ht] at h
          subst data
          simpa using congrArg Nat.succ (ih ht)

/-- Core's coinbase/version/deployment exemptions, or actual aligned
coin-parent data satisfying both BIP68 domains at block-parent MTP. -/
def SequenceCondition (ctx : ChainContext) (facts : HeaderFacts) (height : UInt32)
    (tx : Tx) (l : List (OutPoint × Coin)) : Prop :=
  tx.isCoinBase = true ∨
  Bitcoin.DataLaws.bip68Enabled tx.version (Bitcoin.Activation.CSV_HEIGHT ≤ height) = false ∨
  ∃ data, sequenceInputData ctx facts.parentMtp (viewOf l) tx.vin = .ok data ∧
    data.length = tx.vin.length ∧
    sequenceLocksOk tx (Bitcoin.Activation.CSV_HEIGHT ≤ height) data
      (height.toNat : Int) (facts.parentMtp.toNat : Int) = true

theorem checkSequenceContext_ok {ctx : ChainContext} {facts : HeaderFacts}
    {height : UInt32} {tx : Tx} {l : List (OutPoint × Coin)}
    (h : checkSequenceContext ctx facts height tx l = .ok ()) :
    SequenceCondition ctx facts height tx l := by
  unfold checkSequenceContext at h
  dsimp only at h
  split at h
  · rename_i exempt
    unfold SequenceCondition
    simp only [Bool.or_eq_true, Bool.not_eq_true'] at exempt
    rcases exempt with hcb | disabled
    · exact Or.inl hcb
    · exact Or.inr (Or.inl disabled)
  · cases hd : sequenceInputData ctx facts.parentMtp (viewOf l) tx.vin with
    | error e => simp [hd] at h
    | ok data =>
      simp only [hd, epure_ok, ebind_ok] at h
      split at h
      · simp at h
      · rename_i passed
        exact Or.inr (Or.inr ⟨data, hd, sequenceInputData_length hd, by simpa using passed⟩)

theorem checkContextualTx_ok {ctx : ChainContext} {facts : HeaderFacts}
    {height : UInt32} {tx : Tx} {l : List (OutPoint × Coin)} {fees fee : Amount}
    (h : checkContextualTx ctx facts height tx l fees fee = .ok ()) :
    (tx.isCoinBase = true ∨ checkFeeTotal fees fee = .ok ()) ∧
      SequenceCondition ctx facts height tx l := by
  unfold checkContextualTx at h
  split at h
  · rename_i cb
    exact ⟨Or.inl cb, Or.inl cb⟩
  · cases hf : checkFeeTotal fees fee with
    | error e => simp [hf] at h
    | ok unit =>
      cases unit
      simp only [hf, ebind_ok] at h
      exact ⟨Or.inr rfl, checkSequenceContext_ok h⟩

theorem applyTxsInContext_fee_projection {ctx : ChainContext} {facts : HeaderFacts}
    {height : UInt32} {txs : List Tx} {i : Nat} {l : List (OutPoint × Coin)}
    {a b : Nat} {fees total : Amount} {result : List (OutPoint × Coin) × Nat × Nat}
    (h : applyTxsInContext ctx facts height txs i l a b fees = .ok (result, total)) :
    applyTxsWithFees height txs i l a b fees = .ok (result, total) := by
  induction txs generalizing i l a b fees with
  | nil => simpa [applyTxsInContext, applyTxsWithFees] using h
  | cons tx rest ih =>
    simp only [applyTxsInContext] at h
    cases hs : applyTxWithChecks height tx i l (checkContextualTx ctx facts height tx l fees) with
    | error e => simp [hs] at h
    | ok p =>
      obtain ⟨⟨⟨l', x, y⟩, fee⟩, unit⟩ := p
      cases unit
      simp only [hs, ebind_ok] at h
      have budget := (checkContextualTx_ok (applyTxWithChecks_checked hs)).1
      have projected := applyTxWithChecks_fee_projection budget hs
      simpa [applyTxsWithFees, projected] using ih h

/-- Every ledger transition in the accepted fold carries checked input fees
and a semantic BIP68 condition at its actual intermediate view. -/
def SequenceTrace (ctx : ChainContext) (facts : HeaderFacts) (height : UInt32) :
    List Tx → List (OutPoint × Coin) → Amount → List (OutPoint × Coin) → Amount → Prop
  | [], l, fees, last, total => l = last ∧ fees = total
  | tx :: rest, l, fees, last, total =>
    ∃ next fee,
      applyTxStepL l tx (txidKey tx) height = .ok next ∧
      SequenceCondition ctx facts height tx l ∧
      ((tx.isCoinBase = true ∧ fee = 0) ∨
        (tx.isCoinBase = false ∧ checkTxInputs tx (viewOf l) height = .ok fee)) ∧
      SequenceTrace ctx facts height rest next (fees+fee) last total

theorem applyTxsInContext_trace {ctx : ChainContext} {facts : HeaderFacts}
    {height : UInt32} {txs : List Tx} {i : Nat} {l last : List (OutPoint × Coin)}
    {a b okN unjN : Nat} {fees total : Amount}
    (h : applyTxsInContext ctx facts height txs i l a b fees = .ok ((last, okN, unjN), total)) :
    SequenceTrace ctx facts height txs l fees last total := by
  induction txs generalizing i l a b fees with
  | nil =>
    simp only [applyTxsInContext, Except.ok.injEq, Prod.mk.injEq] at h
    exact ⟨h.1.1, h.2⟩
  | cons tx rest ih =>
    simp only [applyTxsInContext] at h
    cases hs : applyTxWithChecks height tx i l (checkContextualTx ctx facts height tx l fees) with
    | error e => simp [hs] at h
    | ok p =>
      obtain ⟨⟨⟨next, x, y⟩, fee⟩, unit⟩ := p
      cases unit
      simp only [hs, ebind_ok] at h
      have checked := checkContextualTx_ok (applyTxWithChecks_checked hs)
      have projected := applyTxWithChecks_fee_projection checked.1 hs
      have base := applyTxWithFeeCheck_ok projected
      have ledger := (BitcoinProofs.Theorems.CapstoneFold.applyTx_ok_inv base).2.2
      have feeEvidence := BitcoinProofs.Theorems.CapstoneFunding.applyTxWithFeeCheck_fee projected
      refine ⟨next, fee, ledger, checked.2, ?_, ih h⟩
      rcases feeEvidence with cb | ⟨noncb, inputs, _⟩
      · exact Or.inl cb
      · exact Or.inr ⟨noncb, inputs⟩

theorem applyContextualBlockTransactions_funding {ctx : ChainContext} {facts : HeaderFacts}
    {height : UInt32} {txs : List Tx} {l : List (OutPoint × Coin)}
    {result : List (OutPoint × Coin) × Nat × Nat}
    (h : applyContextualBlockTransactions ctx facts height txs l = .ok result) :
    ∃ fees, applyTxsInContext ctx facts height txs 0 l 0 0 0 = .ok (result, fees) ∧
      MoneyRange fees = true ∧
      (txs.getD 0 dummyTx).getValueOut ≤ fees + Bitcoin.Conservation.blockSubsidy height := by
  unfold applyContextualBlockTransactions at h
  cases hf : applyTxsInContext ctx facts height txs 0 l 0 0 0 with
  | error e => simp [hf] at h
  | ok p =>
    obtain ⟨r, fees⟩ := p
    simp only [hf, ebind_ok] at h
    split at h
    · simp at h
    · rename_i budget
      simp only [epure_ok, Except.ok.injEq] at h
      subst r
      refine ⟨fees, rfl, ?_, by simpa [coinbaseRewardOk] using budget⟩
      exact BitcoinProofs.Theorems.CapstoneFunding.applyTxsWithFees_range (by decide)
        (applyTxsInContext_fee_projection hf)

/-- Public dataflow: header facts and absolute finality precede the actual
contextual transaction stage, whose output is exactly the reported state. -/
theorem validateBlockInContext_stages {raw : ByteArray} {st : CapState}
    {ctx : ChainContext} {report : CapReport}
    (h : validateBlockInContext raw st ctx = .ok report) :
    ∃ header txs facts,
      decodeBlock raw = .ok (header, txs) ∧
      checkHeaderContext ctx st.height st.prevHash header = .ok facts ∧
      blockFinalityAtHeight txs st.height facts.parentMtp header.time = true ∧
      applyContextualBlockTransactions ctx facts st.height txs st.utxo =
        .ok (report.state.utxo, report.scriptOk, report.scriptUnjudged) ∧
      report.absoluteFinalityChecked = true ∧ report.sequenceLocksChecked = true := by
  unfold validateBlockInContext at h
  rw [validateBlock.eq_1] at h
  cases hd : decodeBlock raw with
  | error e => simp [hd] at h
  | ok p =>
    obtain ⟨header, txs⟩ := p
    simp only [hd, epure_ok, ebind_ok] at h
    obtain ⟨_, h⟩ := gate_step _ _ h -- nonempty
    obtain ⟨_, h⟩ := gate_step _ _ h -- coinbase position
    obtain ⟨_, h⟩ := gate_step _ _ h -- coinbase length
    obtain ⟨_, h⟩ := gate_step _ _ h -- target
    obtain ⟨_, h⟩ := gate_step _ _ h -- PoW
    obtain ⟨_, h⟩ := gate_step _ _ h -- parent link
    cases hc : checkHeaderContext ctx st.height st.prevHash header with
    | error e => simp [hc] at h
    | ok facts =>
      simp only [hc, epure_ok, ebind_ok] at h
      obtain ⟨_, h⟩ := gate_step _ _ h -- version
      obtain ⟨finality, h⟩ := gate_step _ _ h
      obtain ⟨_, h⟩ := gate_step _ _ h -- BIP34
      obtain ⟨_, h⟩ := gate_step _ _ h -- merkle root
      obtain ⟨_, h⟩ := gate_step _ _ h -- mutation
      obtain ⟨_, h⟩ := unit_precheck_ok _ _ h
      obtain ⟨_, h⟩ := unit_precheck_ok _ _ h -- ordered witness stage
      obtain ⟨_, h⟩ := gate_step _ _ h -- weight
      obtain ⟨_, h⟩ := gate_step _ _ h -- BIP30
      cases ht : applyBlockTransactionsWithSigops (some (ctx, facts)) st.height
          (candidateScriptFlags st.height header) txs st.utxo with
      | error e => simp [ht] at h
      | ok result =>
        obtain ⟨⟨u, a, b⟩, sigops⟩ := result
        have stage : applyContextualBlockTransactions ctx facts st.height txs st.utxo = .ok (u, a, b) :=
          applyBlockTransactionsWithSigops_projection ht
        simp only [ht, ebind_ok, epure_ok, Except.ok.injEq] at h
        subst report
        exact ⟨header, txs, facts, rfl, hc, bool_not_false finality, stage, rfl, rfl⟩

/-- Actual public acceptance implies all absolute locks and every relative
lock in the evolving UTXO trace, plus the same checked-fee/subsidy bound. -/
@[rule "BLK-068", rule "BLK-104"]
theorem validateBlockInContext_locks {raw : ByteArray} {st : CapState}
    {ctx : ChainContext} {report : CapReport}
    (h : validateBlockInContext raw st ctx = .ok report) :
    ∃ header txs facts fees,
      decodeBlock raw = .ok (header, txs) ∧
      checkHeaderContext ctx st.height st.prevHash header = .ok facts ∧
      (∀ tx ∈ txs, Bitcoin.DataLaws.isFinalTx tx st.height
        (finalityCutoffAtHeight st.height facts.parentMtp header.time) = true) ∧
      SequenceTrace ctx facts st.height txs st.utxo 0 report.state.utxo fees ∧
      MoneyRange fees = true ∧
      (txs.getD 0 dummyTx).getValueOut ≤ fees + Bitcoin.Conservation.blockSubsidy st.height := by
  obtain ⟨header, txs, facts, hd, hc, finality, stage, _, _⟩ := validateBlockInContext_stages h
  obtain ⟨fees, fold, range, reward⟩ := applyContextualBlockTransactions_funding stage
  refine ⟨header, txs, facts, fees, hd, hc, ?_, applyTxsInContext_trace fold, range, reward⟩
  exact List.all_eq_true.mp finality

/-- info: 'BitcoinProofs.Theorems.CapstoneSequence.contextualFinality_eq' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms contextualFinality_eq
/-- info: 'BitcoinProofs.Theorems.CapstoneSequence.applyTxWithChecks_checked' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms applyTxWithChecks_checked
/-- info: 'BitcoinProofs.Theorems.CapstoneSequence.applyTxWithChecks_fee_projection' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms applyTxWithChecks_fee_projection
/-- info: 'BitcoinProofs.Theorems.CapstoneSequence.sequenceInputData_length' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms sequenceInputData_length
/-- info: 'BitcoinProofs.Theorems.CapstoneSequence.checkSequenceContext_ok' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms checkSequenceContext_ok
/-- info: 'BitcoinProofs.Theorems.CapstoneSequence.checkContextualTx_ok' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms checkContextualTx_ok
/-- info: 'BitcoinProofs.Theorems.CapstoneSequence.applyTxsInContext_fee_projection' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms applyTxsInContext_fee_projection
/-- info: 'BitcoinProofs.Theorems.CapstoneSequence.applyTxsInContext_trace' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms applyTxsInContext_trace
/-- info: 'BitcoinProofs.Theorems.CapstoneSequence.applyContextualBlockTransactions_funding' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms applyContextualBlockTransactions_funding
/-- info: 'BitcoinProofs.Theorems.CapstoneSequence.validateBlockInContext_stages' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms validateBlockInContext_stages
/-- info: 'BitcoinProofs.Theorems.CapstoneSequence.validateBlockInContext_locks' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms validateBlockInContext_locks

end BitcoinProofs.Theorems.CapstoneSequence
