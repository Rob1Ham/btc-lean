import Bitcoin.Capstone.Pow
import Bitcoin.Capstone.Context
import Bitcoin.Capstone.Merkle
import Bitcoin.Capstone.RealChecker
import Bitcoin.Ledger.Interface
import Bitcoin.Consensus.TxCheck
import Bitcoin.TxValidation.Interface
import Bitcoin.Activation.Interface
import Bitcoin.Interpreter.Interface
import Bitcoin.Block.Sigops
import Bitcoin.Activation.Flags

/-!
# Bitcoin.Capstone.Block — serialized replay and contextual header checks (S2b)

`validateBlock : SerializedBlock → CapState → Except CapError CapReport`
composes the modeled gates on real serialized bytes. The default call is
partial replay (`replayBlock`); an explicit `ChainContext` adds header,
absolute-finality and both BIP68-domain checks. Both entries enforce
legacy and contextual sigop budgets. Remaining witness/Taproot and historical
exception defects are actionable work in the remediation ledger, not assumed
consensus validity. The gates currently composed are:

1. **Decode**: `decodeBlock` — header, tx count, txs (BIP144
   witness framing per tx).
2. **Structure** (BLK rows): vtx non-empty (BLK-022), vtx[0] is the
   coinbase and only it (BLK-027/028), coinbase scriptSig 2..100 bytes
   (BLK-029), weight budget (BLK-023/024/025/026).
3. **Header** (this module): PoW (BLK-037/038/039) + chain link
   (`hashPrevBlock` vs the state's `prevHash` — for the anchor run the
   link target is the REAL parent block hash supplied per anchor, since
   the anchors skip intermediate blocks). With `ChainContext`, also
   require the parent-bound ancestor lookup, expected mainnet nBits, the
   complete parent MTP window and the explicit node-clock future bound.
   Without it, this is partial replay (`replayBlock`), not full validation.
4. **Merkle** (this module): txid tree vs header (BLK-010) + the witness
   commitment gate (BLK-015..020).
