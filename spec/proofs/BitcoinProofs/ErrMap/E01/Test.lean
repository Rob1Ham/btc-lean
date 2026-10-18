import Bitcoin.Data.Basic
import Bitcoin.Data.Tx
import Bitcoin.Ledger.Interface
import Bitcoin.Capstone.Block

/-!
# BitcoinProofs.ErrMap.E01.Test — error-taxonomy completeness (E01)

Core-side scope (pin `cce32b168`, DECISIONS.md D-001): the "Result" enums
consumed by consensus validation live in `src/consensus/validation.h`
(NOT `src/consensus.h`, which holds only constants — specification imprecision
F-E01-001):

* `TxValidationResult` — 13 values, `TX_RESULT_UNSET` .. `TX_UNKNOWN`
* `BlockValidationResult` — 9 values, `BLOCK_RESULT_UNSET` .. `BLOCK_HEADER_LOW_WORK`

Our side: `TxCheckError` (9, `Bitcoin.Consensus.TxCheck`), `TxError`
(8 + `stateless`, `Bitcoin.TxValidation.Interface`), `BlockError`
(4, `Bitcoin.Ledger.Interface`), `CapError` (header/merkle layer,
`Bitcoin.Capstone.Block`).

This file pins, per enum value: the exact Core reject string, and one
decisive reject vector driving the real validators. Full mapping table
(with no-row justifications for the mempool/policy-only values) is recorded here.
-/

namespace BitcoinProofs.ErrMap.E01

open Bitcoin.Data Bitcoin.Consensus Bitcoin.Ledger Bitcoin.TxValidation
open Bitcoin.Capstone.Block

/-- Lean 4.34 core ships no `DecidableEq (Except α β)` (see
`Test/Serialization/Tests.lean` for the same local patch); the vectors
below decide on `Except` equalities, so provide it locally. -/
instance instDecEqExcept {α β : Type} [DecidableEq α] [DecidableEq β] :
    DecidableEq (Except α β)
  | .error e, .error e' =>
      match decEq e e' with
      | isTrue h => isTrue (by rw [h])
      | isFalse h => isFalse (by intro h2; exact h (Except.error.inj h2))
  | .ok a, .ok b =>
      match decEq a b with
      | isTrue h => isTrue (by rw [h])
      | isFalse h => isFalse (by intro h2; exact h (Except.ok.inj h2))
  | .error _, .ok _  => isFalse (by intro h; cases h)
  | .ok _, .error _  => isFalse (by intro h; cases h)

/-! ## Fixtures -/

/-- A non-null 32-byte outpoint (`n = 0` ⇒ `isNull = false`). -/
def P : OutPoint := ⟨zeroBytes 32, 0⟩

/-- A spendable 5000-sat coin created at height `h`. -/
def coinAt (h : UInt32) : Coin := ⟨5000, h, false, Script.empty⟩

/-- One-input, one-output spend of `P`, paying 1000. -/
def spendTx : Tx :=
  ⟨(1 : Int32), [⟨P, Script.empty, 0xFFFFFFFF⟩], [⟨1000, Script.empty⟩], 0, []⟩

/-- The same spend with a too-large locktime and a non-final sequence
(TXV-030: all-`SEQUENCE_FINAL` inputs are final regardless of locktime,
so the locktime arm needs sequence ≠ `SEQUENCE_FINAL`). -/
def lateTx : Tx :=
  ⟨(1 : Int32), [⟨P, Script.empty, 0⟩], [⟨1000, Script.empty⟩], 500, []⟩

/-- A minimal coinbase (null prevout, single input). -/
def cbTx : Tx :=
  ⟨(1 : Int32), [⟨OutPoint.null, Script.empty, 0xFFFFFFFF⟩], [⟨0, Script.empty⟩], 0, []⟩

/-! ## 1. Reject-string pins — every `TxError`/`TxCheckError` value

Each pin is the (a)-side of the mission: constructor ↔ exact Core
reject string (`consensus/tx_check.cpp:19–68`, `tx_verify.cpp`,
`validation.cpp`). -/

example : txCheckReason .vinEmpty            = "bad-txns-vin-empty" := rfl
example : txCheckReason .voutEmpty           = "bad-txns-vout-empty" := rfl
example : txCheckReason .oversize            = "bad-txns-oversize" := rfl
example : txCheckReason .voutNegative        = "bad-txns-vout-negative" := rfl
example : txCheckReason .voutTooLarge        = "bad-txns-vout-toolarge" := rfl
example : txCheckReason .txoutTotalTooLarge  = "bad-txns-txouttotal-toolarge" := rfl
example : txCheckReason .inputsDuplicate     = "bad-txns-inputs-duplicate" := rfl
example : txCheckReason .cbLength            = "bad-cb-length" := rfl
example : txCheckReason .prevoutNull         = "bad-txns-prevout-null" := rfl

example : rejectReason (.stateless .vinEmpty) = "bad-txns-vin-empty" := rfl
example : rejectReason .badTxnsInputsMissingOrSpent = "bad-txns-inputs-missingorspent" := rfl
example : rejectReason .badTxnsInBelowout     = "bad-txns-in-belowout" := rfl
example : rejectReason .badTxnsFeeOutOfRange  = "bad-txns-fee-outofrange" := rfl
example : rejectReason .badTxnsInputvaluesOutOfRange = "bad-txns-inputvalues-outofrange" := rfl
example : rejectReason .badTxnsNonfinal       = "bad-txns-nonfinal" := rfl
example : rejectReason .badTxnsPrematureSpendOfCoinbase = "bad-txns-premature-spend-of-coinbase" := rfl
example : rejectReason .badTxnsNonstandardSequence = "non-BIP68-final" := rfl

