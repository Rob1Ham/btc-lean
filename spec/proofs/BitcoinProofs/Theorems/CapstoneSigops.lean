import BitcoinProofs.Theorems.CapstoneSequence

/-! R17: the actual ConnectBlock sigop budget, on evolving coin views.
These are kernel proofs; the difficulty-one serialized-block fixtures and
conditional stage tests live in core/Test/Capstone/SigopBudget.lean. -/

namespace BitcoinProofs.Theorems.CapstoneSigops

open Bitcoin.Data Bitcoin.Ledger Bitcoin.TxValidation Bitcoin.Serialization
open Bitcoin.Capstone.Block Bitcoin.Capstone.Context Bitcoin.Activation
open BitcoinProofs.Theorems.CapstonePipeline

/-- The exact charged-cost trace. Each transaction's cost uses its current
view, and the next view is its successful ledger transition. There is no
sum against one frozen pre-block view. -/
def SigopTrace (height : UInt32) (flags : ScriptFlags) :
    List Tx → List (OutPoint × Coin) → List (OutPoint × Coin) → Nat → Nat → Prop
  | [], l, out, start, total => out = l ∧ total = start
  | tx :: rest, l, out, start, total =>
    ∃ next, applyTxStepL l tx (txidKey tx) height = .ok next ∧
      SigopTrace height flags rest next out
        (start + Bitcoin.Block.Sigops.txSigOpCostWithFlags (viewOf l) tx flags) total

theorem SigopTrace_nondecreasing {height flags txs l out start total}
    (h : SigopTrace height flags txs l out start total) : start ≤ total := by
  induction txs generalizing l start with
  | nil => exact Nat.le_of_eq h.2.symm
  | cons tx rest ih =>
    obtain ⟨next, _, tail⟩ := h
    have ht := ih tail
    omega

/-- A successful fold started within budget ends within budget, including
the empty fold. Every nonempty step returns its already checked total. -/
theorem applyTxsWithSigops_bounded {context height flags txs i l a b fees start}
    {result : List (OutPoint × Coin) × Nat × Nat} {totalFees : Amount} {total : Nat}
    (initial : start ≤ Bitcoin.Block.Sigops.MAX_BLOCK_SIGOPS_COST)
    (h : applyTxsWithSigops context height flags txs i l a b fees start =
      .ok ((result, totalFees), total)) : total ≤ Bitcoin.Block.Sigops.MAX_BLOCK_SIGOPS_COST := by
  induction txs generalizing i l a b fees start with
  | nil =>
    simp only [applyTxsWithSigops, Except.ok.injEq, Prod.mk.injEq] at h
    exact h.2 ▸ initial
  | cons tx rest ih =>
    simp only [applyTxsWithSigops] at h
    cases hs : applyTxWithChecks height tx i l
        (fun fee => checkSigopTotal context height flags tx l fees fee start) flags with
    | error e => simp [hs] at h
    | ok value =>
      obtain ⟨⟨⟨next, x, y⟩, checkedFee⟩, nextTotal⟩ := value
      simp only [hs, ebind_ok] at h
      have checked := checkSigopTotal_ok (applyTxWithChecks_checks_ok hs)
      exact ih checked.2.2 h

/-- The successful executable fold produces this exact ledger/cost trace. -/
theorem applyTxsWithSigops_trace {context height flags txs i l a b fees start}
    {out : List (OutPoint × Coin)} {x y : Nat} {totalFees : Amount} {total : Nat}
    (h : applyTxsWithSigops context height flags txs i l a b fees start =
      .ok (((out, x, y), totalFees), total)) :
    SigopTrace height flags txs l out start total := by
  induction txs generalizing i l a b fees start with
  | nil =>
    simp only [applyTxsWithSigops, Except.ok.injEq, Prod.mk.injEq] at h
    exact ⟨h.1.1.1.symm, h.2.symm⟩
  | cons tx rest ih =>
    simp only [applyTxsWithSigops] at h
    cases hs : applyTxWithChecks height tx i l
        (fun fee => checkSigopTotal context height flags tx l fees fee start) flags with
    | error e => simp [hs] at h
    | ok value =>
      obtain ⟨⟨⟨next, p, q⟩, checkedFee⟩, nextTotal⟩ := value
      simp only [hs, ebind_ok] at h
      have checked := checkSigopTotal_ok (applyTxWithChecks_checks_ok hs)
      have feeStep := CapstoneSequence.applyTxWithChecks_fee_projection
        (checkFee := fun _ => .ok ()) (Or.inr rfl) hs
      have ledger := (CapstoneFold.applyTx_ok_inv (applyTxWithFeeCheck_ok feeStep)).2.2
      refine ⟨next, ledger, ?_⟩
      have tail := ih h
      simpa only [checked.2.1] using tail