5. **Per tx, in order** (Core ConnectBlock's UTXO-side order):
   `checkTransaction` (BLK-030) → for non-coinbase
   `checkTxInputs` (TXV) against the CURRENT fold state → running fee
   MoneyRange (BLK-091) → BIP68 when context is supplied → cumulative
   sigop cost (BLK-036), including coinbase → per-input
   `verifyScriptFull` with the real checker (ECDSA wiring,
   `RealChecker.realCheckerOf`) → `applyTxStepL` (fold step,
   BIP30/inputs/maturity/UpdateCoins keyed by the REAL txid
   — `txidKey`, not test placeholder `txidPreimageKey`).
6. **Reward**: coinbase outputs ≤ accumulated checked fees + the
   subsidy at the supplied height (BLK-089/090).

## Depth semantics (HONEST reporting — see report §3)

* Every tx of every anchor passes the stateless + ledger gates, and every
  non-coinbase input's script runs under `verifyScriptFull` with REAL
  ECDSA — except inputs whose scriptPubKey is a **v1 witness program**
  (Taproot). Those take the `unjudged` lane: their coin is spent in the
  ledger fold, their script check is recorded `unjudgedTaproot` and does
  NOT gate the block verdict (schnorrEntry is fail-closed until
  the implementation ships BIP340; letting it run would misreport a valid block).
  Semantics = a documented, per-input assume-valid for Taproot ONLY;
  the 709632 key-path spend count is reported.
* `.unjudged` from `verifyScriptFull` (taproot script-path spending) is
  treated the same, by construction of the interpreter.

Errors report the offending tx/input index where applicable.
-/

namespace Bitcoin.Capstone.Block

open Bitcoin.Capstone.Pow Bitcoin.Capstone.Merkle Bitcoin.Capstone.RealChecker
open Bitcoin.Data Bitcoin.Ledger Bitcoin.Consensus Bitcoin.TxValidation
open Bitcoin.Activation Bitcoin.Interpreter Bitcoin.Serialization

/-- Inhabited stand-in for `getD` on `tx.vin` (real inputs never hit it). -/
private def dummyTxIn : TxIn := ⟨OutPoint.null, Script.empty, 0xFFFFFFFF⟩

/-- Inhabited stand-in for `getD` on `txs` (the block is non-empty by
BLK-022 before any coinbase gate reads it). Public so downstream proof
modules can state the pipeline's contextual-prelude theorems without
re-declaring it. -/
def dummyTx : Tx := ⟨0, [], [], 0, []⟩

/-- `do`-notation's `throw` is `Except.error` for the pipeline's monad.
`throw` is a `MonadExcept` method, so `simp` cannot see through it
without the specialised equation. -/
@[simp] theorem throw_except_error {ε β : Type} (e : ε) :
    (throw e : Except ε β) = Except.error e := rfl

/-! ## Errors -/

/-- Capstone-level failure taxonomy: every Core layer's error embedded,
plus the header/merkle checks this module owns. -/
inductive CapError where
  | context (e : Bitcoin.Capstone.Context.ContextError)
  | ser (e : SerError)
  | txCheck (e : TxCheckError)      -- the transaction-validation layer stateless (BLK-030)
  | tx (e : TxError)                -- transaction-validation and ledger context
  | block (e : BlockError)          -- the ledger layer fold (BIP30, cb-missing/multiple)
  | emptyBlock                      -- BLK-022
  | badCbPosition                   -- BLK-027/BLK-028
  | badCbLength                     -- BLK-029
  | badBlkWeight                    -- BLK-024/BLK-026
  | badFeeAccum                     -- BLK-091
  | badCbAmount                     -- BLK-089
  | badBlkSigops                    -- BLK-036
  | badPow                          -- BLK-039 (high-hash) / BLK-038
  | badChainLink                    -- hashPrevBlock ≠ expected parent
  | badMerkleRoot                   -- BLK-010
  | blockMutated                    -- BLK-011 (BLOCK_MUTATED, bad-txns-duplicate)
  | unexpectedWitness               -- BLK-019
  | badWitnessCommitment            -- BLK-017/BLK-020
  | badWitnessNonce                 -- BLK-018
  | badVersion                      -- BLK-060/061/062
  | badCbHeight                     -- BLK-069 (BIP34)
  | scriptFail (txIdx inputIdx : Nat) (e : ExecError)
  | scriptFalse (txIdx inputIdx : Nat)
deriving Repr, DecidableEq

/-- Core's exact reject strings for the Capstone taxonomy (report use). -/
def CapError.reason : CapError → String
  | .context e => e.reason
  | .ser _ => "decode-error"
  | .txCheck e => txCheckReason e
  | .tx e => Bitcoin.TxValidation.rejectReason e
  | .block e => match e with
    | .txError e' => Bitcoin.TxValidation.rejectReason e'
    | .badTxnsBIP30 => "bad-txns-BIP30"
    | .badCbMissing => "bad-cb-missing"
    | .badCbMultiple => "bad-cb-multiple"
  | .emptyBlock => "bad-blk-length (empty vtx)"  -- Core: "bad-cb-missing" via empty check
  | .badCbPosition => "bad-cb-missing/multiple"
  | .badCbLength => "bad-cb-length"
  | .badBlkWeight => "bad-blk-weight"
  | .badFeeAccum => "bad-txns-accumulated-fee-outofrange"
  | .badCbAmount => "bad-cb-amount"
  | .badBlkSigops => "bad-blk-sigops"
  | .badPow => "high-hash"
  | .badChainLink => "bad-prevblk"
  | .badMerkleRoot => "bad-txnmrklroot"
  | .blockMutated => "bad-txns-duplicate"
  | .unexpectedWitness => "unexpected-witness"
  | .badWitnessCommitment => "bad-witness-merkle-match"
  | .badWitnessNonce => "bad-witness-nonce-size"
  | .badVersion => "bad-version"
  | .badCbHeight => "bad-cb-height"
  | .scriptFail _ _ _ => "script-verify-error"
  | .scriptFalse _ _ => "script-eval-false"

/-- Context acquisition failures mean validation is unavailable. The three
contextual header consensus failures remain ordinary rejection verdicts. -/
def CapError.isUnavailable : CapError → Bool
  | .context e => e.isUnavailable
  | _ => false

/-! ## State -/

/-- The chain state a block is validated against: the connection height,
the expected parent hash, and the UTXO view (assoc-list executable tier —
for the anchor run this is the REAL prevout view, materialized from
fetched chain data; see report §3.1). -/
structure CapState where
  height : UInt32
  prevHash : ByteArray
  utxo : List (OutPoint × Coin)
deriving Repr

/-- **BLK-005-keyed ledger key**: the fold keys coins by the REAL txid —
`txidKey tx = fun _ k ⇒ ⟨txidOf tx, k⟩` — replacing test
placeholder `txidPreimageKey` (which uses the preimage itself as the key
hash). All of the fold theorems quantify over the general
`kf : Tx → Key`, so this substitution is inside the abstracted surface. -/
@[rule "BLK-005"]
def txidKey (tx : Tx) : Key := fun _ k => ⟨txidOf tx, k⟩

/-! ## Block-level statics -/

/-- CompactSize width of the tx-count prefix. -/
def txCountPrefix (txs : List Tx) : Nat :=
  (encodeCompactSize txs.length).size

/-- **BLK-024**: stripped size = header + count prefix + Σ base-tx bytes;
× 4 ≤ 4,000,000. -/
@[rule "BLK-024"]
def strippedSize (txs : List Tx) : Nat :=
  80 + txCountPrefix txs + (txs.map (fun t => (serTx t).size)).foldl Nat.add 0

/-- **BLK-025**: weight = 3 × stripped + total (BIP141). SWT-017: the
block-weight formula `base × 3 + total` (the ≤ 4,000,000 gate is
BLK-026's `weightOk`). -/
@[rule "BLK-025", rule "SWT-017"]
def blockWeight (txs : List Tx) (totalSize : Nat) : Nat :=
  3 * strippedSize txs + totalSize

/-- **BLK-026**: weight ≤ 4,000,000 (checked after the commitment gate,
hash-invariance order per BLK-021). -/
@[rule "BLK-026", rule "INV-093"]
def weightOk (txs : List Tx) (totalSize : Nat) : Bool :=
  blockWeight txs totalSize ≤ 4_000_000

/-- **BLK-029**: coinbase vin scriptSig size ∈ [2, 100]. -/
@[rule "BLK-029"]
def cbLengthOk (cb : Tx) : Bool :=
  2 ≤ (cb.vin.getD 0 dummyTxIn).scriptSig.bytes.size && (cb.vin.getD 0 dummyTxIn).scriptSig.bytes.size ≤ 100

/-- Little-endian base-256 digits of `n` — least-significant byte first,
per `CScriptNum::getvch` — with redundant zero digits stripped (heights
< 2^32 ⇒ at most 4 digits; `n ≥ 1` in every BIP34-active use, so the
stripped list is non-empty). -/
private def cbHeightDigits (n : Nat) : List UInt8 :=
  let l := [(n % 256).toUInt8, (n / 256 % 256).toUInt8,
            (n / 65536 % 256).toUInt8, (n / 16777216 % 256).toUInt8]
  match l.reverse.dropWhile (fun b => b.toNat == 0) with
  | [] => []
  | l' => l'.reverse

/-- `CScriptNum(height)` serialization (CScriptNum::getvch): little-endian
magnitude, sign byte appended when the top byte has the high bit set. -/
def cbHeightBytes (n : Nat) : List UInt8 :=
  let l := cbHeightDigits n
  match l.getLast? with
  | some b => if b.toNat ≥ 0x80 then l ++ [0] else l
  | none => []

/-- The minimal single-byte push of `CScriptNum(height)` (heights < 2^31
always push via a one-byte length opcode). -/
def cbHeightPush (height : UInt32) : ByteArray :=
  let l := cbHeightBytes height.toNat
  (l.length.toUInt8 :: l).foldl (fun acc b => acc.push b) ByteArray.empty

/-- **BLK-069** (BIP34, `bad-cb-height`): when active, the coinbase
scriptSig begins with the minimal push of the height. -/
@[rule "BLK-069", rule "INV-135", rule "INV-103"]
def bip34Ok (height : UInt32) (cb : Tx) : Bool :=
  if Bitcoin.Ledger.BIP34_HEIGHT ≤ height then
    let ss := (cb.vin.getD 0 dummyTxIn).scriptSig.bytes
    bytesBEq (ss.extract 0 (cbHeightPush height).size) (cbHeightPush height)
  else true

/-- **BLK-060/061/062**: buried version gates — nVersion ≥ 2/3/4 once
BIP34/BIP66/BIP65 are active (`bad-version`). -/
@[rule "BLK-060", rule "BLK-061", rule "BLK-062", rule "INV-102"]
def versionOk (height : UInt32) (version : Int32) : Bool :=
  (Bitcoin.Ledger.BIP34_HEIGHT ≤ height → version ≥ 2)
    && (BIP66_HEIGHT ≤ height → version ≥ 3)
    && (BIP65_HEIGHT ≤ height → version ≥ 4)

/-- **BLK-027+BLK-028**: vtx[0] is the only coinbase. -/
@[rule "BLK-027", rule "BLK-028"]
def cbPositionOk (txs : List Tx) : Bool :=
  match txs with
  | [] => false
  | cb :: rest => cb.isCoinBase && !rest.any (fun t => t.isCoinBase)

/-! ## The per-tx, per-input script layer -/

/-- Witness bytes of input `i` (the per-input `CScriptWitness`). -/
def witnessAt (tx : Tx) (i : Nat) : WitnessStack := tx.witness.getD i []

/-- BIP141 scriptPubKey gate for the unjudged lane: a witness program of
version ≥ 1 (v0 stays fully adjudicated through the witness paths). -/
def isTaprootProgram (spk : ByteArray) : Bool :=
  match isWitnessProgram spk with
  | some (v, _) => 1 ≤ v
  | none => false

/-- One input's script verdict: adjudicated bool, or the unjudged lane. -/
inductive InputVerdict where
  | pass
  | fail (e : CapError)
  | unjudgedTaproot
deriving Repr, DecidableEq

/-- Script check for input `i` of `tx` spending `coin`:
`verifyScriptFull` (flags = `getBlockScriptFlags` at the block
height, policy = consensus default), checker = the REAL seam wiring
(adapter × verifier × sighash). Fuel = script+witness byte
budget (each opcode consumes ≥ 1 wire byte). A v1-witness (Taproot)
program routes to the unjudged lane BEFORE the checker can fail-closed.
SWT-068: mixed-scheme transactions — the dispatch is PER INPUT
(BASE/WITNESS_V0/TAPROOT lanes decided independently per input from the
prevout's scriptPubKey; Core's PrecomputedTransactionData::Init fills
per-input sigversion data — no shared cache in this model, each input
carries its own `ScriptExecutionData`). -/
@[rule "SWT-068"]
def verifyInput (height : UInt32) (tx : Tx) (i : Nat) (coin : Coin)
    (txIdx inputIdx : Nat) : InputVerdict :=
  if isTaprootProgram coin.scriptPubKey.bytes then InputVerdict.unjudgedTaproot
  else
    let ss := (tx.vin.getD i dummyTxIn).scriptSig.bytes
    let spk := coin.scriptPubKey.bytes
    let w := witnessAt tx i
    let wbytes := (w.map (·.size)).foldl Nat.add 0
    let fuel := ss.size + spk.size + wbytes + 10
    let flags := getBlockScriptFlags height
    let chk := realCheckerOf tx i coin.value
    match verifyScriptFull fuel flags default ss spk w chk with
    | .ok => InputVerdict.pass
    | .unjudged => InputVerdict.unjudgedTaproot
    | .fail e => InputVerdict.fail (CapError.scriptFail txIdx inputIdx e)

/-- All input script verdicts of a non-coinbase tx, against the CURRENT
UTXO view. Fails fast on the first adjudicated failure. -/
def verifyTxInputs (height : UInt32) (tx : Tx) (txIdx : Nat)
    (u : List (OutPoint × Coin)) : Except CapError (Nat × Nat) :=
  -- (adjudicated count, unjudged count)
  let rec loop : Nat → Nat → Nat → Except CapError (Nat × Nat)
    | i, okN, unjN =>
      if i ≥ tx.vin.length then .ok (okN, unjN)
      else
        let prevout := (tx.vin.getD i dummyTxIn).prevout
        match coinLookup u prevout with
        | none => .ok (okN, unjN)   -- HaveInputs reports through the ledger / transaction-validation error lane
        | some coin =>
          match verifyInput height tx i coin txIdx i with
          | .pass => loop (i+1) (okN+1) unjN
          | .unjudgedTaproot => loop (i+1) okN (unjN+1)
          | .fail e => .error e
  loop 0 0 0

/-! ## The pipeline -/

/-- The canonical transaction engine validates input amounts exactly once,
then runs caller checks before scripts and UpdateCoins. Callers can carry
checked budget metadata in α without re-running CheckTxInputs. -/
def applyTxWithChecks {α : Type} (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l : List (OutPoint × Coin)) (checks : Amount → Except CapError α) :
    Except CapError (((List (OutPoint × Coin) × Nat × Nat) × Amount) × α) := do
  match checkTransaction tx with
  | some e => throw (CapError.txCheck e)
  | none => pure ()
  let fee ← if tx.isCoinBase then pure 0 else
    match checkTxInputs tx (viewOf l) height with
    | .error e => throw (CapError.tx e)
    | .ok fee => pure fee
  let checked ← checks fee
  let (okN, unjN) ← if tx.isCoinBase then pure (0, 0)
                     else verifyTxInputs height tx txIdx l
  match applyTxStepL l tx (txidKey tx) height with
  | .error e => throw (CapError.block e)
  | .ok l' => pure (((l', okN, unjN), fee), checked)