/-! ## 2. Decisive reject vectors (tx level, `validateTx`/`checkTxInputs`)

Vector EV-1 — `TX_CONSENSUS` (stateless prefix): empty vin rejects
with the exact stateless reason. -/

example : checkTransaction ⟨(1 : Int32), [], [⟨0, Script.empty⟩], 0, []⟩
    = some TxCheckError.vinEmpty := by decide
example : validateTx ⟨(1 : Int32), [], [⟨0, Script.empty⟩], 0, []⟩ (fun _ => none) 400 400 {}
    = .error (TxError.stateless .vinEmpty) := by decide

/-- Vector EV-2 — `TX_MISSING_INPUTS`: prevout absent from the view. -/
example : checkTxInputs spendTx (fun _ => none) 1100
    = .error .badTxnsInputsMissingOrSpent := by decide

/-- Vector EV-3 — `TX_PREMATURE_SPEND` (coinbase maturity): depth 99
rejects, depth 100 succeeds (TXV-070 boundary through the real
`checkTxInputs` path). -/

example : checkTxInputs spendTx (fun o => if o == P then some ⟨5000, 1000, true, Script.empty⟩ else none) 1099
    = .error .badTxnsPrematureSpendOfCoinbase := by decide
example : checkTxInputs spendTx (fun o => if o == P then some ⟨5000, 1000, true, Script.empty⟩ else none) 1100
    = .ok 4000 := by decide

/-- Vector EV-4 — `TX_CONSENSUS` (`bad-txns-in-belowout`): valueIn 500
< valueOut 1000. -/

example : checkTxInputs spendTx (fun o => if o == P then some ⟨500, 0, false, Script.empty⟩ else none) 0
    = .error .badTxnsInBelowout := by decide

/-- Vector EV-5 — `TX_PREMATURE_SPEND` (locktime arm): `nLockTime = 500`
is nonfinal at height/MTP 400 (TXV-029/031/032). -/

example : validateTx lateTx (fun _ => none) 400 400 {}
    = .error .badTxnsNonfinal := by decide

/-! ## 3. Decisive reject vectors (block level, `applyTxStepU`/`cbPositionOk`)

Vector EV-6 — `BLOCK_CONSENSUS` wrapping, reason preserved: a
non-coinbase tx with a missing input fails the block fold with
`BlockError.txError` (validation.cpp:2545–2549 shape). -/

example : (applyTxStepU (fun _ => none) spendTx (fun _ _ => P) 1100).map (fun _ => 0)
    = .error (BlockError.txError .badTxnsInputsMissingOrSpent) := by decide

/-- Vector EV-7 — `BLOCK_CONSENSUS` (`bad-txns-BIP30`), post-D4c-2
(F-TXVB-014) shape: Core 2466-2475 runs the duplicate-coinbase check
ONCE pre-block on the pristine view — a coinbase whose output key
already sits in the view at a BIP30-enforced height is rejected by
`applyBlockU`'s pre-loop gate, not per-tx. -/

example : (applyBlockU (fun _ => some ⟨0, 99, false, Script.empty⟩)
    (fun _ _ _ => OutPoint.null) [cbTx] 100).map (fun _ => 0)
    = .error BlockError.badTxnsBIP30 := by decide

/-- Post-D4c-2 control (Core 2466-2475 = ONCE pre-block):
`applyTxStepU` is BIP30-free — even against a colliding view the
per-tx step itself connects. -/
example : (applyTxStepU (fun _ => some ⟨0, 99, false, Script.empty⟩) cbTx
    (fun _ _ => OutPoint.null) 100).isOk := by decide

/-- Negative control for EV-7: empty view connects cleanly (no
collision → the block gate stays open). -/
example : (applyBlockU (fun _ => none) (fun _ _ _ => OutPoint.null)
    [cbTx] 100).isOk := by decide

/-- Vector EV-8 — `bad-cb-missing` / `bad-cb-multiple` shapes
(BLK-027/028): `vtx[0]` must be the only coinbase. -/

example : cbPositionOk [] = false := by decide
example : cbPositionOk [spendTx, cbTx] = false := by decide
example : cbPositionOk [cbTx, cbTx] = false := by decide
example : cbPositionOk [cbTx, spendTx] = true := by decide

/-! ## 4. Block-header layer pins (`CapError.reason`, exact Core strings) -/

example : CapError.reason (.block .badTxnsBIP30) = "bad-txns-BIP30" := rfl
example : CapError.reason (.block .badCbMissing)  = "bad-cb-missing" := rfl
example : CapError.reason (.block .badCbMultiple) = "bad-cb-multiple" := rfl
example : CapError.reason .badPow        = "high-hash" := rfl
example : CapError.reason .badChainLink  = "bad-prevblk" := rfl
example : CapError.reason .badMerkleRoot = "bad-txnmrklroot" := rfl
example : CapError.reason .badBlkWeight  = "bad-blk-weight" := rfl
example : CapError.reason .badVersion    = "bad-version" := rfl
example : CapError.reason .badCbHeight   = "bad-cb-height" := rfl
example : CapError.reason .badWitnessCommitment = "bad-witness-merkle-match" := rfl

end BitcoinProofs.ErrMap.E01