/-- The resource-checked stage exposes precisely its funded fold and the
coinbase reward check; no separately assumed cost result is used. -/
theorem applyBlockTransactionsWithSigops_fold {context height flags txs l}
    {result : List (OutPoint × Coin) × Nat × Nat} {total : Nat}
    (h : applyBlockTransactionsWithSigops context height flags txs l = .ok (result, total)) :
    ∃ fees, applyTxsWithSigops context height flags txs 0 l 0 0 0 0 =
      .ok ((result, fees), total) ∧ coinbaseRewardOk (txs.getD 0 dummyTx) fees height = true := by
  unfold applyBlockTransactionsWithSigops at h
  cases hf : applyTxsWithSigops context height flags txs 0 l 0 0 0 0 with
  | error e => simp [hf] at h
  | ok value =>
    obtain ⟨⟨r, fees⟩, actual⟩ := value
    simp only [hf, ebind_ok] at h
    split at h
    · simp at h
    · rename_i reward
      simp only [epure_ok, Except.ok.injEq, Prod.mk.injEq] at h
      obtain ⟨hr, ht⟩ := h
      subst r
      subst actual
      exact ⟨fees, rfl, by simpa using reward⟩

/-- Public dataflow pins both the reported total and its checked flag to
the new resource stage, for contextual validation and partial replay. -/
theorem validateBlock_sigop_stage {raw : ByteArray} {st : CapState}
    {context : Option (ChainContext)} {report : CapReport}
    (h : validateBlock raw st context = .ok report) :
    ∃ header txs resolved,
      decodeBlock raw = .ok (header, txs) ∧ checkBlockPrelude txs = .ok () ∧
      checkWitnessCommitment (Bitcoin.Activation.SEGWIT_HEIGHT ≤ st.height) txs
        (txs.getD 0 dummyTx) = .ok () ∧
      applyBlockTransactionsWithSigops resolved st.height (candidateScriptFlags st.height header)
        txs st.utxo = .ok ((report.state.utxo, report.scriptOk, report.scriptUnjudged), report.sigOpCost) ∧
      report.sigOpBudgetChecked = true ∧
      report.scriptAdjudication = (if report.scriptUnjudged = 0 then .complete else .incomplete) := by
  rw [validateBlock.eq_1] at h
  cases hd : decodeBlock raw with
  | error e => simp [hd] at h
  | ok pair =>
    obtain ⟨header, txs⟩ := pair
    simp only [hd, epure_ok, ebind_ok] at h
    obtain ⟨_, h⟩ := gate_step _ _ h -- nonempty
    obtain ⟨_, h⟩ := gate_step _ _ h -- coinbase position
    obtain ⟨_, h⟩ := gate_step _ _ h -- coinbase script length
    obtain ⟨_, h⟩ := gate_step _ _ h -- target
    obtain ⟨_, h⟩ := gate_step _ _ h -- proof of work
    obtain ⟨_, h⟩ := gate_step _ _ h -- parent link
    cases context with
    | none =>
      simp only [epure_ok, ebind_ok] at h
      obtain ⟨_, h⟩ := gate_step _ _ h -- version
      obtain ⟨_, h⟩ := gate_step _ _ h -- BIP34
      obtain ⟨_, h⟩ := gate_step _ _ h -- merkle
      obtain ⟨_, h⟩ := gate_step _ _ h -- mutation
      obtain ⟨prelude, h⟩ := unit_precheck_ok _ _ h
      obtain ⟨witness, h⟩ := unit_precheck_ok _ _ h -- ordered witness stage
      obtain ⟨_, h⟩ := gate_step _ _ h -- weight
      obtain ⟨_, h⟩ := gate_step _ _ h -- BIP30
      cases hs : applyBlockTransactionsWithSigops none st.height
          (candidateScriptFlags st.height header) txs st.utxo with
      | error e => simp [hs] at h
      | ok value =>
        obtain ⟨⟨out, a, b⟩, total⟩ := value
        simp only [hs, ebind_ok, epure_ok, Except.ok.injEq] at h
        subst report
        exact ⟨header, txs, none, rfl, prelude, witness, hs, rfl, rfl⟩
    | some ctx =>
      cases hc : checkHeaderContext ctx st.height st.prevHash header with
      | error e => simp [hc] at h
      | ok facts =>
        simp only [hc, epure_ok, ebind_ok] at h
        obtain ⟨_, h⟩ := gate_step _ _ h -- version
        obtain ⟨_, h⟩ := gate_step _ _ h -- absolute finality
        obtain ⟨_, h⟩ := gate_step _ _ h -- BIP34
        obtain ⟨_, h⟩ := gate_step _ _ h -- merkle
        obtain ⟨_, h⟩ := gate_step _ _ h -- mutation
        obtain ⟨prelude, h⟩ := unit_precheck_ok _ _ h
        obtain ⟨witness, h⟩ := unit_precheck_ok _ _ h -- ordered witness stage
        obtain ⟨_, h⟩ := gate_step _ _ h -- weight
        obtain ⟨_, h⟩ := gate_step _ _ h -- BIP30
        cases hs : applyBlockTransactionsWithSigops (some (ctx, facts)) st.height
            (candidateScriptFlags st.height header) txs st.utxo with
        | error e => simp [hs] at h
        | ok value =>
          obtain ⟨⟨out, a, b⟩, total⟩ := value
          simp only [hs, ebind_ok, epure_ok, Except.ok.injEq] at h
          subst report
          exact ⟨header, txs, some (ctx, facts), rfl, prelude, witness, hs, rfl, rfl⟩