/-- Fee-only standalone adapter of the canonical engine. -/
def applyTxWithFeeCheck (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l : List (OutPoint × Coin)) (checkFee : Amount → Except CapError Unit) :
    Except CapError ((List (OutPoint × Coin) × Nat × Nat) × Amount) := do
  let (result, _) ← applyTxWithChecks height tx txIdx l
    (fun fee => if tx.isCoinBase then .ok () else checkFee fee)
  pure result

/-- Stable fee-only equation for existing transaction/funding proofs. -/
theorem applyTxWithFeeCheck_unfold (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l : List (OutPoint × Coin)) (checkFee : Amount → Except CapError Unit) :
    applyTxWithFeeCheck height tx txIdx l checkFee = (do
  match checkTransaction tx with
  | some e => throw (CapError.txCheck e)
  | none => pure ()
  let (okN, unjN, fee) ←
    if tx.isCoinBase then pure (0, 0, 0)
    else
      match checkTxInputs tx (viewOf l) height with
      | .error e => throw (CapError.tx e)
      | .ok fee => do
          checkFee fee
          let (a, b) ← verifyTxInputs height tx txIdx l
          pure (a, b, fee)
  match applyTxStepL l tx (txidKey tx) height with
  | .error e => throw (CapError.block e)
  | .ok l' => pure ((l', okN, unjN), fee)) := by
  unfold applyTxWithFeeCheck applyTxWithChecks
  cases hc : checkTransaction tx with
  | some e => simp [hc] <;> rfl
  | none =>
    cases hb : tx.isCoinBase with
    | true => cases hs : applyTxStepL l tx (txidKey tx) height <;> simp [hc, hb, hs] <;> rfl
    | false =>
      cases hm : checkTxInputs tx (viewOf l) height with
      | error e => simp [hc, hb, hm] <;> rfl
      | ok fee =>
        cases hf : checkFee fee with
        | error e => simp [hc, hb, hm, hf] <;> rfl
        | ok unit =>
          cases hv : verifyTxInputs height tx txIdx l with
          | error e => simp [hc, hb, hm, hf, hv] <;> rfl
          | ok counts =>
            obtain ⟨x, y⟩ := counts
            cases hs : applyTxStepL l tx (txidKey tx) height <;> simp [hc, hb, hm, hf, hv, hs] <;> rfl

/-- Standalone transaction validation. Block-level fee and subsidy
budgets belong to `applyBlockTransactions`, not to this partial helper. -/
def applyTx (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l : List (OutPoint × Coin)) :
    Except CapError (List (OutPoint × Coin) × Nat × Nat) := do
  let (result, _) ← applyTxWithFeeCheck height tx txIdx l (fun _ => .ok ())
  pure result

/-- Stable equation for the standalone projection of the canonical step. -/
theorem applyTx_unfold (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l : List (OutPoint × Coin)) :
    applyTx height tx txIdx l = (do
      match checkTransaction tx with
      | some e => throw (CapError.txCheck e)
      | none => pure ()
      let (okN, unjN) ←
        if tx.isCoinBase then pure (0, 0)
        else match checkTxInputs tx (viewOf l) height with
          | .error e => throw (CapError.tx e)
          | .ok _ => verifyTxInputs height tx txIdx l
      match applyTxStepL l tx (txidKey tx) height with
      | .error e => throw (CapError.block e)
      | .ok l' => pure (l', okN, unjN)) := by
  unfold applyTx
  rw [applyTxWithFeeCheck_unfold]
  cases hc : checkTransaction tx with
  | some e => simp [Except.map] <;> rfl
  | none =>
    cases hb : tx.isCoinBase <;> simp only [hb, Bool.false_eq_true, ↓reduceIte]
    · cases hm : checkTxInputs tx (viewOf l) height with
      | error e => simp [Except.map] <;> rfl
      | ok fee =>
        cases hv : verifyTxInputs height tx txIdx l with
        | error e => simp [Except.map] <;> rfl
        | ok counts =>
          obtain ⟨a, b⟩ := counts
          cases hs : applyTxStepL l tx (txidKey tx) height <;> simp [Except.map] <;> rfl
    · cases hs : applyTxStepL l tx (txidKey tx) height <;> simp [Except.map] <;> rfl

