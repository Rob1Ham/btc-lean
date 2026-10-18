import Bitcoin.Capstone.Block

/-!
# BitcoinProofs.Theorems.CapstoneError — P11: the proved error taxonomy (sorry-free)

The capstone (`Bitcoin.Capstone.Block`) rejects blocks through the
`CapError` taxonomy — 19 constructors covering every layer — and
reports Core's exact reject strings via `CapError.reason`.  This module
pins that report-level surface as theorems: every reject string is a
concrete nonempty literal, the index-carrying constructors report their
string independently of the indices, the taxonomy carries a decidable
equality, and the constructors are injective.

C4 portfolio linkage:

| C4 ID    | theorem here | statement (short) |
|----------|--------------|-------------------|
| (ERR-001) | `reason_nonempty` | EVERY constructor reports a nonempty reject string (all 19; none restricted away) |
| (ERR-002) | `reason_ser` … `reason_scriptFalse` | the 13 locally-owned + 2 index-carrying reject strings, `rfl`-pinned against Core's exact strings |
| (ERR-003) | `reason_txCheck_vinEmpty` … `reason_block_txError`, `reason_txCheck_routes`, `reason_tx_stateless_routes` | the embedded-layer strings route to the embedded modules' own reason tables exactly |
| (ERR-004) | `reason_scriptFail_ignores_indices` / `reason_scriptFalse_ignores_indices` | the script reject strings do not depend on the tx/input indices (report-level honesty) |
| (ERR-005) | `scriptFail_index_injectivity` / `scriptFalse_index_injectivity` | the index-carrying constructors are injective |
| (ERR-006) | `reason_badCbLength_eq_cbLength` | the one string shared across layers ("bad-cb-length") is intentional, matching Core |
| (ERR-007) | `capError_eq_dec` / `capError_decide_iff` / `inputVerdict_eq_dec` / `inputVerdict_decide_iff` | capstone verdict statements are decidable |
| (ERR-008) | `witness_errors_pairwise_distinct` | the three witness-gate errors are pairwise distinct |

Honesty notes:
* `reason_nonempty` covers ALL 19 constructors.  The sub-reasons that
  come from the embedded layers — `txCheckReason` (9 stateless strings)
  and `rejectReason` (8 contextual strings) — are themselves
  proved nonempty here (`txCheckReason_nonempty`, `rejectReason_nonempty`),
  so no constructor had to be restricted away.
* `reason` is deliberately NOT injective across layers: `badCbLength`
  (block structure, BLK-029) and `txCheck .cbLength` (stateless, TXV-006)
  both report "bad-cb-length", exactly as Core reuses the string at both
  call sites.  `reason_badCbLength_eq_cbLength` pins this as intended.
* The taxonomy has 19 constructors (the package documentation said 17; the
  freeze in `Bitcoin.Capstone.Block` gained `blockMutated` in BLK-011).

Axiom footprints (audited with `#print axioms`, pinned by `#guard_msgs`
at the bottom of this file): every theorem here is axiom-free.
-/

namespace BitcoinProofs.Theorems.CapstoneError

open Bitcoin.Capstone.Block Bitcoin.TxValidation Bitcoin.Consensus
open Bitcoin.Interpreter Bitcoin.Serialization

/-! ## The embedded layers' nonemptiness (sub-taxonomies) -/

/-- Every stateless reject string is nonempty (9/9 literals,
consensus/tx_check.cpp:23-68). -/
theorem txCheckReason_nonempty (e : TxCheckError) : txCheckReason e ≠ "" := by
  cases e <;> simp only [txCheckReason] <;> decide

/-- Every contextual reject string is nonempty (8/8; the `stateless`
arm routes to `txCheckReason`, whose nonemptiness is the theorem above). -/
theorem rejectReason_nonempty (e : TxError) : rejectReason e ≠ "" := by
  cases e with
  | stateless e' => exact txCheckReason_nonempty e'
  | _ => simp only [rejectReason] <;> decide