/-- The public entry also enforces CheckBlock's early legacy-only budget
and checks every stateless transaction before reaching input validation. -/
@[rule "BLK-034", rule "INV-040"]
theorem validateBlock_legacy_budget {raw : ByteArray} {st : CapState}
    {context : Option ChainContext} {report : CapReport}
    (h : validateBlock raw st context = .ok report) :
    ∃ header txs, decodeBlock raw = .ok (header, txs) ∧
      Bitcoin.Block.Sigops.legacySigOpBudgetOk txs = true ∧
      ∀ tx ∈ txs, Bitcoin.Consensus.checkTransaction tx = none := by
  obtain ⟨header, txs, _, hd, prelude, _, _, _⟩ := validateBlock_sigop_stage h
  have checked := checkBlockPrelude_ok prelude
  exact ⟨header, txs, hd, checked.2, checkBlockStateless_ok checked.1⟩

/-- Actual public success implies the inclusive 80,000-unit bound and an
exact cost/ledger trace under flags selected from the actual candidate hash. -/
@[rule "BLK-036", rule "SWT-021", rule "INV-039"]
theorem validateBlock_sigop_budget {raw : ByteArray} {st : CapState}
    {context : Option ChainContext} {report : CapReport}
    (h : validateBlock raw st context = .ok report) :
    report.sigOpBudgetChecked = true ∧ report.sigOpCost ≤ 80000 ∧
    ∃ header txs, decodeBlock raw = .ok (header, txs) ∧
      SigopTrace st.height (candidateScriptFlags st.height header) txs st.utxo
        report.state.utxo 0 report.sigOpCost := by
  obtain ⟨header, txs, resolved, hd, _, _, stage, covered⟩ := validateBlock_sigop_stage h
  obtain ⟨fees, fold, _⟩ := applyBlockTransactionsWithSigops_fold stage
  exact ⟨covered.1, applyTxsWithSigops_bounded (by decide) fold,
    header, txs, hd, applyTxsWithSigops_trace fold⟩

/-- Every actual script check in the successful resource fold used the same
caller-supplied flags as its cost calculation, at the evolving input view. -/
theorem applyTxsWithSigops_script_flags {context height flags txs i l a b fees start}
    {out : List (OutPoint × Coin)} {x y total : Nat} {totalFees : Amount}
    (h : applyTxsWithSigops context height flags txs i l a b fees start =
      .ok (((out, x, y), totalFees), total)) :
    CapstoneFold.ScriptPass (flags := flags) height txs i l out (x-a) (y-b) := by
  have projected := applyTxsWithSigops_projection h
  have feeFold : applyTxsWithFees height txs i l a b fees flags =
      .ok ((out, x, y), totalFees) := by
    cases context with
    | none => exact projected
    | some pair =>
      obtain ⟨ctx, facts⟩ := pair
      exact CapstoneSequence.applyTxsInContext_fee_projection projected
  have run := applyTxsWithFees_ok feeFold
  have ledger := CapstoneFold.applyTxs_ledgerFold_agrees height txs i l a b out x y run
  have counts := CapstoneFold.applyTxs_counters_ge height txs i l a b out x y run
  exact CapstoneFold.scriptPass_of_agree height txs i l out a b x y ledger run counts.1 counts.2

/-- The full resource stage retains exact script flags and output counters. -/
theorem applyBlockTransactionsWithSigops_script_flags {context height flags txs l}
    {out : List (OutPoint × Coin)} {okN unjN total : Nat}
    (h : applyBlockTransactionsWithSigops context height flags txs l =
      .ok ((out, okN, unjN), total)) :
    CapstoneFold.ScriptPass (flags := flags) height txs 0 l out okN unjN := by
  obtain ⟨fees, fold, _⟩ := applyBlockTransactionsWithSigops_fold h
  simpa only [Nat.sub_zero] using applyTxsWithSigops_script_flags fold

