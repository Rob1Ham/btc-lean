import BitcoinVectors.Records
import Bitcoin.Consensus.TxCheck
import Bitcoin.Data.Script
import Bitcoin.Script.Interp
import Bitcoin.Crypto.Taproot.Verify
import Bitcoin.Serialization.Interface
import Bitcoin.SigHash.Interface
import Bitcoin.Interpreter.Interface
import Bitcoin.TxValidation.Interface
import Bitcoin.Crypto.Schnorr.Verify
import Bitcoin.TxValidation.Full

/-!
# BitcoinVectors.Backend — the workstream plug-in seam (W07)

The runner computes verdicts ONLY through the functions in this file. Each
conformance layer has a `LayerMode`: `live` (the runner calls a real,
sorry-free implementation) or `stub` (the frozen interface body is still a
frozen placeholder — calling it at runtime would hit an `executed 'sorry'`
panic, so the runner REPORTS the layer as `stub` and never calls it).

## Backend extension protocol

1. Land an implementation behind the frozen interface (fill the
   `opaque ... := sorry` body in the corresponding `Interface.lean` — no
   signature change).
2. In THIS file, extend the corresponding `*Backend` def below (or replace
   the placeholder with a call into the interface), then flip the layer's
   `mode*` from `.stub` to `.live`.
3. Re-run `bash spec/scripts/dashboard.sh` to refresh the raw
   `spec/db/results.json` record. This does not rewrite the census or
   create a proof claim.

The layer→owner table is in the module docstrings of `spec/core/Bitcoin/*/
Interface.lean`; the rule→vector join lives in `spec/db/vector_ids.yaml`.
-/

namespace BitcoinVectors

open Bitcoin.Data Bitcoin.Consensus Bitcoin.Script Bitcoin.Serialization
open Bitcoin.TxValidation Bitcoin.Ledger

inductive LayerMode where
  | live | stub
deriving DecidableEq, Repr

/-- TXV stateless prefix (C1 `checkTransaction`, 16 `@[rule]` rows). LIVE. -/
def modeTxvStateless : LayerMode := .live
/-- SCR legacy subset via the C1 PoC interpreter (no flags/P2SH/witness).
    Superseded when W09's `verifyScript` lands. LIVE (baseline-grade). -/
def modeScriptLegacy : LayerMode := .live
/-- TXV contextual/inputs layer — calls W10's `checkTxInputs`. LIVE (W10). -/
def modeTxvContextual : LayerMode := .live
/-- SER decode layer — calls W02's `decodeTx`. LIVE (C02: raw-tx capture in
TxVec + the `serDecodeVerdict` judge below). -/
def modeSer : LayerMode := .live
/-- Sighash layer (legacy + BIP143) — calls W11's digest constructions. LIVE (W11). -/
def modeSighash : LayerMode := .live
/-- BIP340 Schnorr — calls X02's real `verifyImpl` (BIP340 over the W14b
curve layer) behind W13's seam. LIVE (X02). -/
def modeBip340 : LayerMode := .live

/-! ## Live backends -/

/-- Statelesss tx verdict: the C1 `CheckTransaction` transliteration
(`spec/core/Bitcoin/Consensus/TxCheck.lean`, rows INV-001..009/TXV-001..009). -/
def txStatelessError (v : TxVec) : Option TxCheckError :=
  checkTransaction v.tx