/-- The sequential per-tx fold (tx i+1 sees the UTXO set after tx i,
B3's same-block spend ordering — `applyBlockL` order, threaded
through the script layer). Returns the final UTXO list plus the
script-layer counters. This standalone helper has no block funding
budget; `applyBlockTransactions` is the funded stage used by `validateBlock`. -/
def applyTxs (height : UInt32) :
    List Tx → Nat → List (OutPoint × Coin) → Nat → Nat →
    Except CapError (List (OutPoint × Coin) × Nat × Nat)
  | [], _, l, okN, unjN => .ok (l, okN, unjN)
  | tx :: rest, i, l, okN, unjN => do
      let (l', a, b) ← applyTx height tx i l
      applyTxs height rest (i+1) l' (okN + a) (unjN + b)

/-- Fee budget at the exact Core ConnectBlock call site: after input
validation and before scripts. -/
def checkFeeTotal (fees fee : Amount) : Except CapError Unit :=
  if MoneyRange (fees + fee) then .ok () else .error .badFeeAccum

/-- CheckBlock checks every stateless transaction before its legacy budget
and before any ConnectBlock input lookup. Standalone transaction validation
retains its own guard; neither pass performs contextual amount lookup. -/
def checkBlockStateless : List Tx → Except CapError Unit
  | [] => .ok ()
  | tx :: rest =>
    match checkTransaction tx with
    | some e => .error (.txCheck e)
    | none => checkBlockStateless rest

/-- CheckBlock's transaction loop and early legacy-only resource bound.
This precedes witness/weight checks and contextual UTXO input access. -/
def checkBlockPrelude (txs : List Tx) : Except CapError Unit := do
  checkBlockStateless txs
  if !Bitcoin.Block.Sigops.legacySigOpBudgetOk txs then throw CapError.badBlkSigops

/-- Core CheckWitnessMalleation: select the last matching output, check the
reserved-value shape before its hash, and otherwise forbid witness data.
Output amounts do not participate. This stage must precede block weight. -/
def checkWitnessCommitment (active : Bool) (txs : List Tx) (cb : Tx) :
    Except CapError Unit := do
  if active && (witnessCommitmentOutput cb).isSome then
    if !commitmentNonceOk cb then throw CapError.badWitnessNonce
    if !witnessCommitmentOk txs cb then throw CapError.badWitnessCommitment
  else
    if anyWitness txs then throw CapError.unexpectedWitness

/-- Exact accepted predicate of the ordered witness stage. -/
theorem checkWitnessCommitment_ok_iff (active : Bool) (txs : List Tx) (cb : Tx) :
    checkWitnessCommitment active txs cb = .ok () ↔ commitmentGate active txs cb = true := by
  unfold checkWitnessCommitment commitmentGate
  split
  · by_cases hn : commitmentNonceOk cb = true
    · cases hh : witnessCommitmentOk txs cb <;> simp [hn, hh, pure, Except.pure]
    · have hh : witnessCommitmentOk txs cb = false := by
        cases h : witnessCommitmentOk txs cb
        · rfl
        · exact False.elim (hn (witnessCommitmentOk_nonce h))
      simp [hn, hh, pure, Except.pure]
  · cases anyWitness txs <;> simp [pure, Except.pure]

/-- The witness stage can only emit its three Core witness verdicts. -/
theorem checkWitnessCommitment_error {active : Bool} {txs : List Tx} {cb : Tx} {e : CapError}
    (h : checkWitnessCommitment active txs cb = .error e) :
    e = .badWitnessNonce ∨ e = .badWitnessCommitment ∨ e = .unexpectedWitness := by
  unfold checkWitnessCommitment at h
  cases ha : active && (witnessCommitmentOutput cb).isSome <;>
    cases hn : commitmentNonceOk cb <;> cases hh : witnessCommitmentOk txs cb <;>
    cases hw : anyWitness txs <;> simp_all [pure, Except.pure]

theorem checkBlockStateless_error {txs : List Tx} {e : CapError}
    (h : checkBlockStateless txs = .error e) : ∃ txError, e = .txCheck txError := by
  induction txs with
  | nil => simp [checkBlockStateless] at h
  | cons tx rest ih =>
    cases hc : checkTransaction tx with
    | none => exact ih (by simpa [checkBlockStateless, hc] using h)
    | some err =>
      simp [checkBlockStateless, hc] at h
      exact ⟨err, h.symm⟩

/-- The early prelude can reject only stateless transaction errors or the
legacy sigop limit. In particular it cannot manufacture a weight verdict. -/
theorem checkBlockPrelude_error {txs : List Tx} {e : CapError}
    (h : checkBlockPrelude txs = .error e) :
    (∃ txError, e = .txCheck txError) ∨ e = .badBlkSigops := by
  unfold checkBlockPrelude at h
  cases hs : checkBlockStateless txs with
  | error err =>
    simp only [hs, Bind.bind, Except.bind, Except.error.injEq] at h
    exact Or.inl (h ▸ checkBlockStateless_error hs)
  | ok value =>
    cases value
    simp only [hs, Bind.bind, Except.bind] at h
    split at h
    · simp only [throw_except_error, Except.error.injEq] at h
      exact Or.inr h.symm
    · simp [pure, Except.pure] at h

theorem checkBlockStateless_ok {txs : List Tx}
    (h : checkBlockStateless txs = .ok ()) :
    ∀ tx ∈ txs, checkTransaction tx = none := by
  induction txs with
  | nil => simp
  | cons tx rest ih =>
    cases hc : checkTransaction tx with
    | some e => simp [checkBlockStateless, hc] at h
    | none =>
      have tail : checkBlockStateless rest = .ok () := by
        simpa [checkBlockStateless, hc] using h
      intro t ht
      rcases List.mem_cons.mp ht with rfl | ht
      · exact hc
      · exact ih tail t ht

theorem checkBlockPrelude_ok {txs : List Tx}
    (h : checkBlockPrelude txs = .ok ()) :
    checkBlockStateless txs = .ok () ∧ Bitcoin.Block.Sigops.legacySigOpBudgetOk txs = true := by
  unfold checkBlockPrelude at h
  cases hs : checkBlockStateless txs with
  | error e => simp [hs] at h
  | ok value =>
    cases value
    simp only [hs, Bind.bind, Except.bind] at h
    split at h
    · simp at h
    · simp_all

/-- Successful Unit-valued prechecks expose their continuation. -/
theorem unit_precheck_ok {α : Type} (check : Except CapError Unit)
    (next : Unit → Except CapError α) {result : α}
    (h : (check >>= next) = .ok result) :
    check = .ok () ∧ next () = .ok result := by
  cases hc : check with
  | error e => simp [hc, Bind.bind, Except.bind] at h
  | ok value =>
    cases value
    exact ⟨rfl, by simpa [hc, Bind.bind, Except.bind] using h⟩

/-- Sequential transaction fold with checked running fees. Every non-coinbase
fee comes from `checkTxInputs` against that transaction's evolving UTXO view. -/
def applyTxsWithFees (height : UInt32) :
    List Tx → Nat → List (OutPoint × Coin) → Nat → Nat → Amount →
    Except CapError ((List (OutPoint × Coin) × Nat × Nat) × Amount)
  | [], _, l, okN, unjN, fees => .ok ((l, okN, unjN), fees)
  | tx :: rest, i, l, okN, unjN, fees => do
      let ((l', a, b), fee) ← applyTxWithFeeCheck height tx i l (checkFeeTotal fees)
      applyTxsWithFees height rest (i+1) l' (okN + a) (unjN + b) (fees + fee)

/-- BLK-089: a coinbase may claim less than its budget, but never more.
The public validator already establishes a nonempty, unique coinbase. -/
def coinbaseRewardOk (cb : Tx) (fees : Amount) (height : UInt32) : Bool :=
  cb.getValueOut ≤ fees + Bitcoin.Conservation.blockSubsidy height

/-- Funded block transaction stage. All fees are checked before scripts;
the final coinbase check uses precisely the accumulated checked fees. -/
def applyBlockTransactions (height : UInt32) (txs : List Tx)
    (l : List (OutPoint × Coin)) :
    Except CapError (List (OutPoint × Coin) × Nat × Nat) := do
  let (result, fees) ← applyTxsWithFees height txs 0 l 0 0 0
  if !coinbaseRewardOk (txs.getD 0 dummyTx) fees height then throw CapError.badCbAmount
  pure result

/-- BIP68 on exactly aligned input data from the evolving view. The activation
bit is the block deployment, independent of script-local CSV execution. -/
def checkSequenceContext (ctx : Bitcoin.Capstone.Context.ChainContext)
    (facts : Bitcoin.Capstone.Context.HeaderFacts) (height : UInt32)
    (tx : Tx) (l : List (OutPoint × Coin)) : Except CapError Unit := do
  let csv := (CSV_HEIGHT ≤ height : Bool)
  if tx.isCoinBase || !Bitcoin.DataLaws.bip68Enabled tx.version csv then pure ()
  else
    let data ← match Bitcoin.Capstone.Context.sequenceInputData ctx facts.parentMtp (viewOf l) tx.vin with
      | .error e => throw (CapError.context e)
      | .ok data => pure data
    if !sequenceLocksOk tx csv data (height.toNat : Int) (facts.parentMtp.toNat : Int) then
      throw (CapError.tx .badTxnsNonfinal)

/-- ConnectBlock's fee-range check precedes BIP68, which precedes scripts. -/
def checkContextualTx (ctx : Bitcoin.Capstone.Context.ChainContext)
    (facts : Bitcoin.Capstone.Context.HeaderFacts) (height : UInt32)
    (tx : Tx) (l : List (OutPoint × Coin)) (fees fee : Amount) : Except CapError Unit := do
  if tx.isCoinBase then pure () else
    checkFeeTotal fees fee
    checkSequenceContext ctx facts height tx l

/-- Contextual transaction fold: CheckTxInputs supplies each fee once;
BIP68 reads coin heights from the same current view, including outputs
created earlier in this block. -/
def applyTxsInContext (ctx : Bitcoin.Capstone.Context.ChainContext)
    (facts : Bitcoin.Capstone.Context.HeaderFacts) (height : UInt32) :
    List Tx → Nat → List (OutPoint × Coin) → Nat → Nat → Amount →
    Except CapError ((List (OutPoint × Coin) × Nat × Nat) × Amount)
  | [], _, l, a, b, fees => .ok ((l, a, b), fees)
  | tx :: rest, i, l, a, b, fees => do
    let (((l', x, y), fee), _) ← applyTxWithChecks height tx i l
      (checkContextualTx ctx facts height tx l fees)
    applyTxsInContext ctx facts height rest (i+1) l' (a+x) (b+y) (fees+fee)

/-- Funded contextual fold. Absolute finality is the earlier block prelude;
this stage adds BIP68 at its input-dependent ConnectBlock call site. -/
def applyContextualBlockTransactions (ctx : Bitcoin.Capstone.Context.ChainContext)
    (facts : Bitcoin.Capstone.Context.HeaderFacts) (height : UInt32)
    (txs : List Tx) (l : List (OutPoint × Coin)) :
    Except CapError (List (OutPoint × Coin) × Nat × Nat) := do
  let (result, fees) ← applyTxsInContext ctx facts height txs 0 l 0 0 0
  if !coinbaseRewardOk (txs.getD 0 dummyTx) fees height then throw CapError.badCbAmount
  pure result

/-- The candidate's actual hash selects Core's script-flag exceptions.
The numeric interpretation is the same uint256 little-endian value used
by proof-of-work, rather than a height or a digest byte-order guess. -/
def candidateScriptFlags (height : UInt32) (header : Bitcoin.Chain.BlockHeader) : ScriptFlags :=
  getBlockScriptFlagsP Bitcoin.Activation.mainnetParams
    (hashNatLE (headerHash header)) height

/-- Checks preceding the ConnectBlock sigop budget. Replay omits BIP68;
the contextual entry uses exactly its resolved parent-chain facts. -/
def checkBeforeSigops (context : Option (Bitcoin.Capstone.Context.ChainContext ×
      Bitcoin.Capstone.Context.HeaderFacts)) (height : UInt32) (tx : Tx)
    (l : List (OutPoint × Coin)) (fees fee : Amount) : Except CapError Unit :=
  match context with
  | none => if tx.isCoinBase then .ok () else checkFeeTotal fees fee
  | some (ctx, facts) => checkContextualTx ctx facts height tx l fees fee

/-- Exact ConnectBlock ordering: checked input amounts (in the canonical
engine), accumulated fees, BIP68, then the running sigop total, then scripts.
Coinbase skips fees/BIP68/scripts but its legacy sigops still count. -/
def checkSigopTotal (context : Option (Bitcoin.Capstone.Context.ChainContext ×
      Bitcoin.Capstone.Context.HeaderFacts)) (height : UInt32) (flags : ScriptFlags)
    (tx : Tx) (l : List (OutPoint × Coin)) (fees fee : Amount)
    (sigops : Nat) : Except CapError Nat := do
  checkBeforeSigops context height tx l fees fee
  let total := sigops + Bitcoin.Block.Sigops.txSigOpCostWithFlags (viewOf l) tx flags
  if total > Bitcoin.Block.Sigops.MAX_BLOCK_SIGOPS_COST then throw CapError.badBlkSigops
  pure total

/-- The actual block fold. Each cost reads the same evolving view as
CheckTxInputs and BIP68, before the input coins are spent. The callback
carries the checked total without a second CheckTxInputs or script run. -/
def applyTxsWithSigops (context : Option (Bitcoin.Capstone.Context.ChainContext ×
      Bitcoin.Capstone.Context.HeaderFacts)) (height : UInt32) (flags : ScriptFlags) :
    List Tx → Nat → List (OutPoint × Coin) → Nat → Nat → Amount → Nat →
    Except CapError (((List (OutPoint × Coin) × Nat × Nat) × Amount) × Nat)
  | [], _, l, a, b, fees, sigops => .ok (((l, a, b), fees), sigops)
  | tx :: rest, i, l, a, b, fees, sigops => do
    let (((l', x, y), fee), checkedTotal) ← applyTxWithChecks height tx i l
      (fun fee => checkSigopTotal context height flags tx l fees fee sigops)
    applyTxsWithSigops context height flags rest (i+1) l' (a+x) (b+y) (fees+fee) checkedTotal

/-- Resource-checked transaction stage used by both public entries. -/
def applyBlockTransactionsWithSigops (context : Option (Bitcoin.Capstone.Context.ChainContext ×
      Bitcoin.Capstone.Context.HeaderFacts)) (height : UInt32) (flags : ScriptFlags)
    (txs : List Tx) (l : List (OutPoint × Coin)) :
    Except CapError ((List (OutPoint × Coin) × Nat × Nat) × Nat) := do
  let ((result, fees), sigops) ← applyTxsWithSigops context height flags txs 0 l 0 0 0 0
  if !coinbaseRewardOk (txs.getD 0 dummyTx) fees height then throw CapError.badCbAmount
  pure (result, sigops)

/-- Recover the exact successful caller check from the canonical engine. -/
theorem applyTxWithChecks_checks_ok {α : Type} {height : UInt32} {tx : Tx} {i : Nat}
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
        cases hs : applyTxStepL l tx (txidKey tx) height <;> simp_all [Bind.bind, Except.bind, Functor.map, Except.map, pure, Except.pure]
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
            cases hs : applyTxStepL l tx (txidKey tx) height <;> simp_all [Bind.bind, Except.bind, Functor.map, Except.map, pure, Except.pure]

/-- Replacing a successful additional check preserves the exact checked
fee, scripts, ledger transition and counters. This is a proof refinement;
the executable pipeline still runs the canonical engine only once. -/
theorem applyTxWithChecks_replace {α β : Type} {height : UInt32} {tx : Tx} {i : Nat}
    {l : List (OutPoint × Coin)} {checks : Amount → Except CapError α}
    {checks' : Amount → Except CapError β}
    {result : List (OutPoint × Coin) × Nat × Nat} {fee : Amount}
    {metadata : α} {metadata' : β}
    (h : applyTxWithChecks height tx i l checks = .ok ((result, fee), metadata))
    (hc' : checks' fee = .ok metadata') :
    applyTxWithChecks height tx i l checks' = .ok ((result, fee), metadata') := by
  unfold applyTxWithChecks at h ⊢
  cases hc : checkTransaction tx with
  | some e => simp [hc] at h
  | none =>
    cases hb : tx.isCoinBase with
    | true =>
      cases hf : checks 0 with
      | error e => simp [hc, hb, hf] at h
      | ok value =>
        cases hs : applyTxStepL l tx (txidKey tx) height <;>
          simp_all [Bind.bind, Except.bind, Functor.map, Except.map, pure, Except.pure]
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
            cases hs : applyTxStepL l tx (txidKey tx) height <;>
              simp_all [Bind.bind, Except.bind, Functor.map, Except.map, pure, Except.pure]

/-- Successful sigop checking includes the earlier fee/sequence checks
and the exact running sum, with the inclusive 80,000-unit bound. -/
theorem checkSigopTotal_ok {context height flags tx l fees fee sigops total}
    (h : checkSigopTotal context height flags tx l fees fee sigops = .ok total) :
    checkBeforeSigops context height tx l fees fee = .ok () ∧
    total = sigops + Bitcoin.Block.Sigops.txSigOpCostWithFlags (viewOf l) tx flags ∧
    total ≤ Bitcoin.Block.Sigops.MAX_BLOCK_SIGOPS_COST := by
  unfold checkSigopTotal at h
  cases hc : checkBeforeSigops context height tx l fees fee with
  | error e => simp [hc] at h
  | ok unit =>
    cases unit
    simp only [hc, Bind.bind, Except.bind] at h
    split at h
    · simp at h
    · simp only [pure, Except.pure, Except.ok.injEq] at h
      simp_all

/-- Forgetting the resource budget recovers the exact earlier fee/BIP68
fold, not a second execution or an assumption about the returned state. -/
theorem applyTxsWithSigops_projection {context height flags txs i l a b fees sigops}
    {result : List (OutPoint × Coin) × Nat × Nat} {totalFees : Amount} {totalSigops : Nat}
    (h : applyTxsWithSigops context height flags txs i l a b fees sigops =
      .ok ((result, totalFees), totalSigops)) :
    (match context with
     | none => applyTxsWithFees height txs i l a b fees
     | some (ctx, facts) => applyTxsInContext ctx facts height txs i l a b fees) =
      .ok (result, totalFees) := by
  induction txs generalizing i l a b fees sigops with
  | nil =>
    simp only [applyTxsWithSigops, Except.ok.injEq, Prod.mk.injEq] at h
    rcases h with ⟨⟨hr, hf⟩, _⟩
    cases context <;> simp_all [applyTxsWithFees, applyTxsInContext]
  | cons tx rest ih =>
    simp only [applyTxsWithSigops] at h
    cases hs : applyTxWithChecks height tx i l
        (fun fee => checkSigopTotal context height flags tx l fees fee sigops) with
    | error e => simp [hs] at h
    | ok value =>
      obtain ⟨⟨⟨l', x, y⟩, checkedFee⟩, nextTotal⟩ := value
      simp only [hs, Bind.bind, Except.bind] at h
      have checked := (checkSigopTotal_ok (applyTxWithChecks_checks_ok hs)).1
      have step := applyTxWithChecks_replace hs checked
      have tail := ih h
      cases context with
      | none =>
        have feeStep : applyTxWithFeeCheck height tx i l (checkFeeTotal fees) =
            .ok ((l', x, y), checkedFee) := by
          unfold applyTxWithFeeCheck
          change (do
            let (r, _) ← applyTxWithChecks height tx i l
              (checkBeforeSigops none height tx l fees)
            pure r) = _
          rw [step]
          rfl
        simpa [applyTxsWithFees, feeStep] using tail
      | some pair =>
        obtain ⟨ctx, facts⟩ := pair
        change applyTxWithChecks height tx i l
          (checkContextualTx ctx facts height tx l fees) =
            .ok (((l', x, y), checkedFee), ()) at step
        simpa [applyTxsInContext, step] using tail

/-- Public resource-stage success preserves the exact previously proved
funding/sequence stage, so those contracts survive the stronger validator. -/
theorem applyBlockTransactionsWithSigops_projection {context height flags txs l result sigops}
    (h : applyBlockTransactionsWithSigops context height flags txs l = .ok (result, sigops)) :
    (match context with
     | none => applyBlockTransactions height txs l
     | some (ctx, facts) => applyContextualBlockTransactions ctx facts height txs l) = .ok result := by
  unfold applyBlockTransactionsWithSigops at h
  cases hf : applyTxsWithSigops context height flags txs 0 l 0 0 0 0 with
  | error e => simp [hf] at h
  | ok value =>
    obtain ⟨⟨r, fees⟩, total⟩ := value
    simp only [hf, Bind.bind, Except.bind] at h
    split at h
    · simp at h
    · simp only [pure, Except.pure, Except.ok.injEq, Prod.mk.injEq] at h
      rcases h with ⟨hr, ht⟩
      have projected := applyTxsWithSigops_projection hf
      cases context <;>
        simp_all [applyBlockTransactions, applyContextualBlockTransactions,
          Bind.bind, Except.bind, pure, Except.pure]

/-- A successful budgeted step refines standalone transaction validation. -/
theorem applyTxWithFeeCheck_ok {height : UInt32} {tx : Tx} {i : Nat}
    {l : List (OutPoint × Coin)} {checkFee : Amount → Except CapError Unit}
    {result : List (OutPoint × Coin) × Nat × Nat} {fee : Amount}
    (h : applyTxWithFeeCheck height tx i l checkFee = .ok (result, fee)) :
    applyTx height tx i l = .ok result := by
  rw [applyTx_unfold]
  rw [applyTxWithFeeCheck_unfold] at h
  cases hc : checkTransaction tx with
  | some e => simp [hc] at h
  | none =>
    cases hb : tx.isCoinBase with
    | true =>
      cases hs : applyTxStepL l tx (txidKey tx) height <;>
        simp_all [Bind.bind, Except.bind, Functor.map, Except.map, pure, Except.pure]
    | false =>
      cases hm : checkTxInputs tx (viewOf l) height with
      | error e => simp [hc, hb, hm] at h
      | ok checkedFee =>
        cases hf : checkFee checkedFee with
        | error e => simp [hc, hb, hm, hf] at h
        | ok unit =>
          cases hv : verifyTxInputs height tx i l with
          | error e => simp [hc, hb, hm, hf, hv] at h
          | ok counts =>
            obtain ⟨a, b⟩ := counts
            cases hs : applyTxStepL l tx (txidKey tx) height <;>
              simp_all [Bind.bind, Except.bind, Functor.map, Except.map, pure, Except.pure]

/-- The funded fold preserves the standalone fold's UTXO and counters. -/
theorem applyTxsWithFees_ok {height : UInt32} {txs : List Tx} {i : Nat}
    {l : List (OutPoint × Coin)} {a b : Nat} {fees total : Amount}
    {result : List (OutPoint × Coin) × Nat × Nat}
    (h : applyTxsWithFees height txs i l a b fees = .ok (result, total)) :
    applyTxs height txs i l a b = .ok result := by
  induction txs generalizing i l a b fees with
  | nil =>
    simp only [applyTxsWithFees, Except.ok.injEq, Prod.mk.injEq] at h
    simpa [applyTxs] using congrArg (Except.ok (ε := CapError)) h.1
  | cons tx rest ih =>
    simp only [applyTxsWithFees] at h
    cases hs : applyTxWithFeeCheck height tx i l (checkFeeTotal fees) with
    | error e => simp [hs] at h
    | ok p =>
      obtain ⟨⟨l', x, y⟩, fee⟩ := p
      simp only [hs, Bind.bind, Except.bind] at h
      have step := applyTxWithFeeCheck_ok hs
      simpa [applyTxs, step] using ih h

/-- The public funding stage refines the previously exposed partial fold. -/
theorem applyBlockTransactions_ok {height : UInt32} {txs : List Tx}
    {l : List (OutPoint × Coin)} {result : List (OutPoint × Coin) × Nat × Nat}
    (h : applyBlockTransactions height txs l = .ok result) :
    applyTxs height txs 0 l 0 0 = .ok result := by
  unfold applyBlockTransactions at h
  cases hf : applyTxsWithFees height txs 0 l 0 0 0 with
  | error e => simp [hf] at h
  | ok p =>
    obtain ⟨r, fees⟩ := p
    simp only [hf, Bind.bind, Except.bind] at h
    split at h
    · simp at h
    · simp only [pure, Except.pure, Except.ok.injEq] at h
      subst r
      exact applyTxsWithFees_ok hf

/-- Run report: the new state plus the honest per-layer counters. -/
structure CapReport where
  state : CapState
  txs : Nat
  scriptOk : Nat          -- inputs adjudicated PASS (real ECDSA + the interpreter layer + the sig-hash layer)
  scriptUnjudged : Nat    -- inputs on the Taproot unjudged lane
  headerContextChecked : Bool := false -- expected nBits, parent MTP, node-clock bound
  absoluteFinalityChecked : Bool := false
  sequenceLocksChecked : Bool := false
  sigOpBudgetChecked : Bool := false
  sigOpCost : Nat := 0
  deriving Repr

/-- **THE PIPELINE** (S2b): `SerializedBlock → ChainState → Except Err
ChainState`, composed of decode → structure checks → header PoW +
chain link → merkle + witness commitment → per-tx validation →
fold. -/
@[rule "BLK-030", rule "BLK-102"]
def validateBlock (raw : ByteArray) (st : CapState)
    (context : Option Bitcoin.Capstone.Context.ChainContext := none) :
    Except CapError CapReport := do
  -- 1. Decode.
  let (h, txs) ← match decodeBlock raw with
    | .error e => throw (CapError.ser e)
    | .ok p => pure p
  -- 2. Structure (BLK rows).
  if !vtxNonempty txs then throw CapError.emptyBlock
  if !cbPositionOk txs then throw CapError.badCbPosition
  if !cbLengthOk (txs.getD 0 dummyTx) then throw CapError.badCbLength
  -- 3. Header: PoW + chain link.
  -- BLK-037/038: targetOk is the full `SetCompact` gate — fNegative,
  -- fOverflow, target ≠ 0, target ≤ powLimit (pow.cpp:146-159 @cce32b168).
  if !targetOk h.bits then throw CapError.badPow
  if !powOk h then throw CapError.badPow
  if !bytesBEq h.hashPrevBlock st.prevHash then throw CapError.badChainLink
  -- Missing header history is an unavailable-context error, never an assumed pass.
  let resolved ← match context with
    | none => pure none
    | some ctx =>
      match Bitcoin.Capstone.Context.checkHeaderContext ctx st.height st.prevHash h with
      | .error e => throw (CapError.context e)
      | .ok facts => pure (some (ctx, facts))
  -- 3b. Contextual gates: buried version gates (BLK-060/061/062) and
  -- BIP34 coinbase height push (BLK-069) — Core ContextualCheck order.
  if !versionOk st.height h.version then throw CapError.badVersion
  match resolved with
  | none => pure ()
  | some (_, facts) =>
    if !Bitcoin.Capstone.Context.blockFinalityAtHeight txs st.height facts.parentMtp h.time then
      throw (CapError.tx .badTxnsNonfinal)
  if !bip34Ok st.height (txs.getD 0 dummyTx) then throw CapError.badCbHeight
  -- 4. Merkle root (BLK-010), then the CVE-2012-2459 mutation scan
  -- (BLK-011) at the same CheckMerkleRoot call site. A mutated tree is
  -- `BLOCK_MUTATED` / `bad-txns-duplicate`, distinct from the root
  -- mismatch's `bad-txnmrklroot` and not cached permanently invalid
  -- (BLK-012).
  if !merkleOk h txs then throw CapError.badMerkleRoot
  if !merkleMutationOk txs then throw CapError.blockMutated
  -- CheckBlock's stateless loop precedes its early legacy-only sigop gate.
  -- ConnectBlock later adds the input-dependent P2SH/witness terms.
  checkBlockPrelude txs
  let cb := txs.getD 0 dummyTx
  -- Core's `expect_witness_commitment` = DeploymentActiveAfter(pindexPrev,
  -- DEPLOYMENT_SEGWIT): pprev->nHeight + 1 ≥ SegwitHeight, i.e. the
  -- block's own height ≥ 481824 (validation.cpp:4177). Before activation
  -- CheckWitnessMalleation is a no-op apart from the no-witness rule.
  let segwitActive := SEGWIT_HEIGHT ≤ st.height
  checkWitnessCommitment segwitActive txs cb
  -- 4b. BLK-021: the witness commitment (reserved shape, then hash) is
  -- checked BEFORE the block weight. Core's ContextualCheckBlock comment
  -- (validation.cpp:4179-4187) is explicit: a too-big-by-witness block
  -- must not be cached invalid before the coinbase witness binds the
  -- tree, since filling the reserved witness does not change the hash.
  if !weightOk txs raw.size then throw CapError.badBlkWeight
  -- 4c. BIP30 duplicate-coinbase gate (BLK-096/097/098, TXV-063).
  -- Core ConnectBlock validation.cpp:2401/2466-2475 runs ONE pre-block
  -- overlap loop on the PRISTINE view, before the per-tx script/ledger
  -- fold: if enforcement is on and some tx output recreates a live
  -- outpoint, the block fails `bad-txns-BIP30`. `applyBlockL` already has
  -- this gate; the pipeline must not bypass it.
  if bip30BlockCollision (viewOf st.utxo) txidKey txs st.height
        && bip30Enforced st.height then
    throw (CapError.block BlockError.badTxnsBIP30)
  -- 5. Per-tx checks, running fees and ledger updates; then coinbase reward.
  let ((utxo', okN, unjN), sigops) ← applyBlockTransactionsWithSigops resolved st.height
    (candidateScriptFlags st.height h) txs st.utxo
  pure { state := { st with height := st.height + 1, prevHash := headerHash h, utxo := utxo' }
         txs := txs.length, scriptOk := okN, scriptUnjudged := unjN
         headerContextChecked := context.isSome
         absoluteFinalityChecked := context.isSome, sequenceLocksChecked := context.isSome
         sigOpBudgetChecked := true, sigOpCost := sigops }

/-- Explicit partial anchor-replay adapter. No ancestor/clock checks are
claimed; script adjudication may also be incomplete as the report records. -/
def replayBlock (raw : ByteArray) (st : CapState) : Except CapError CapReport :=
  validateBlock raw st none

/-- Header-context entry point. Checks expected nBits, parent MTP and node
time, absolute finality and both BIP68 domains as well as the funded replay
gates and both sigop budgets. Witness adjudication, height-based script
flag selection and other historical-exception work remain open; success
is not yet a full consensus-validation claim. -/
def validateBlockInContext (raw : ByteArray) (st : CapState)
    (ctx : Bitcoin.Capstone.Context.ChainContext) : Except CapError CapReport :=
  validateBlock raw st (some ctx)

/-! ## BLK-010 — the merkle gate rejects a mismatched header root

The accept lane is `BitcoinProofs.AF.PDW12.merkleOk_of_eq`; this theorem
is the pipeline-side reject lane the audit asked for: when every gate
BEFORE the merkle check passes and `merkleOk` is false, `validateBlock`
returns exactly `CapError.badMerkleRoot` (Core `bad-txnmrklroot`,
validation.cpp:3848-3852). The hypotheses are the earlier gates in
pipeline order, so no other branch can pre-empt the merkle verdict. -/
@[rule "BLK-010"]
theorem validateBlock_badMerkleRoot
    (raw : ByteArray) (st : CapState) (h : Bitcoin.Chain.BlockHeader) (txs : List Tx)
    (hdec : decodeBlock raw = .ok (h, txs))
    (hstruct : vtxNonempty txs = true)
    (hcbpos : cbPositionOk txs = true)
    (hcblen : cbLengthOk (txs.getD 0 dummyTx) = true)
    (hweight : weightOk txs raw.size = true)
    (hver : versionOk st.height h.version = true)
    (hbip34 : bip34Ok st.height (txs.getD 0 dummyTx) = true)
    (htarget : targetOk h.bits = true)
    (hpow : powOk h = true)
    (hlink : bytesBEq h.hashPrevBlock st.prevHash = true)
    (hmerkle : merkleOk h txs = false) :
    validateBlock raw st = .error CapError.badMerkleRoot := by
  unfold validateBlock
  have hcblen' : cbLengthOk (txs[0]?.getD dummyTx) = true := by simpa using hcblen
  have hbip34' : bip34Ok st.height (txs[0]?.getD dummyTx) = true := by simpa using hbip34
  simp [hdec, hstruct, hcbpos, hcblen', hweight, hver, hbip34', htarget, hpow, hlink, hmerkle]

/-! ## BLK-011 — the mutation gate rejects a duplicated merkle level

The pipeline now runs `merkleMutationOk` immediately after `merkleOk`,
the same place Core's `CheckMerkleRoot` sets its `mutated` flag. The
detector is `Bitcoin.Block.Connect.merkleMutationFree` (cited, not
edited); `BitcoinProofs.AF.PDW12.merkleMutationFreeCap_eq` identifies
the import-cycle bridge with it. The reject bucket is `blockMutated`
(`bad-txns-duplicate`, `BLOCK_MUTATED`) — distinct from BLK-010's
`badMerkleRoot` and, per BLK-012, not a permanently-invalid cache write. -/

/-- **BLK-011**: when every earlier gate passes and the mutation gate is
false, `validateBlock` returns exactly `CapError.blockMutated`. -/
@[rule "BLK-011"]
theorem validateBlock_badMutated
    (raw : ByteArray) (st : CapState) (h : Bitcoin.Chain.BlockHeader) (txs : List Tx)
    (hdec : decodeBlock raw = .ok (h, txs))
    (hstruct : vtxNonempty txs = true)
    (hcbpos : cbPositionOk txs = true)
    (hcblen : cbLengthOk (txs.getD 0 dummyTx) = true)
    (hver : versionOk st.height h.version = true)
    (hbip34 : bip34Ok st.height (txs.getD 0 dummyTx) = true)
    (htarget : targetOk h.bits = true)
    (hpow : powOk h = true)
    (hlink : bytesBEq h.hashPrevBlock st.prevHash = true)
    (hmerkle : merkleOk h txs = true)
    (hmut : merkleMutationOk txs = false) :
    validateBlock raw st = .error CapError.blockMutated := by
  unfold validateBlock
  have hcblen' : cbLengthOk (txs[0]?.getD dummyTx) = true := by simpa using hcblen
  have hbip34' : bip34Ok st.height (txs[0]?.getD dummyTx) = true := by simpa using hbip34
  simp [hdec, hstruct, hcbpos, hcblen', hver, hbip34', htarget, hpow, hlink, hmerkle, hmut]

/-! ## BLK-021 — the commitment gate precedes the weight gate

Core's `ContextualCheckBlock` runs `CheckWitnessMalleation` (coinbase
reserved witness + commitment binding) first, then the
`GetBlockWeight > MAX_BLOCK_WEIGHT` check (validation.cpp:4179-4187;
the source comment gives the hash-invariance reason). The real
`validateBlock` prelude now follows that order. These theorems are on
the actual pipeline, not on the `contextualChecksOrdered` helper. -/

/-- **BLK-021 (pre-emption)**: at the real prelude, a commitment-gate
failure pre-empts weight after CheckBlock succeeds. The ordered witness stage
selects its precise nonce/hash/no-commitment verdict. The exact equation
also propagates CheckBlock's earlier stateless/legacy-budget rejection,
without assuming those checks succeeded. -/
@[rule "BLK-021"]
theorem validateBlock_commitment_preempts_weight
    (raw : ByteArray) (st : CapState) (h : Bitcoin.Chain.BlockHeader) (txs : List Tx)
    (hdec : decodeBlock raw = .ok (h, txs))
    (hstruct : vtxNonempty txs = true)
    (hcbpos : cbPositionOk txs = true)
    (hcblen : cbLengthOk (txs.getD 0 dummyTx) = true)
    (hver : versionOk st.height h.version = true)
    (hbip34 : bip34Ok st.height (txs.getD 0 dummyTx) = true)
    (htarget : targetOk h.bits = true)
    (hpow : powOk h = true)
    (hlink : bytesBEq h.hashPrevBlock st.prevHash = true)
    (hmerkle : merkleOk h txs = true)
    (hmut : merkleMutationOk txs = true)
    (hcg : commitmentGate (SEGWIT_HEIGHT ≤ st.height) txs
             (txs.getD 0 dummyTx) = false)
    (hweight : weightOk txs raw.size = false) :
    validateBlock raw st = (do
      checkBlockPrelude txs
      checkWitnessCommitment (SEGWIT_HEIGHT ≤ st.height) txs (txs.getD 0 dummyTx)
      throw CapError.badBlkWeight) := by
  have hcblen' : cbLengthOk (txs[0]?.getD dummyTx) = true := by simpa using hcblen
  have hbip34' : bip34Ok st.height (txs[0]?.getD dummyTx) = true := by simpa using hbip34
  unfold validateBlock
  simp [hdec, hstruct, hcbpos, hcblen', hver, hbip34', htarget, hpow, hlink,
    hmerkle, hmut, hweight, throw_except_error]

/-- **BLK-021 (weight reached only after commitment)**: once the
commitment gate passes, a failed weight check
returns `badBlkWeight` after CheckBlock, whose errors propagate first.
Together with the pre-emption theorem
this pins the real prelude's order. -/
@[rule "BLK-021"]
theorem validateBlock_badBlkWeight_after_commitment
    (raw : ByteArray) (st : CapState) (h : Bitcoin.Chain.BlockHeader) (txs : List Tx)
    (hdec : decodeBlock raw = .ok (h, txs))
    (hstruct : vtxNonempty txs = true)
    (hcbpos : cbPositionOk txs = true)
    (hcblen : cbLengthOk (txs.getD 0 dummyTx) = true)
    (hver : versionOk st.height h.version = true)
    (hbip34 : bip34Ok st.height (txs.getD 0 dummyTx) = true)
    (htarget : targetOk h.bits = true)
    (hpow : powOk h = true)
    (hlink : bytesBEq h.hashPrevBlock st.prevHash = true)
    (hmerkle : merkleOk h txs = true)
    (hmut : merkleMutationOk txs = true)
    (hcg : commitmentGate (SEGWIT_HEIGHT ≤ st.height) txs
             (txs.getD 0 dummyTx) = true)
    (hweight : weightOk txs raw.size = false) :
    validateBlock raw st = (do
      checkBlockPrelude txs
      throw CapError.badBlkWeight) := by
  have witnessOk := (checkWitnessCommitment_ok_iff (SEGWIT_HEIGHT ≤ st.height)
    txs (txs.getD 0 dummyTx)).2 hcg
  have hcblen' : cbLengthOk (txs[0]?.getD dummyTx) = true := by simpa using hcblen
  have hbip34' : bip34Ok st.height (txs[0]?.getD dummyTx) = true := by simpa using hbip34
  have witnessOk' : checkWitnessCommitment (SEGWIT_HEIGHT ≤ st.height) txs
      (txs[0]?.getD dummyTx) = .ok () := by simpa using witnessOk
  unfold validateBlock
  simp [hdec, hstruct, hcbpos, hcblen', hver, hbip34', htarget, hpow, hlink,
    hmerkle, hmut, witnessOk', hweight, throw_except_error]

/-! ## BIP30 — the pre-block duplicate-coinbase gate

Core `ConnectBlock` (validation.cpp:2401/2466-2475) runs the overlap loop
once on the pristine view, before the per-tx script/ledger fold. The
pipeline now performs the same check (`bip30BlockCollision` gated by
`bip30Enforced`), so a block that recreates a live outpoint is rejected
with `bad-txns-BIP30` instead of being admitted by `applyTxs`. -/

/-- **BIP30 (pipeline face)**: when every earlier gate passes, BIP30 is
enforced, and some tx output recreates an outpoint live in the pristine
pre-block view, the exact equation returns `badTxnsBIP30` after
CheckBlock, propagating any earlier stateless/legacy-budget error. -/
@[rule "BLK-096", rule "BLK-097", rule "BLK-098", rule "INV-104"]
theorem validateBlock_badBip30
    (raw : ByteArray) (st : CapState) (h : Bitcoin.Chain.BlockHeader) (txs : List Tx)
    (hdec : decodeBlock raw = .ok (h, txs))
    (hstruct : vtxNonempty txs = true)
    (hcbpos : cbPositionOk txs = true)
    (hcblen : cbLengthOk (txs.getD 0 dummyTx) = true)
    (hver : versionOk st.height h.version = true)
    (hbip34 : bip34Ok st.height (txs.getD 0 dummyTx) = true)
    (htarget : targetOk h.bits = true)
    (hpow : powOk h = true)
    (hlink : bytesBEq h.hashPrevBlock st.prevHash = true)
    (hmerkle : merkleOk h txs = true)
    (hmut : merkleMutationOk txs = true)
    (hcg : commitmentGate (SEGWIT_HEIGHT ≤ st.height) txs
             (txs.getD 0 dummyTx) = true)
    (hweight : weightOk txs raw.size = true)
    (hcol : bip30BlockCollision (viewOf st.utxo) txidKey txs st.height = true)
    (henf : bip30Enforced st.height = true) :
    validateBlock raw st = (do
      checkBlockPrelude txs
      throw (CapError.block BlockError.badTxnsBIP30)) := by
  have witnessOk := (checkWitnessCommitment_ok_iff (SEGWIT_HEIGHT ≤ st.height)
    txs (txs.getD 0 dummyTx)).2 hcg
  have hcblen' : cbLengthOk (txs[0]?.getD dummyTx) = true := by simpa using hcblen
  have hbip34' : bip34Ok st.height (txs[0]?.getD dummyTx) = true := by simpa using hbip34
  have witnessOk' : checkWitnessCommitment (SEGWIT_HEIGHT ≤ st.height) txs
      (txs[0]?.getD dummyTx) = .ok () := by simpa using witnessOk
  unfold validateBlock
  simp [hdec, hstruct, hcbpos, hcblen', hver, hbip34', htarget, hpow, hlink,
    hmerkle, hmut, witnessOk', hweight, hcol, henf, throw_except_error]

end Bitcoin.Capstone.Block
