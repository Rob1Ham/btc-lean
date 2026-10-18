import Bitcoin.TxValidation.Interface
import Bitcoin.Interpreter.Interface
import Bitcoin.Capstone.RealChecker

/-!
# Bitcoin.TxValidation.Full — the transaction-validation module: the full tx-pipeline verdict (script lane)

Composes the contextual tier (`TxValidation.Interface`: stateless prefix +
HaveInputs + `checkTxInputs`, 131/131 on the tx corpus) with the live script
lanes (`verifyScriptFull` interpreter, sighash, real ECDSA,
the Schnorr module real BIP340 behind seam) into ONE per-transaction verdict — Core's
`CheckInputScripts` / `CScriptCheck::operator()` slice of `ConnectBlock` +
`MemPoolAccept` (validation.cpp:2060-2134, 2013-2026).

## What the pipeline adjudicates (and what it defers)

* stateless prefix (TXV-001..009) → `some false` on reject;
* coinbase early-exit (TXV-059/072): coinbases never script-verify;
* per-input prevout resolution (TXV-020) and, when every resolved prevout
  carries an amount, the fee slice (TXV-023/024/025);
* per-input `VerifyScript(scriptSig, prevout.scriptPubKey, witness, flags)`
  (TXV-058) under the caller's flag word (TXV-061: consensus flags; the
  policy word rides along for the corpus's policy-gated rows);
* `unjudged` outcomes (taproot script-path spending — `CheckTapTweak` EC is
  outside the seam) propagate as `none` = "cannot adjudicate" — honest
  queueing, never a guessed verdict.

Finality (TXV-027..032) and the time-domain half of BIP68 are deliberately
NOT in this lane: the tx corpus carries no block context, so they are the
block/mempool-context layer's verdicts (`Mempool.lean` in this directory,
`validateTx` caller). This mirrors Core, where `CheckInputScripts`
runs after the context checks its CALLER performed.

## The checker

`txCheckerFor` is `Bitcoin.Capstone.RealChecker`'s real wiring, re-assembled
per input with an `Option Amount`: `none` models the checker's missing-data
state (`amount < 0`, `HandleMissingData` fail-closed, SWT-055) — exactly the
corpus's `-1` "amount omitted" sentinel. The Schnorr sighash remains the
fail-closed the Taproot and interpreter delta layers stand-in (a one-parameter flip at `RealChecker.lean`,
the single wiring point).
-/

namespace Bitcoin.TxValidation.Full

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Consensus Bitcoin.Activation
open Bitcoin.Numeric Bitcoin.Interpreter
open Bitcoin.Capstone.RealChecker (sighashDispatch dummyTxIn)
open Bitcoin.Crypto.Seam.Entry (txCheckerOf)

/-! ## The resolved-prevout script table -/

/-- One resolved prevout for the script lane: the prevout's scriptPubKey
plus the spent amount. `amount = none` is the corpus's `-1` sentinel =
the signature checker's missing-data state (SWT-055 fail-closed). -/
abbrev ScriptEntry := ByteArray × Option Amount

/-- TXV-020 at the table level: every input's prevout resolves. -/
@[rule "TXV-020"]
def tableSupplied (tx : Tx) (tbl : OutPoint → Option ScriptEntry) : Bool :=
  tx.vin.all (fun i => (tbl i.prevout).isSome)

/-- Every resolved prevout carries an amount (no `-1` sentinel inputs). -/
def tableAmountsKnown (tx : Tx) (tbl : OutPoint → Option ScriptEntry) : Bool :=
  tx.vin.all (fun i =>
    match tbl i.prevout with
    | some (_, some _) => true
    | _ => false)

/-! ## The per-input real checker (TXV-058/061) -/