/-- Both public entries use flags selected from the actual candidate hash
for every script in their successful transaction trace. Unjudged counts
remain explicit in the trace and report. -/
@[rule "SCR-015", rule "TXV-055", rule "TXV-056", rule "BLK-083", rule "BLK-084"]
theorem validateBlock_script_flags {raw : ByteArray} {st : CapState}
    {context : Option ChainContext} {report : CapReport}
    (h : validateBlock raw st context = .ok report) :
    ∃ header txs, decodeBlock raw = .ok (header, txs) ∧
      CapstoneFold.ScriptPass (flags := candidateScriptFlags st.height header)
        st.height txs 0 st.utxo report.state.utxo report.scriptOk report.scriptUnjudged := by
  obtain ⟨header, txs, resolved, hd, _, _, stage, _⟩ := validateBlock_sigop_stage h
  exact ⟨header, txs, hd, applyBlockTransactionsWithSigops_script_flags stage⟩

/-! Guard the exact footprints of the new public-stage proofs and their Core lemmas. -/

/-- info: 'Bitcoin.Capstone.Block.checkBlockStateless_error' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Block.checkBlockStateless_error

/-- info: 'Bitcoin.Capstone.Block.checkBlockPrelude_error' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Block.checkBlockPrelude_error

/-- info: 'Bitcoin.Capstone.Block.checkBlockStateless_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Block.checkBlockStateless_ok

/-- info: 'Bitcoin.Capstone.Block.checkBlockPrelude_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Block.checkBlockPrelude_ok

/-- info: 'Bitcoin.Capstone.Block.unit_precheck_ok' depends on axioms: [propext] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Block.unit_precheck_ok

/-- info: 'Bitcoin.Capstone.Block.applyTxWithChecks_checks_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Block.applyTxWithChecks_checks_ok

/-- info: 'Bitcoin.Capstone.Block.applyTxWithChecks_replace' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Block.applyTxWithChecks_replace

/-- info: 'Bitcoin.Capstone.Block.checkSigopTotal_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Block.checkSigopTotal_ok

/-- info: 'Bitcoin.Capstone.Block.applyTxsWithSigops_projection' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Block.applyTxsWithSigops_projection

/-- info: 'Bitcoin.Capstone.Block.applyBlockTransactionsWithSigops_projection' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Capstone.Block.applyBlockTransactionsWithSigops_projection

/-- info: 'BitcoinProofs.Theorems.CapstoneSigops.SigopTrace_nondecreasing' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneSigops.SigopTrace_nondecreasing

/-- info: 'BitcoinProofs.Theorems.CapstoneSigops.applyTxsWithSigops_bounded' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneSigops.applyTxsWithSigops_bounded

/-- info: 'BitcoinProofs.Theorems.CapstoneSigops.applyTxsWithSigops_trace' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneSigops.applyTxsWithSigops_trace

/-- info: 'BitcoinProofs.Theorems.CapstoneSigops.applyBlockTransactionsWithSigops_fold' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneSigops.applyBlockTransactionsWithSigops_fold

/-- info: 'BitcoinProofs.Theorems.CapstoneSigops.validateBlock_sigop_stage' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneSigops.validateBlock_sigop_stage

/-- info: 'BitcoinProofs.Theorems.CapstoneSigops.validateBlock_legacy_budget' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneSigops.validateBlock_legacy_budget

/-- info: 'BitcoinProofs.Theorems.CapstoneSigops.validateBlock_sigop_budget' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.Theorems.CapstoneSigops.validateBlock_sigop_budget

/-- info: 'Bitcoin.Block.Sigops.txSigOpCostWithFlags_decompose' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Block.Sigops.txSigOpCostWithFlags_decompose

end BitcoinProofs.Theorems.CapstoneSigops

-- R07a: actual candidate flags reach the full script trace.
/-- info: 'BitcoinProofs.Theorems.CapstoneSigops.applyTxsWithSigops_script_flags' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.Theorems.CapstoneSigops.applyTxsWithSigops_script_flags

/-- info: 'BitcoinProofs.Theorems.CapstoneSigops.applyBlockTransactionsWithSigops_script_flags' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.Theorems.CapstoneSigops.applyBlockTransactionsWithSigops_script_flags

/-- info: 'BitcoinProofs.Theorems.CapstoneSigops.validateBlock_script_flags' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.Theorems.CapstoneSigops.validateBlock_script_flags