/-- Legacy script driver over the C1 PoC interpreter
(`Bitcoin.Data.Script.parse` + `Bitcoin.Script.Interp.run`): scriptSig runs
to completion, scriptPubKey runs on the resulting stack, success = final
stack non-empty with truthy top (Core's cast_to_bool convention). This is
the DELIBERATELY SIMPLIFIED baseline: no P2SH, no flags, no witness, no
CScriptNum sign rules — W09's `verifyScript` replaces it. -/
def legacyScriptRun (ss spk : ByteArray) : Bool :=
  match Script.parse ⟨ss⟩ with
  | none => false
  | some p1 =>
    match run 10000 p1 [] with
    | .error _ => false
    | .ok st1 =>
      match Script.parse ⟨spk⟩ with
      | none => false
      | some p2 =>
        match run 10000 p2 st1 with
        | .ok (top :: _) => top.size ≠ 0
        | _ => false

/-! ## Core `DoTest` preimage (script_tests.cpp:125-136) -/

/-- `BuildCreditingTransaction` (test/util/transaction_utils.cpp:15):
version 1, nLockTime 0, one input (null prevout; scriptSig
`CScript() << CScriptNum(0) << CScriptNum(0)` = two empty-vector pushes =
`0x00 0x00`, script.h `operator<<(CScriptNum)` → `AppendDataSize(0)`;
nSequence FINAL), one output (`scriptPubKey`, `value`). -/
def doTestCredit (spk : ByteArray) (value : Amount) : Tx :=
  { version := 1
  , vin := [{ prevout := OutPoint.null
            , scriptSig := ⟨ByteArray.mk #[0x00, 0x00]⟩
            , sequence := 0xFFFFFFFF }]
  , vout := [{ value := value, scriptPubKey := ⟨spk⟩ }]
  , locktime := 0
  , witness := [] }

/-- `BuildSpendingTransaction` (transaction_utils.cpp:32): version 1,
nLockTime 0, one input (prevout = the crediting tx's txid — `GetHash` =
sha256d over the WITNESSLESS serialization (BIP141), raw digest bytes,
little-endian on the wire; index 0; scriptSig; nSequence FINAL;
scriptWitness), one output (EMPTY scriptPubKey, the credited value). -/
def doTestSpend (ss : ByteArray) (w : WitnessStack) (credit : Tx)
    (value : Amount) : Tx :=
  { version := 1
  , vin := [{ prevout :=
               ⟨Bitcoin.Crypto.Seam.sha256d (encodeTxNoWitness credit), 0⟩
            , scriptSig := ⟨ss⟩
            , sequence := 0xFFFFFFFF }]
  , vout := [{ value := value, scriptPubKey := Script.empty }]
  , locktime := 0
  , witness := [w] }

/-- Literal-byte scan for tapscript signature opcodes (conservative: a
data byte equal to the opcode also counts; over-approximation only
weakens the verdict). -/
def hasTapscriptSigOp (s : ByteArray) : Bool :=
  s.toList.any (fun b => [0xac, 0xad, 0xba].contains b)

/-- Literal-byte scan for OP_IF/OP_NOTIF (branching). -/
def hasConditionalOp (s : ByteArray) : Bool :=
  s.toList.any (fun b => [0x63, 0x64].contains b)

/-- Taproot script-path corpus verdict — Core `VerifyWitnessProgram`'s
script-path arm (interpreter.cpp:1976-1993), the composition
`verifyScriptFull` leaves `.unjudged`: control-block size gate + tapleaf
hash + `CheckTapTweak` commitment (`Crypto.Taproot.Verify.scriptPathSpend`)
→ BIP342 `ExecuteWitnessScript` over the remaining witness stack.
`none` = not a bare v1 script-path spend, or a verdict that could depend
on the tapleaf hash being threaded into `ScriptExecutionData` for a
32-byte-key Schnorr sighash (the Defs executor seeds `ed` from
`default`): such rows stay queued rather than guessed. Straight-line
scripts (no OP_IF/OP_NOTIF) that fail at `TAPSCRIPT_EMPTY_PUBKEY`
(before any EC check) are adjudicable regardless. -/
def taprootScriptPathVerdict (v : ScrVec) : Option Bool :=
  if v.scriptSig.size ≠ 0 then none else
  match Bitcoin.Interpreter.isWitnessProgram v.scriptPubKey with
  | some (1, program) =>
    let annex := 2 ≤ v.witness.length ∧ (v.witness.getLast!).size ≠ 0 ∧
      (Bitcoin.Interpreter.byteOr (v.witness.getLast!) 0).toNat = 0x50
    let stack := if annex then v.witness.dropLast else v.witness
    match stack.reverse with
    | control :: script :: rest =>
      match Bitcoin.Crypto.Taproot.Verify.scriptPathSpend control script program with
      | some (_, committed, isTapscript) =>
        if !committed then some false
        else if !isTapscript then none
        else
          let credit := doTestCredit v.scriptPubKey v.value
          let spend := doTestSpend v.scriptSig v.witness credit v.value
          let chk := Bitcoin.Capstone.RealChecker.realCheckerFullOf spend 0 v.value
          match Bitcoin.Interpreter.executeWitnessScript
              (Bitcoin.TxValidation.Full.pipelineFuel
                v.scriptSig v.scriptPubKey v.witness) rest.reverse
              (Bitcoin.Interpreter.witnessSerSize v.witness) script v.flags
              (Bitcoin.Interpreter.parsePolicyFlags v.policyFlags) chk
              Bitcoin.Crypto.Seam.SigVersion.tapscript with
          | .ok => if hasTapscriptSigOp script then none else some true
          | .fail e =>
            if hasTapscriptSigOp script then
              if e = .tapscriptEmptyPubkey ∧ !hasConditionalOp script then some false
              else none
            else some false
          | .unjudged => none
      | none => some false
    | _ => none
  | _ => none

/-- Script verdict (W09 + W14b EC). `none` = this backend cannot judge
the row. Core's `DoTest` (script_tests.cpp:125-136) executes every row as
`VerifyScript(scriptSig, scriptPubKey, witness, flags,
MutableTransactionSignatureChecker(&txSpend, 0, nValue,
MissingDataBehavior::ASSERT_FAIL))` over the fixed
`BuildCreditingTransaction`/`BuildSpendingTransaction` pair — a REAL
secp256k1 checker over the real sighash preimage, never a stub. This
backend reproduces that judge: `realCheckerFullOf` (W14b lax-ECDSA
`verifyImpl` + W11 `sighashDispatch` + X02 BIP340 + the real locktime
environment) over the row assembled the same way — `ScrVec.value` is the
witness array's trailing `nValue` (`AmountFromValue`, script_tests.cpp:953),
`0` = the `DoTest` default. `unjudged` (taproot script-path spending —
CheckTapTweak EC is outside the W13 seam) maps to `none`. CLEANSTACK
requires P2SH+WITNESS in Core (asserted), so the flags are forced
accordingly when the policy carries it. Fuel is the production path's
witness-aware `pipelineFuel` (ss + spk + every witness item + 28), so
witness-script bytes count: a P2WSH opcode budget is never truncated by
the runner (F-L2SCR-002). -/
def scrVerdict (v : ScrVec) : Option Bool :=
  let pol := Bitcoin.Interpreter.parsePolicyFlags v.policyFlags
  let flags :=
    if pol.cleanstack then { v.flags with p2sh := true, witness := true } else v.flags
  let credit := doTestCredit v.scriptPubKey v.value
  let spend := doTestSpend v.scriptSig v.witness credit v.value
  let chk : Bitcoin.Interpreter.ScriptChecker :=
    Bitcoin.Capstone.RealChecker.realCheckerFullOf spend 0 v.value
  match Bitcoin.Interpreter.verifyScriptFull
      (Bitcoin.TxValidation.Full.pipelineFuel
        v.scriptSig v.scriptPubKey v.witness) flags pol
      v.scriptSig v.scriptPubKey v.witness chk with
  | .ok => some true
  | .fail _ => some false
  | .unjudged => taprootScriptPathVerdict v

/-! ## C02 ser_decode backend (LIVE) -/

/-- SER decode verdict (W02's `decodeTx` over the corpus raw bytes).
`v.rawTx` is the case's verbatim wire hex; `v.tx` the codegen reference
decode of the SAME bytes (both emitted by `codegen.py`).
* decode fails on an expect-invalid row → `some true` (a legitimate
  rejection: the malformed-serialization slice of tx_invalid);
* decode fails on an expect-valid row → `some false` (real conformance
  failure: Lean's decoder rejects what Core accepts);
* decode succeeds → the decoded tx must (a) RE-ENCODE to exactly the
  corpus wire bytes — the witness-aware roundtrip, i.e. the txid-witness
  (wtxid) preimage matches — and (b) agree with the reference decode on
  the base (no-witness) serialization — the txid preimage (`encodeTxNoWitness`
  is by definition what txid is computed over). Canonical-variant wire
  bytes (non-minimal encodings Core re-encodes differently) surface as
  roundtrip mismatches = `some false`.
`none` is not produced: the judge is total. -/
def serDecodeVerdict (v : TxVec) : Option Bool :=
  match decodeTx v.rawTx with
  | .error _ => some (!v.expectValid)
  | .ok tx =>
    some (bytesBEq (encodeTx tx) v.rawTx
      && bytesBEq (encodeTxNoWitness tx) (encodeTxNoWitness v.tx))

/-! ## W10 contextual backend (LIVE) -/

/-- The corpus spend height for `checkTxInputs` (W07 handoff convention):
coins enter the view at height 0 as non-coinbase (the tx_*.json corpora
carry no block context), so any height ≥ `COINBASE_MATURITY` keeps the
maturity gate vacuous — 100 it is. -/
def ctxSpendHeight : UInt32 := 100

/-- Materialize the UTXO view from the vector's prevout table: coin at
`(txid-wire-bytes, n)` with the corpus amount, height 0, non-coinbase.
Entries with the `-1` "amount omitted" sentinel supply NO coin. -/
def utxoOfPrevouts (ps : List (ByteArray × UInt32 × ByteArray × Amount)) :
    Bitcoin.Ledger.UtxoSet := fun o =>
  match ps.find? (fun p => bytesBEq p.1 o.hash && p.2.1 == o.n) with
  | some ⟨_, _, spk, v⟩ => if 0 ≤ v then some ⟨v, 0, false, ⟨spk⟩⟩ else none
  | none => none

/-- Every input's prevout appears in the vector's prevout table. -/
def prevoutSupplied (v : TxVec) : Bool :=
  v.tx.vin.all (fun i =>
    v.prevouts.any (fun p => bytesBEq p.1 i.prevout.hash && p.2.1 == i.prevout.n))

/-- Every prevout entry carries a corpus amount (`≥ 0`; `-1` = omitted). -/
def allPrevoutValuesKnown (v : TxVec) : Bool :=
  v.prevouts.all (fun p => 0 ≤ p.2.2.2)

/-- Contextual verdict (W10's slice of the Core pipeline, `tx_*.json`
semantics — `CheckTransaction` + `HaveInputs` + `CheckTxInputs`; the
corpora encode NO block context, so finality/BIP68/maturity are
adjudicated by the block-context layer, W12):
* stateless rejection → `some false` (validateTx's prefix rejects);
* coinbase → `some true` (TXV-072 early-exit: no inputs are consulted);
* some input's prevout absent from the table → `some false` (HaveInputs);
* all amounts present → `some (checkTxInputs … = ok)` (TXV-020/023/024/025);
* feeless row → `some true`: the adjudicable slice accepts (Core's test
  asserts only stateless+script for these rows — amounts feed the script
  checker's `amount` only, and the script layer owns that verdict).
`none` is reserved for rows the slice cannot judge. -/
def txContextualVerdict (v : TxVec) : Option Bool :=
  if (txStatelessError v).isSome then some false
  else if v.tx.isCoinBase then some true
  else if ! prevoutSupplied v then some false
  else if allPrevoutValuesKnown v then
    some (match checkTxInputs v.tx (utxoOfPrevouts v.prevouts) ctxSpendHeight with
          | .ok _ => true
          | .error _ => false)
  else some true

/-! ## X09 full tx-pipeline backend (LIVE) -/

/-- X09's full-pipeline layer mode (W10 contextual tier + the per-input real
script lane). LIVE (X09). -/
def modeTxvFull : LayerMode := .live

/-- The resolved-prevout script table for a corpus row: `(scriptPubKey,
amount)` per input, with the `-1` "amount omitted" sentinel mapped to
`none` — the signature checker's missing-data state (SWT-055 fail-closed
on WITNESS_V0 sighashes; legacy sighashes are amount-free). -/
def txFullTable (v : TxVec) :
    OutPoint → Option Bitcoin.TxValidation.Full.ScriptEntry :=
  fun o =>
    match v.prevouts.find? (fun p => bytesBEq p.1 o.hash && p.2.1 == o.n) with
    | some ⟨_, _, spk, amt⟩ => some (spk, if amt < 0 then none else some amt)
    | none => none

/-- X09's full-pipeline tx verdict (`Bitcoin.TxValidation.Full.txVerdictFull`):
stateless prefix → coinbase early-exit → prevout resolution (TXV-020) →
fee slice (TXV-023/024/025) → per-input real `verifyScriptFull` (TXV-058)
under the caller's flag word (TXV-061). CLEANSTACK forces P2SH + WITNESS
exactly as `scrVerdict` (Core asserts the implication). A `none` verdict —
the script lane hit `unjudged` (taproot script-path EC outside the W13
seam; the BIP342 sighash remains the fail-closed X03/X04 stand-in) — falls
back to the contextual tier's verdict: the lane cannot adjudicate those
rows at all, so the tier's slice is the honest residual judgment. -/
def txFullVerdict (v : TxVec) : Option Bool :=
  let pol := Bitcoin.Interpreter.parsePolicyFlags v.policyFlags
  let flags :=
    if pol.cleanstack then { v.flags with p2sh := true, witness := true } else v.flags
  Bitcoin.TxValidation.Full.txVerdictFull v.tx (txFullTable v)
    (utxoOfPrevouts v.prevouts) ctxSpendHeight flags pol
/-- W11 sighash backend (LIVE): decode `v.rawTx` (W02 `decodeTx`), run the
legacy digest (the 500-row corpus is pre-SegWit), compare against
`v.expected` — uint256::GetHex order, i.e. the REVERSED internal digest
(byte-order note in spec/Test/Sighash/SighashTest.lean). `none` = row not
judgeable (decode failure). BIP143 rows are exercised by the
spec/Test/Sighash harness (bip-0143.mediawiki worked examples). -/
def sighashVerdict (v : SghVec) : Option Bool :=
  match decodeTx v.rawTx with
  | .error _ => none
  | .ok tx =>
    some (bytesBEq
      (Bitcoin.SigHash.signatureHashLegacy tx v.inputIndex ⟨v.scriptCode⟩ v.hashType)
      (bytesOfList (bL v.expected).reverse))

/-- BIP340 backend (X02, LIVE): the real `Schnorr.Verify.verifyImpl` on the
generated corpus row — verdict of the BIP340 algorithm over the W14b curve
layer (lift_x even-y, r < p, s < n, tagged challenge, s·G − e·P triple).
`none` is not produced: verifyImpl is total (TPR-053). -/
def bip340Verdict (v : Bip340Vec) : Option Bool :=
  some (Bitcoin.Crypto.Schnorr.Verify.verifyImpl v.sig v.pubKey v.msg)

end BitcoinVectors