/-- The real signature checker for input `nIn` of `tx` spending `amount`:
real lax-ECDSA entry (`verifyImpl` over sighash dispatch;
`hasAmount = amount.isSome`, so `none` fails closed on WITNESS_V0 sighashes
exactly as Core's `HandleMissingData`), real BIP340 verifier in the Schnorr
entry (BIP342 sighash still the fail-closed Taproot/interpreter-delta stand-in), and the real
locktime environment (`LocktimeEnv` IC-2: tx version / nLockTime / this
input's nSequence — the CLTV/CSV opcode lanes, TXV-043..048). -/
@[rule "TXV-058", rule "TXV-061"]
def txCheckerFor (tx : Tx) (nIn : Nat) (amount : Option Amount) : ScriptChecker :=
  { base := txCheckerOf Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
        (sighashDispatch tx nIn (amount.getD 0)) amount.isSome
        Bitcoin.Crypto.Schnorr.Verify.verifyImpl (fun _ _ _ => none)
    env := { txVersion := tx.version
             txLockTime := tx.locktime
             txSequence := (tx.vin.getD nIn dummyTxIn).sequence } }

/-- Verification fuel: every executed opcode consumes ≥ 1 wire byte of the
script it lives in, so the total byte mass of scriptSig + scriptPubKey +
every witness item (plus the 25-byte implied P2WPKH program and slack)
bounds the opcode count of every `EvalScript` this pipeline runs. Surplus
fuel is verdict-inert (`evalFrom_succ_ok` / `evalScript_fuel_monotone`). -/
def pipelineFuel (ss spk : ByteArray) (w : WitnessStack) : Nat :=
  ss.size + spk.size + w.foldl (fun a d => a + d.size) 0 + 28

/-! ## The script lane (TXV-058) -/

/-- Per-input script verification, indexed fold over the input list (Core
runs `CheckInputScripts` per input; the running index `n` threads the
sighash input index and the witness stack). `some true` = every input
verified; `some false` = some input's script failed; `none` = some input's
outcome is `unjudged` (taproot script-path EC outside the seam) —
propagate, don't guess. -/
@[rule "TXV-058"]
def scriptLane (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (flags : ScriptFlags) (pol : PolicyFlags) :
    List TxIn → Nat → Option Bool
  | [], _ => some true
  | i :: rest, n =>
    match tbl i.prevout with
    | none => some false
    | some (spk, amt) =>
      let w := tx.witness.getD n []
      match verifyScriptFull (pipelineFuel i.scriptSig.bytes spk w) flags pol
          i.scriptSig.bytes spk w (txCheckerFor tx n amt) with
      | .ok => scriptLane tx tbl flags pol rest (n + 1)
      | .fail _ => some false
      | .unjudged => none

/-- The lane's verdict for a whole tx (indexed from 0). -/
def scriptLaneTx (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (flags : ScriptFlags) (pol : PolicyFlags) : Option Bool :=
  scriptLane tx tbl flags pol tx.vin 0

/-! ## The fee slice (TXV-023/024/025 at tx level) -/

/-- `checkTxInputs` as a Boolean verdict (`ok` ⇒ true, error ⇒ false). -/
def feeOk (tx : Tx) (u : UtxoSet) (spendHeight : UInt32) : Bool :=
  match checkTxInputs tx u spendHeight with
  | .ok _ => true
  | .error _ => false

/-! ## The full pipeline -/

/-- The full tx-pipeline verdict (the transaction-validation module): the transaction-validation layer's contextual tier + the script
lane. Check order mirrors Core's `PreChecks` → `CheckInputScripts`:
stateless prefix → coinbase early-exit (TXV-059/072) → prevout resolution
(TXV-020) → fee slice when adjudicable (TXV-023/024/025) → per-input
scripts (TXV-058). `none` = unjudged residue (honest queueing). -/
@[rule "TXV-058", rule "TXV-059", rule "TXV-060", rule "TXV-061", rule "TXV-072"]
def txVerdictFull (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (u : UtxoSet) (spendHeight : UInt32)
    (flags : ScriptFlags) (pol : PolicyFlags) : Option Bool :=
  match checkTransaction tx with
  | some _ => some false
  | none =>
    if tx.isCoinBase then some true
    else if tableSupplied tx tbl then
      if tableAmountsKnown tx tbl then
        if feeOk tx u spendHeight then scriptLaneTx tx tbl flags pol
        else some false
      else scriptLaneTx tx tbl flags pol
    else some false

/-! ## Pipeline laws (all sorry-free; axiom pins at the file end) -/

/-- Totality: the pipeline always returns a verdict-or-queue. -/
theorem txVerdictFull_total (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (u : UtxoSet) (spendHeight : UInt32) (flags : ScriptFlags) (pol : PolicyFlags) :
    ∃ r, txVerdictFull tx tbl u spendHeight flags pol = r := ⟨_, rfl⟩

/-- The stateless prefix gates the pipeline exactly as in `validateTx`
(TXV-001..009 route through `checkTransaction`). -/
theorem txVerdictFull_stateless_reject (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (u : UtxoSet) (spendHeight : UInt32) (flags : ScriptFlags) (pol : PolicyFlags)
    (e : TxCheckError) (h : checkTransaction tx = some e) :
    txVerdictFull tx tbl u spendHeight flags pol = some false := by
  unfold txVerdictFull
  simp only [h]

/-- TXV-059/072: a (statelessly valid) coinbase is accepted WITHOUT any
script or input work — coinbases never script-verify. -/
theorem txVerdictFull_coinbase_skip (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (u : UtxoSet) (spendHeight : UInt32) (flags : ScriptFlags) (pol : PolicyFlags)
    (h : checkTransaction tx = none) (hcb : tx.isCoinBase = true) :
    txVerdictFull tx tbl u spendHeight flags pol = some true := by
  unfold txVerdictFull
  simp only [h, if_pos hcb]

/-- TXV-020: an unresolved prevout rejects the tx before the fee slice or
the script lane runs. -/
theorem txVerdictFull_prevout_reject (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (u : UtxoSet) (spendHeight : UInt32) (flags : ScriptFlags) (pol : PolicyFlags)
    (hst : checkTransaction tx = none) (hcb : tx.isCoinBase = false)
    (hsup : tableSupplied tx tbl = false) :
    txVerdictFull tx tbl u spendHeight flags pol = some false := by
  unfold txVerdictFull
  simp [hst, hcb, hsup]

/-- TXV-023/024/025: a fee-slice failure rejects the tx before the script
lane runs. -/
theorem txVerdictFull_fee_reject (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (u : UtxoSet) (spendHeight : UInt32) (flags : ScriptFlags) (pol : PolicyFlags)
    (hst : checkTransaction tx = none) (hcb : tx.isCoinBase = false)
    (hsup : tableSupplied tx tbl = true)
    (hamt : tableAmountsKnown tx tbl = true)
    (hfee : feeOk tx u spendHeight = false) :
    txVerdictFull tx tbl u spendHeight flags pol = some false := by
  unfold txVerdictFull
  simp [hst, hcb, hsup, hamt, hfee]

/-- Script-lane fail-closedness at tx level (TXV-058): when the pipeline
reaches the lane and the lane's verdict is `some false`, the tx is
rejected — a script failure is never upgraded to an accept. -/
theorem txVerdictFull_script_fail (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (u : UtxoSet) (spendHeight : UInt32) (flags : ScriptFlags) (pol : PolicyFlags)
    (hst : checkTransaction tx = none) (hcb : tx.isCoinBase = false)
    (hsup : tableSupplied tx tbl = true)
    (hlane : scriptLaneTx tx tbl flags pol = some false) :
    txVerdictFull tx tbl u spendHeight flags pol = some false := by
  unfold txVerdictFull
  simp only [hst, if_neg (by simp [hcb] : ¬ (tx.isCoinBase = true)),
    if_pos hsup]
  split
  · split
    · exact hlane
    · rfl
  · exact hlane

/-! ## TXV-060: the script-failure → tx-reject kind map
(validation.cpp:2126-2131)

`CheckInputScripts` turns a script-check failure into one of two tx-level
rejections: `TX_NOT_STANDARD` (`mempool-script-verify-flag-failed`) when
the caller's flag word carries any `STANDARD_NOT_MANDATORY_VERIFY_FLAGS`
bit — the mempool policy tier — and `TX_CONSENSUS`
(`block-script-verify-flag-failed`) otherwise. The split is on the WHOLE
flag word, not on the individual failing check. -/

/-- The two rejection kinds the script slice can raise. -/
@[rule "TXV-060"]
inductive ScriptRejectKind where
  | consensus     -- TX_CONSENSUS (block-script-verify-flag-failed)
  | notStandard   -- TX_NOT_STANDARD (mempool-script-verify-flag-failed)
deriving Repr, DecidableEq, BEq

/-- `flags & STANDARD_NOT_MANDATORY_VERIFY_FLAGS != 0` (validation.cpp:
2118 @cce32b168), projected onto this model's flag split. The consensus
word is `ScriptFlags`; the remaining Core bits live in the policy word.
`STANDARD_NOT_MANDATORY_VERIFY_FLAGS = STANDARD_SCRIPT_VERIFY_FLAGS &
~MANDATORY_SCRIPT_VERIFY_FLAGS` (policy.h:106-134) is exactly the 13
policy bits below — note that `SCRIPT_VERIFY_SIGPUSHONLY` is NOT one of
them (it never enters `STANDARD_SCRIPT_VERIFY_FLAGS`), so `pol != default`
is not the right test: a policy word carrying only SIGPUSHONLY is
non-default yet leaves Core's mask zero. `default` (all policy bits
clear) is the block/consensus word (`getBlockScriptFlags` paired with
`flagsComboOk_consensus_pol`'s policy `default`). -/
@[rule "TXV-060"]
def hasStandardNotMandatory (pol : PolicyFlags) : Bool :=
  pol.minimalData ||            -- SCRIPT_VERIFY_MINIMALDATA
  pol.minimalIf ||              -- SCRIPT_VERIFY_MINIMALIF
  pol.nullFail ||               -- SCRIPT_VERIFY_NULLFAIL
  pol.strictEnc ||              -- SCRIPT_VERIFY_STRICTENC
  pol.constScriptCode ||        -- SCRIPT_VERIFY_CONST_SCRIPTCODE
  pol.cleanstack ||             -- SCRIPT_VERIFY_CLEANSTACK
  pol.lowS ||                   -- SCRIPT_VERIFY_LOW_S
  pol.witnessPubkeyType ||      -- SCRIPT_VERIFY_WITNESS_PUBKEYTYPE
  pol.discourageUpgradableNops ||            -- DISCOURAGE_UPGRADABLE_NOPS
  pol.discourageUpgradableWitnessProgram ||  -- DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM
  pol.discourageUpgradablePubkeyType ||      -- DISCOURAGE_UPGRADABLE_PUBKEYTYPE
  pol.discourageOpSuccess ||                 -- DISCOURAGE_OP_SUCCESS
  pol.discourageUpgradableTaprootVersion     -- DISCOURAGE_UPGRADABLE_TAPROOT_VERSION

/-- The consensus/block word has no standard-not-mandatory bit. -/
@[rule "TXV-060"]
theorem hasStandardNotMandatory_default :
    hasStandardNotMandatory (default : PolicyFlags) = false := rfl

/-- The discriminating case the coarse `pol != default` test got wrong:
`{sigPushOnly := true}` is a non-default policy word, but Core's mask is
zero because SIGPUSHONLY is not in `STANDARD_NOT_MANDATORY_VERIFY_FLAGS`
(policy.h:134). -/
@[rule "TXV-060"]
theorem hasStandardNotMandatory_sigPushOnly :
    hasStandardNotMandatory ({ sigPushOnly := true } : PolicyFlags) = false := rfl

/-- The non-default policy word used above really is non-default: the
correction is a genuine distinction, not a vacuous one. -/
@[rule "TXV-060"]
theorem sigPushOnly_ne_default :
    ({ sigPushOnly := true } : PolicyFlags) ≠ default := by decide

/-- The script-result → tx-result kind function (validation.cpp:2126-2131). -/
@[rule "TXV-060"]
def scriptFailKind (pol : PolicyFlags) : ScriptRejectKind :=
  if hasStandardNotMandatory pol then .notStandard else .consensus

/-- Consensus (mandatory-only) flags ⇒ `TX_CONSENSUS`. -/
@[rule "TXV-060"]
theorem scriptFailKind_consensus (pol : PolicyFlags)
    (h : hasStandardNotMandatory pol = false) :
    scriptFailKind pol = .consensus := by
  unfold scriptFailKind
  rw [if_neg (by simpa using h)]

/-- Extra (standard-not-mandatory / policy) flags ⇒ `TX_NOT_STANDARD`. -/
@[rule "TXV-060"]
theorem scriptFailKind_not_standard (pol : PolicyFlags)
    (h : hasStandardNotMandatory pol = true) :
    scriptFailKind pol = .notStandard := by
  unfold scriptFailKind
  rw [if_pos h]

/-- `SCRIPT_VERIFY_SIGPUSHONLY` alone stays on the consensus arm: Core's
mask is zero even though the policy word is non-default, so the reject
kind is `TX_CONSENSUS`, not `TX_NOT_STANDARD`. -/
@[rule "TXV-060"]
theorem scriptFailKind_sigPushOnly :
    scriptFailKind ({ sigPushOnly := true } : PolicyFlags) = .consensus := rfl

/-- TXV-060 (the full script-result → tx-result map): a script-lane
failure is a tx rejection, and the reject kind is `TX_CONSENSUS` under the
consensus word and `TX_NOT_STANDARD` under a word carrying extra policy
bits. -/
@[rule "TXV-060"]
theorem txVerdictFull_script_fail_kind (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (u : UtxoSet) (spendHeight : UInt32) (flags : ScriptFlags) (pol : PolicyFlags)
    (hst : checkTransaction tx = none) (hcb : tx.isCoinBase = false)
    (hsup : tableSupplied tx tbl = true)
    (hlane : scriptLaneTx tx tbl flags pol = some false) :
    txVerdictFull tx tbl u spendHeight flags pol = some false ∧
      (hasStandardNotMandatory pol = false → scriptFailKind pol = .consensus) ∧
      (hasStandardNotMandatory pol = true → scriptFailKind pol = .notStandard) :=
  ⟨txVerdictFull_script_fail tx tbl u spendHeight flags pol hst hcb hsup hlane,
   scriptFailKind_consensus pol, scriptFailKind_not_standard pol⟩

/-! ## TXV-061: the mempool current-block-flag script re-run
(validation.cpp:1175-1181)

`CheckInputsFromMempoolAndCache` re-executes every input's script under
`GetBlockScriptFlags(active tip)`. This is a SECOND, independent gate: a
tx that passed the standard/policy pass but fails against the current
block flags is a fatal `Assume(false)` (the logged "failed against
latest-block but not STANDARD flags" bug message), so the re-run's verdict
is authoritative for the mempool entry. -/

/-- The mempool's consensus-flag script re-run. -/
@[rule "TXV-061"]
def scriptRecheckAtTip (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (tipHeight : UInt32) (pol : PolicyFlags) : Option Bool :=
  scriptLaneTx tx tbl (getBlockScriptFlags tipHeight) pol

/-- The re-run's verdict is the script lane evaluated with the CURRENT
BLOCK flags, not the standard/policy word of the admission pass. -/
@[rule "TXV-061"]
theorem scriptRecheckAtTip_eq (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (tipHeight : UInt32) (pol : PolicyFlags) :
    scriptRecheckAtTip tx tbl tipHeight pol
      = scriptLaneTx tx tbl (getBlockScriptFlags tipHeight) pol := rfl

/-- TXV-061 (the re-run rejects independently): a re-check failure is a
tx rejection under the current-block flags — the standard-flag admission
pass cannot override it. -/
@[rule "TXV-061"]
theorem scriptRecheckAtTip_reject (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (u : UtxoSet) (spendHeight : UInt32) (tipHeight : UInt32) (pol : PolicyFlags)
    (hst : checkTransaction tx = none) (hcb : tx.isCoinBase = false)
    (hsup : tableSupplied tx tbl = true)
    (h : scriptRecheckAtTip tx tbl tipHeight pol = some false) :
    txVerdictFull tx tbl u spendHeight (getBlockScriptFlags tipHeight) pol = some false :=
  txVerdictFull_script_fail tx tbl u spendHeight (getBlockScriptFlags tipHeight) pol
    hst hcb hsup h

/-! ### The mempool caller (`MemPoolAccept::ConsensusScriptChecks`)

`validation.cpp:1152-1181`: `PolicyScriptChecks` runs the scripts under
`STANDARD_SCRIPT_VERIFY_FLAGS` (1121-1148); only on success does
`ConsensusScriptChecks` re-run them under
`GetBlockScriptFlags(active tip)` (1176), and a failure there is not an
ordinary reject: Core logs "BUG! ... CheckInputScripts failed against
latest-block but not STANDARD flags" and returns `Assume(false)`. The
caller model below pins that call order and that fatal link. -/

/-- Core's `STANDARD_SCRIPT_VERIFY_FLAGS` (policy.h:117-131) projected to
the consensus word: `MANDATORY_SCRIPT_VERIFY_FLAGS` is exactly the seven
consensus bits P2SH|DERSIG|NULLDUMMY|CLTV|CSV|WITNESS|TAPROOT, so the
standard pass's consensus word is the full record. (The additional
standard bits are policy flags and ride in `pol`.) -/
@[rule "TXV-061"]
def standardScriptFlags : ScriptFlags :=
  { p2sh := true, dersig := true, cltv := true, csv := true,
    nullDummy := true, witness := true, taproot := true }

/-- `MemPoolAccept::ConsensusScriptChecks` outcomes: `cached` = the
re-check passed (the script-execution cache is populated and admission
continues); `fatal` = the re-check failed, i.e. the logged BUG plus
`Assume(false)`; `rejected` = the earlier standard/policy script pass
failed (an ordinary mempool rejection); `unjudged` = the seam cannot
adjudicate (taproot script-path EC), so the model makes no claim. -/
@[rule "TXV-061"]
inductive MempoolScriptOutcome where
  | cached
  | fatal
  | rejected
  | unjudged
deriving Repr, DecidableEq, BEq

/-- `ConsensusScriptChecks`: re-run the input scripts under
`GetBlockScriptFlags(tip)` with NO policy bits — Core passes
`currentBlockScriptVerifyFlags` alone (validation.cpp:1176-1178), so the
policy word is `default`. -/
@[rule "TXV-061"]
def mempoolConsensusScriptCheck (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (tipHeight : UInt32) : MempoolScriptOutcome :=
  match scriptRecheckAtTip tx tbl tipHeight (default : PolicyFlags) with
  | some true => .cached
  | some false => .fatal
  | none => .unjudged

/-- `AcceptToMemoryPool`'s two script gates in Core's order: the
standard/policy pass (`PolicyScriptChecks`, `STANDARD_SCRIPT_VERIFY_FLAGS`)
first, then — only when that passed — the current-block consensus
re-check (`ConsensusScriptChecks`). -/
@[rule "TXV-061"]
def mempoolScriptAdmission (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (tipHeight : UInt32) (pol : PolicyFlags) : MempoolScriptOutcome :=
  match scriptLaneTx tx tbl standardScriptFlags pol with
  | some true => mempoolConsensusScriptCheck tx tbl tipHeight
  | some false => .rejected
  | none => .unjudged

/-- The caller really invokes the re-check after a passing standard pass:
the admission outcome is then exactly `mempoolConsensusScriptCheck`. -/
@[rule "TXV-061"]
theorem mempoolScriptAdmission_after_policy_pass
    (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (tipHeight : UInt32) (pol : PolicyFlags)
    (hpass : scriptLaneTx tx tbl standardScriptFlags pol = some true) :
    mempoolScriptAdmission tx tbl tipHeight pol
      = mempoolConsensusScriptCheck tx tbl tipHeight := by
  unfold mempoolScriptAdmission
  rw [hpass]

/-- A failed re-check is the fatal `Assume(false)` arm of
`ConsensusScriptChecks`, not an ordinary policy rejection. -/
@[rule "TXV-061"]
theorem mempoolConsensusScriptCheck_fail_fatal
    (tx : Tx) (tbl : OutPoint → Option ScriptEntry) (tipHeight : UInt32)
    (h : scriptRecheckAtTip tx tbl tipHeight (default : PolicyFlags) = some false) :
    mempoolConsensusScriptCheck tx tbl tipHeight = .fatal := by
  unfold mempoolConsensusScriptCheck
  rw [h]

/-- TXV-061 (the full caller law): after the standard/policy pass, the
current-block re-check runs; if it fails the outcome is `.fatal` (Core's
`Assume(false)`, so no mempool entry) and the same tx is a rejection
under `getBlockScriptFlags tipHeight`. The standard pass cannot make a
tip-flag script failure admissible. -/
@[rule "TXV-061"]
theorem mempoolScriptAdmission_recheck_fail
    (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (u : UtxoSet) (spendHeight : UInt32) (tipHeight : UInt32) (pol : PolicyFlags)
    (hst : checkTransaction tx = none) (hcb : tx.isCoinBase = false)
    (hsup : tableSupplied tx tbl = true)
    (hpass : scriptLaneTx tx tbl standardScriptFlags pol = some true)
    (hre : scriptRecheckAtTip tx tbl tipHeight (default : PolicyFlags) = some false) :
    mempoolScriptAdmission tx tbl tipHeight pol = .fatal ∧
      mempoolScriptAdmission tx tbl tipHeight pol ≠ .cached ∧
      txVerdictFull tx tbl u spendHeight (getBlockScriptFlags tipHeight)
        (default : PolicyFlags) = some false := by
  have hfatal : mempoolScriptAdmission tx tbl tipHeight pol = .fatal := by
    rw [mempoolScriptAdmission_after_policy_pass tx tbl tipHeight pol hpass]
    exact mempoolConsensusScriptCheck_fail_fatal tx tbl tipHeight hre
  refine ⟨hfatal, ?_, ?_⟩
  · rw [hfatal]
    intro hc
    cases hc
  · exact scriptRecheckAtTip_reject tx tbl u spendHeight tipHeight
      (default : PolicyFlags) hst hcb hsup hre

/-- Unjudged propagation: when the pipeline reaches the script lane (the fee
slice adjudicable and passing) and the lane cannot adjudicate (taproot
script-path EC outside the seam), the pipeline's verdict is `none` — the
honest queue, not a guess. -/
theorem txVerdictFull_unjudged_propagate (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (u : UtxoSet) (spendHeight : UInt32) (flags : ScriptFlags) (pol : PolicyFlags)
    (hst : checkTransaction tx = none) (hcb : tx.isCoinBase = false)
    (hsup : tableSupplied tx tbl = true)
    (hfee : feeOk tx u spendHeight = true)
    (hlane : scriptLaneTx tx tbl flags pol = none) :
    txVerdictFull tx tbl u spendHeight flags pol = none := by
  unfold txVerdictFull
  simp only [hst, if_neg (by simp [hcb] : ¬ (tx.isCoinBase = true)),
    if_pos hsup]
  split
  · simp [hfee, hlane]
  · exact hlane

/-- Accept soundness: `some true` means the stateless prefix passed AND
(non-coinbase) every prevout resolved AND — when amounts were adjudicable —
the fee slice accepted AND the script lane verified every input. -/
theorem txVerdictFull_accept_sound (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (u : UtxoSet) (spendHeight : UInt32) (flags : ScriptFlags) (pol : PolicyFlags)
    (h : txVerdictFull tx tbl u spendHeight flags pol = some true) :
    checkTransaction tx = none ∧
      (tx.isCoinBase = true ∨
        (tableSupplied tx tbl = true ∧
          (tableAmountsKnown tx tbl = false ∨ feeOk tx u spendHeight = true) ∧
          scriptLaneTx tx tbl flags pol = some true)) := by
  unfold txVerdictFull at h
  by_cases hst : checkTransaction tx = none
  · simp only [hst] at h
    by_cases hcb : tx.isCoinBase = true
    · exact ⟨hst, Or.inl hcb⟩
    · rw [if_neg (by simp [hcb] : ¬ (tx.isCoinBase = true))] at h
      by_cases hsup : tableSupplied tx tbl = true
      · rw [if_pos hsup] at h
        by_cases hamt : tableAmountsKnown tx tbl = true
        · rw [if_pos hamt] at h
          by_cases hfee : feeOk tx u spendHeight = true
          · rw [if_pos hfee] at h
            exact ⟨hst, Or.inr ⟨hsup, ⟨Or.inr hfee, h⟩⟩⟩
          · rw [if_neg (by simp [hfee] : ¬ (feeOk tx u spendHeight = true))] at h
            simp at h
        · have hamt' : tableAmountsKnown tx tbl = false := by
            simpa using hamt
          rw [if_neg (by simp [hamt] : ¬ (tableAmountsKnown tx tbl = true))] at h
          exact ⟨hst, Or.inr ⟨hsup, Or.inl hamt', h⟩⟩
      · rw [if_neg (by simp [hsup] : ¬ (tableSupplied tx tbl = true))] at h
        simp at h
  · rcases he : checkTransaction tx with _ | e
    · exact absurd hst (by rw [he]; simp)
    · simp only [he] at h; exact absurd h (by simp)

/-- The lane's accept is an all-inputs verify: `scriptLane = some true`
implies every input in the walked list resolved in the table AND its
`verifyScriptFull` returned `.ok` at its own index. -/
theorem scriptLane_true_all_ok (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (flags : ScriptFlags) (pol : PolicyFlags) :
    ∀ (l : List TxIn) (n : Nat),
      scriptLane tx tbl flags pol l n = some true →
      ∀ (k : Nat) (i : TxIn), l[k]? = some i →
        ∃ spk amt, tbl i.prevout = some (spk, amt) ∧
          verifyScriptFull (pipelineFuel i.scriptSig.bytes spk (tx.witness.getD (n + k) []))
            flags pol i.scriptSig.bytes spk (tx.witness.getD (n + k) [])
            (txCheckerFor tx (n + k) amt) = .ok := by
  intro l
  induction l with
  | nil => intro n _ k i hget; simp at hget
  | cons j rest ih =>
    intro n hacc k i hget
    simp only [scriptLane] at hacc
    cases ht : tbl j.prevout with
    | none => simp only [ht] at hacc; simp at hacc
    | some e =>
      obtain ⟨spk, amt⟩ := e
      simp only [ht] at hacc
      cases hvo : verifyScriptFull (pipelineFuel j.scriptSig.bytes spk
          (tx.witness.getD n [])) flags pol j.scriptSig.bytes spk
          (tx.witness.getD n []) (txCheckerFor tx n amt) with
      | ok =>
        simp only [hvo] at hacc
        cases k with
        | zero =>
            simp only [List.getElem?_cons_zero] at hget
            cases hget
            refine ⟨spk, amt, ht, ?_⟩
            rwa [Nat.add_zero]
        | succ k' =>
            rw [List.getElem?_cons_succ] at hget
            obtain ⟨spk', amt', ht', hok⟩ := ih (n + 1) hacc k' i hget
            refine ⟨spk', amt', ht', ?_⟩
            have hidx : n + 1 + k' = n + (k' + 1) := by omega
            rwa [hidx] at hok
      | fail _ => simp only [hvo] at hacc; simp at hacc
      | unjudged => simp only [hvo] at hacc; simp at hacc

/-- The tx-level wrapper instantiates the lane law over `tx.vin` from
index 0 (`n + 0` collapses to the lane's index). -/
theorem scriptLaneTx_true_all_ok (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (flags : ScriptFlags) (pol : PolicyFlags)
    (h : scriptLaneTx tx tbl flags pol = some true) :
    ∀ (k : Nat) (i : TxIn), tx.vin[k]? = some i →
      ∃ spk amt, tbl i.prevout = some (spk, amt) ∧
        verifyScriptFull (pipelineFuel i.scriptSig.bytes spk (tx.witness.getD k []))
          flags pol i.scriptSig.bytes spk (tx.witness.getD k [])
          (txCheckerFor tx k amt) = .ok := by
  intro k i hget
  have hres := scriptLane_true_all_ok tx tbl flags pol tx.vin 0 h k i hget
  simpa only [Nat.zero_add] using hres

/-- TXV-061 (the re-run is under consensus flags): every input the
re-check accepts was verified by `verifyScriptFull` with
`getBlockScriptFlags tipHeight` — the active tip's consensus word. -/
@[rule "TXV-061"]
theorem scriptRecheckAtTip_true_all_ok (tx : Tx) (tbl : OutPoint → Option ScriptEntry)
    (tipHeight : UInt32) (pol : PolicyFlags)
    (h : scriptRecheckAtTip tx tbl tipHeight pol = some true) :
    ∀ (k : Nat) (i : TxIn), tx.vin[k]? = some i →
      ∃ spk amt, tbl i.prevout = some (spk, amt) ∧
        verifyScriptFull (pipelineFuel i.scriptSig.bytes spk (tx.witness.getD k []))
          (getBlockScriptFlags tipHeight) pol i.scriptSig.bytes spk
          (tx.witness.getD k [])
          (txCheckerFor tx k amt) = .ok := by
  intro k i hget
  exact scriptLaneTx_true_all_ok tx tbl (getBlockScriptFlags tipHeight) pol h k i hget

/-! ## Axiom pins (every theorem here is sorry-free; standard axioms only) -/

section Pins

/-- info: 'Bitcoin.TxValidation.Full.txVerdictFull_total' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms txVerdictFull_total
/-- info: 'Bitcoin.TxValidation.Full.txVerdictFull_stateless_reject' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms txVerdictFull_stateless_reject
/-- info: 'Bitcoin.TxValidation.Full.txVerdictFull_coinbase_skip' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms txVerdictFull_coinbase_skip
/-- info: 'Bitcoin.TxValidation.Full.txVerdictFull_prevout_reject' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms txVerdictFull_prevout_reject
/-- info: 'Bitcoin.TxValidation.Full.txVerdictFull_fee_reject' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms txVerdictFull_fee_reject
/-- info: 'Bitcoin.TxValidation.Full.txVerdictFull_script_fail' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms txVerdictFull_script_fail
/-- info: 'Bitcoin.TxValidation.Full.txVerdictFull_unjudged_propagate' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms txVerdictFull_unjudged_propagate
/-- info: 'Bitcoin.TxValidation.Full.txVerdictFull_accept_sound' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms txVerdictFull_accept_sound
/-- info: 'Bitcoin.TxValidation.Full.scriptLane_true_all_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms scriptLane_true_all_ok
/-- info: 'Bitcoin.TxValidation.Full.scriptLaneTx_true_all_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms scriptLaneTx_true_all_ok
/-- info: 'Bitcoin.TxValidation.Full.scriptFailKind_consensus' depends on axioms: [propext] -/
#guard_msgs in #print axioms scriptFailKind_consensus
/-- info: 'Bitcoin.TxValidation.Full.scriptFailKind_not_standard' does not depend on any axioms -/
#guard_msgs in #print axioms scriptFailKind_not_standard
/-- info: 'Bitcoin.TxValidation.Full.hasStandardNotMandatory_sigPushOnly' does not depend on any axioms -/
#guard_msgs in #print axioms hasStandardNotMandatory_sigPushOnly
/-- info: 'Bitcoin.TxValidation.Full.sigPushOnly_ne_default' does not depend on any axioms -/
#guard_msgs in #print axioms sigPushOnly_ne_default
/-- info: 'Bitcoin.TxValidation.Full.scriptFailKind_sigPushOnly' does not depend on any axioms -/
#guard_msgs in #print axioms scriptFailKind_sigPushOnly
/-- info: 'Bitcoin.TxValidation.Full.txVerdictFull_script_fail_kind' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms txVerdictFull_script_fail_kind
/-- info: 'Bitcoin.TxValidation.Full.scriptRecheckAtTip_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms scriptRecheckAtTip_eq
/-- info: 'Bitcoin.TxValidation.Full.scriptRecheckAtTip_true_all_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms scriptRecheckAtTip_true_all_ok
/-- info: 'Bitcoin.TxValidation.Full.scriptRecheckAtTip_reject' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms scriptRecheckAtTip_reject
/-- info: 'Bitcoin.TxValidation.Full.mempoolScriptAdmission_after_policy_pass' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms mempoolScriptAdmission_after_policy_pass
/-- info: 'Bitcoin.TxValidation.Full.mempoolConsensusScriptCheck_fail_fatal' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms mempoolConsensusScriptCheck_fail_fatal
/-- info: 'Bitcoin.TxValidation.Full.mempoolScriptAdmission_recheck_fail' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms mempoolScriptAdmission_recheck_fail

end Pins

end Bitcoin.TxValidation.Full