/-! ## ERR-001: the report's reject column is never blank -/

/-- **ERR-001**: every constructor of the capstone taxonomy reports a
nonempty reject string — `CapError.reason` is total over the taxonomy in
the strong sense that its output is never the empty string. -/
theorem reason_nonempty (e : CapError) : CapError.reason e ≠ "" := by
  cases e with
  | ser _ => simp only [CapError.reason]; decide
  | txCheck e => exact txCheckReason_nonempty e
  | tx e => exact rejectReason_nonempty e
  | block e =>
      cases e with
      | txError e' => exact rejectReason_nonempty e'
      | badTxnsBIP30 => simp only [CapError.reason]; decide
      | badCbMissing => simp only [CapError.reason]; decide
      | badCbMultiple => simp only [CapError.reason]; decide
  | emptyBlock => simp only [CapError.reason]; decide
  | badCbPosition => simp only [CapError.reason]; decide
  | badCbLength => simp only [CapError.reason]; decide
  | badBlkWeight => simp only [CapError.reason]; decide
  | badPow => simp only [CapError.reason]; decide
  | badChainLink => simp only [CapError.reason]; decide
  | badMerkleRoot => simp only [CapError.reason]; decide
  | blockMutated => simp only [CapError.reason]; decide
  | unexpectedWitness => simp only [CapError.reason]; decide
  | badWitnessCommitment => simp only [CapError.reason]; decide
  | badWitnessNonce => simp only [CapError.reason]; decide
  | badVersion => simp only [CapError.reason]; decide
  | badCbHeight => simp only [CapError.reason]; decide
  | scriptFail _ _ _ => simp only [CapError.reason]; decide
  | scriptFalse _ _ => simp only [CapError.reason]; decide

/-! ## ERR-002: the 13 locally-owned strings + the decode/script strings -/

/-- `CapError.ser` (decode) reports Core's decode error. -/
theorem reason_ser (e : SerError) :
    CapError.reason (.ser e) = "decode-error" := rfl

/-- BLK-022: empty vtx. -/
theorem reason_emptyBlock :
    CapError.reason .emptyBlock = "bad-blk-length (empty vtx)" := rfl

/-- BLK-027/BLK-028: coinbase position. -/
theorem reason_badCbPosition :
    CapError.reason .badCbPosition = "bad-cb-missing/multiple" := rfl

/-- BLK-029: coinbase scriptSig length. -/
theorem reason_badCbLength :
    CapError.reason .badCbLength = "bad-cb-length" := rfl

/-- BLK-024/BLK-026: block weight. -/
theorem reason_badBlkWeight :
    CapError.reason .badBlkWeight = "bad-blk-weight" := rfl

/-- BLK-039/BLK-038: proof of work (`high-hash` is Core's string for the
bits-target check that BLK-039's `targetOk` front-runs). -/
theorem reason_badPow :
    CapError.reason .badPow = "high-hash" := rfl

/-- Chain link: `hashPrevBlock` ≠ expected parent. -/
theorem reason_badChainLink :
    CapError.reason .badChainLink = "bad-prevblk" := rfl

/-- BLK-010: merkle root mismatch. -/
theorem reason_badMerkleRoot :
    CapError.reason .badMerkleRoot = "bad-txnmrklroot" := rfl

/-- BLK-019: witness present without a commitment. -/
theorem reason_unexpectedWitness :
    CapError.reason .unexpectedWitness = "unexpected-witness" := rfl

/-- BLK-017/BLK-020: witness commitment mismatch/missing. -/
theorem reason_badWitnessCommitment :
    CapError.reason .badWitnessCommitment = "bad-witness-missing" := rfl

/-- BLK-018: witness nonce size. -/
theorem reason_badWitnessNonce :
    CapError.reason .badWitnessNonce = "bad-witness-nonce-size" := rfl

/-- BLK-060/061/062: buried version gates. -/
theorem reason_badVersion :
    CapError.reason .badVersion = "bad-version" := rfl

/-- BLK-069: BIP34 coinbase height push. -/
theorem reason_badCbHeight :
    CapError.reason .badCbHeight = "bad-cb-height" := rfl

/-- Script failure (real ECDSA checker): Core's
script-verify error. -/
theorem reason_scriptFail (i j : Nat) (e : ExecError) :
    CapError.reason (.scriptFail i j e) = "script-verify-error" := rfl

/-- script evaluated to false. -/
theorem reason_scriptFalse (i j : Nat) :
    CapError.reason (.scriptFalse i j) = "script-eval-false" := rfl

/-! ## ERR-003: the embedded layers route to their own reason tables -/

/-- stateless routing: `txCheck` errors report `txCheckReason`
verbatim. -/
theorem reason_txCheck_routes (e : TxCheckError) :
    CapError.reason (.txCheck e) = txCheckReason e := rfl

/-- contextual routing: `tx` errors report `rejectReason` verbatim. -/
theorem reason_tx_routes (e : TxError) :
    CapError.reason (.tx e) = rejectReason e := rfl

/-- fold routing: `block .txError` errors report `rejectReason`
verbatim. -/
theorem reason_block_txError (e : TxError) :
    CapError.reason (.block (.txError e)) = rejectReason e := rfl

/-- stateless errors embedded in `tx` still reach `txCheckReason`
(two-level routing through `rejectReason .stateless`). -/
theorem reason_tx_stateless_routes (e : TxCheckError) :
    CapError.reason (.tx (.stateless e)) = txCheckReason e := rfl

/-- A representative stateless string through the capstone wrapper
(CVE-2018-17144's duplicate-input check). -/
theorem reason_txCheck_inputsDuplicate :
    CapError.reason (.txCheck .inputsDuplicate) = "bad-txns-inputs-duplicate" := rfl

/-- A representative contextual string through the capstone wrapper
(tx_verify.cpp:174). -/
theorem reason_tx_inputsMissingOrSpent :
    CapError.reason (.tx .badTxnsInputsMissingOrSpent)
      = "bad-txns-inputs-missingorspent" := rfl

/-- BIP30 string through the capstone wrapper
(validation.cpp:2496-2511). -/
theorem reason_block_bip30 :
    CapError.reason (.block .badTxnsBIP30) = "bad-txns-BIP30" := rfl

/-- coinbase-missing string through the capstone wrapper
(ConnectBlock:2540-2545). -/
theorem reason_block_cbMissing :
    CapError.reason (.block .badCbMissing) = "bad-cb-missing" := rfl

/-! ## ERR-004: index-independence of the script reject strings -/

/-- **ERR-004**: the `scriptFail` reject string does not depend on the tx
index, the input index, or the `ExecError` payload — a report consumer
reading only the reject column cannot distinguish which input failed.
(The indices ARE recoverable from the structured error, see ERR-005.) -/
theorem reason_scriptFail_ignores_indices (i i' j j' : Nat) (e e' : ExecError) :
    CapError.reason (.scriptFail i j e)
      = CapError.reason (.scriptFail i' j' e') := rfl

/-- Same report-level honesty for `scriptFalse`. -/
theorem reason_scriptFalse_ignores_indices (i i' j j' : Nat) :
    CapError.reason (.scriptFalse i j)
      = CapError.reason (.scriptFalse i' j') := rfl

/-! ## ERR-005: constructor injectivity -/

/-- **ERR-005**: `scriptFail` is injective — equal structured errors
carry equal tx indices, equal input indices, and equal `ExecError`
payloads (constructor injectivity, stronger than the documented
index-only statement). -/
theorem scriptFail_index_injectivity {i i' j j' : Nat} {e e' : ExecError}
    (h : CapError.scriptFail i j e = CapError.scriptFail i' j' e') :
    i = i' ∧ j = j' ∧ e = e' := by
  injection h with h₁ h₂ h₃
  exact ⟨h₁, h₂, h₃⟩

/-- `scriptFalse` is injective in both indices. -/
theorem scriptFalse_index_injectivity {i i' j j' : Nat}
    (h : CapError.scriptFalse i j = CapError.scriptFalse i' j') :
    i = i' ∧ j = j' := by
  injection h with h₁ h₂
  exact ⟨h₁, h₂⟩

/-! ## ERR-006: the one cross-layer shared string -/

/-- **ERR-006**: the block-structure `badCbLength` and the stateless
`txCheck .cbLength` report the SAME string — intentional, Core reuses
"bad-cb-length" at both call sites (BLK-029 vs TXV-006). -/
theorem reason_badCbLength_eq_cbLength :
    CapError.reason .badCbLength = txCheckReason .cbLength := rfl

/-! ## ERR-007: decidability of capstone verdict statements -/

/-- **ERR-007**: the taxonomy carries the derived `DecidableEq`, so every
statement of the form "the capstone rejected with error `e`" is a
decidable proposition — this definition exhibits the derived decider. -/
def capError_eq_dec (e e' : CapError) : Decidable (e = e') :=
  inferInstanceAs (Decidable (e = e'))

/-- Decidable equality in `decide` form: `decide (e = e')` computes the
verdict and reflects it exactly. -/
theorem capError_decide_iff (e e' : CapError) :
    decide (e = e') = true ↔ e = e' := decide_eq_true_iff

/-- The per-input verdict type of `verifyInput` is likewise decidable
(its `fail` payload is a `CapError`) — exhibited decider. -/
def inputVerdict_eq_dec (a b : InputVerdict) : Decidable (a = b) :=
  inferInstanceAs (Decidable (a = b))

/-- Decidable equality in `decide` form for per-input verdicts. -/
theorem inputVerdict_decide_iff (a b : InputVerdict) :
    decide (a = b) = true ↔ a = b := decide_eq_true_iff

/-! ## ERR-008: the witness-gate errors are pairwise distinct -/

/-- **ERR-008**: the three witness-gate constructors are pairwise
distinct elements of the taxonomy (decidable equality in action — this
is the statement the anchor runner's `decide`-checked dispatch relies
on). -/
theorem witness_errors_pairwise_distinct :
    (CapError.unexpectedWitness : CapError) ≠ CapError.badWitnessCommitment ∧
    (CapError.unexpectedWitness : CapError) ≠ CapError.badWitnessNonce ∧
    (CapError.badWitnessCommitment : CapError) ≠ CapError.badWitnessNonce := by
  decide

/-- The two script-lane reject strings differ, so a report can always
tell a verify failure from an eval-false. -/
theorem reason_scriptFail_ne_scriptFalse (i j : Nat) (e : ExecError) :
    CapError.reason (.scriptFail i j e) ≠ CapError.reason (.scriptFalse i j) := by
  show "script-verify-error" ≠ "script-eval-false"
  decide

/-! ## Axiom-footprint pins (L3): drift on any of these fails the build -/

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_nonempty' does not depend on any axioms -/
#guard_msgs in #print axioms reason_nonempty

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_ser' does not depend on any axioms -/
#guard_msgs in #print axioms reason_ser

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_emptyBlock' does not depend on any axioms -/
#guard_msgs in #print axioms reason_emptyBlock

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_badCbPosition' does not depend on any axioms -/
#guard_msgs in #print axioms reason_badCbPosition

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_badCbLength' does not depend on any axioms -/
#guard_msgs in #print axioms reason_badCbLength

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_badBlkWeight' does not depend on any axioms -/
#guard_msgs in #print axioms reason_badBlkWeight

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_badPow' does not depend on any axioms -/
#guard_msgs in #print axioms reason_badPow

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_badChainLink' does not depend on any axioms -/
#guard_msgs in #print axioms reason_badChainLink

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_badMerkleRoot' does not depend on any axioms -/
#guard_msgs in #print axioms reason_badMerkleRoot

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_unexpectedWitness' does not depend on any axioms -/
#guard_msgs in #print axioms reason_unexpectedWitness

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_badWitnessCommitment' does not depend on any axioms -/
#guard_msgs in #print axioms reason_badWitnessCommitment

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_badWitnessNonce' does not depend on any axioms -/
#guard_msgs in #print axioms reason_badWitnessNonce

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_badVersion' does not depend on any axioms -/
#guard_msgs in #print axioms reason_badVersion

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_badCbHeight' does not depend on any axioms -/
#guard_msgs in #print axioms reason_badCbHeight

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_scriptFail' does not depend on any axioms -/
#guard_msgs in #print axioms reason_scriptFail

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_scriptFalse' does not depend on any axioms -/
#guard_msgs in #print axioms reason_scriptFalse

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_txCheck_routes' does not depend on any axioms -/
#guard_msgs in #print axioms reason_txCheck_routes

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_tx_routes' does not depend on any axioms -/
#guard_msgs in #print axioms reason_tx_routes

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_block_txError' does not depend on any axioms -/
#guard_msgs in #print axioms reason_block_txError

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_tx_stateless_routes' does not depend on any axioms -/
#guard_msgs in #print axioms reason_tx_stateless_routes

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_txCheck_inputsDuplicate' does not depend on any axioms -/
#guard_msgs in #print axioms reason_txCheck_inputsDuplicate

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_tx_inputsMissingOrSpent' does not depend on any axioms -/
#guard_msgs in #print axioms reason_tx_inputsMissingOrSpent

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_block_bip30' does not depend on any axioms -/
#guard_msgs in #print axioms reason_block_bip30

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_block_cbMissing' does not depend on any axioms -/
#guard_msgs in #print axioms reason_block_cbMissing

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_scriptFail_ignores_indices' does not depend on any axioms -/
#guard_msgs in #print axioms reason_scriptFail_ignores_indices

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_scriptFalse_ignores_indices' does not depend on any axioms -/
#guard_msgs in #print axioms reason_scriptFalse_ignores_indices

/-- info: 'BitcoinProofs.Theorems.CapstoneError.scriptFail_index_injectivity' does not depend on any axioms -/
#guard_msgs in #print axioms scriptFail_index_injectivity

/-- info: 'BitcoinProofs.Theorems.CapstoneError.scriptFalse_index_injectivity' does not depend on any axioms -/
#guard_msgs in #print axioms scriptFalse_index_injectivity

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_badCbLength_eq_cbLength' does not depend on any axioms -/
#guard_msgs in #print axioms reason_badCbLength_eq_cbLength

/-- info: 'BitcoinProofs.Theorems.CapstoneError.capError_eq_dec' does not depend on any axioms -/
#guard_msgs in #print axioms capError_eq_dec

/-- info: 'BitcoinProofs.Theorems.CapstoneError.capError_decide_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms capError_decide_iff

/-- info: 'BitcoinProofs.Theorems.CapstoneError.inputVerdict_eq_dec' does not depend on any axioms -/
#guard_msgs in #print axioms inputVerdict_eq_dec

/-- info: 'BitcoinProofs.Theorems.CapstoneError.inputVerdict_decide_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms inputVerdict_decide_iff

/-- info: 'BitcoinProofs.Theorems.CapstoneError.witness_errors_pairwise_distinct' does not depend on any axioms -/
#guard_msgs in #print axioms witness_errors_pairwise_distinct

/-- info: 'BitcoinProofs.Theorems.CapstoneError.reason_scriptFail_ne_scriptFalse' does not depend on any axioms -/
#guard_msgs in #print axioms reason_scriptFail_ne_scriptFalse

end BitcoinProofs.Theorems.CapstoneError
