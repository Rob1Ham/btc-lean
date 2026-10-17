import Bitcoin.Block.Connect
import Bitcoin.Block.Params

/-! # PDW53.lean — TOP-261..265 (D-CONNECT status-debt five)

Row-face theorems on the sorry-free core defs of
`Bitcoin/Block/Connect.lean` (X08 B4). Route B: zero core writes; tags
ride these theorems; `lean_target` flips to them at promotion.

* **BLK-012** `merkleFailureKind` — the CVE-2012-2459 taxonomy. Core's
  `CheckMerkleRoot` returns `BLOCK_MUTATED` for BOTH a root mismatch
  (`bad-txnmrklroot`) and a mutated tree (`bad-txns-duplicate`), so
  `plainMismatch` is a model bucket, not a `BLOCK_CONSENSUS` category.
* **BLK-021** `contextualChecksOrdered` — commitment-before-weight
  order is verdict-invariant (both checks pure); the SegWit activation
  flag is threaded explicitly through both sides of the swap.
* **BLK-109 / INV-107** `connectGenesis` — genesis skips the tx fold:
  UTXO unchanged, best hash recorded.
* **INV-108** `blockSequenceLocksOk` — BIP68 block gate: flag off ⇒
  the gate passes for every tx list.
-/

namespace BitcoinProofs.AF.PDW53

open Bitcoin.Block.Connect

@[rule "BLK-012"]
theorem merkleFailureKind_plain_of_free (leaves : List ByteArray) (fuel : Nat)
    (h : merkleMutationFree leaves fuel = true) :
    merkleFailureKind leaves fuel = MerkleFailure.plainMismatch := by
  unfold merkleFailureKind
  simp [h]

@[rule "BLK-012"]
theorem merkleFailureKind_mutated (leaves : List ByteArray) (fuel : Nat)
    (h : merkleMutationFree leaves fuel = false) :
    merkleFailureKind leaves fuel = MerkleFailure.mutatedDuplicate := by
  unfold merkleFailureKind
  simp [h]

/-- BLK-012 (validation.cpp:3845-3864 @cce32b168): Core's
`CheckMerkleRoot` failure result. Both failure arms — root mismatch
(`bad-txnmrklroot`) and a mutated tree (`bad-txns-duplicate`) — return
`BLOCK_MUTATED`; there is no `BLOCK_CONSENSUS` merkle-failure arm. -/
@[rule "BLK-012"]
inductive CheckMerkleRootResult where
  | blockMutated
  | blockConsensus
deriving Repr, DecidableEq

/-- BLK-012: every `CheckMerkleRoot` failure is `BLOCK_MUTATED`. In
particular `merkleFailureKind`'s `plainMismatch` bucket (mutation-free
leaves that still fail the root comparison) is NOT Core
`BLOCK_CONSENSUS`; it is the `bad-txnmrklroot` arm of `BLOCK_MUTATED`. -/
@[rule "BLK-012"]
def checkMerkleRootResult (kind : MerkleFailure) : CheckMerkleRootResult :=
  match kind with
  | MerkleFailure.plainMismatch => CheckMerkleRootResult.blockMutated
  | MerkleFailure.mutatedDuplicate => CheckMerkleRootResult.blockMutated

/-- BLK-012: the result mapping is total and lands on `BLOCK_MUTATED`. -/
@[rule "BLK-012"]
theorem checkMerkleRootResult_blockMutated (kind : MerkleFailure) :
    checkMerkleRootResult kind = CheckMerkleRootResult.blockMutated := by
  cases kind <;> rfl

/-- BLK-012 (validation.cpp:1987-1996 @cce32b168): Core's
`InvalidBlockFound` guard. Every result except `BLOCK_MUTATED` sets
`BLOCK_FAILED_VALID` (`nStatus |= BLOCK_FAILED_VALID`); `BLOCK_MUTATED`
leaves the index entry untouched. The model is
`Bitcoin.Block.Params.IndexEntry.failed` (= the `BLOCK_FAILED_VALID` bit). -/
@[rule "BLK-012"]
def invalidBlockFound (result : CheckMerkleRootResult)
    (e : Bitcoin.Block.Params.IndexEntry) : Bitcoin.Block.Params.IndexEntry :=
  if result = CheckMerkleRootResult.blockMutated then e else { e with failed := true }

/-- BLK-012: a `CheckMerkleRoot` failure is NOT cached permanently
invalid. `InvalidBlockFound` skips the `BLOCK_FAILED_VALID` write for
`BLOCK_MUTATED`, and both Core merkle-failure arms map to
`BLOCK_MUTATED`, so `failed` is unchanged. -/
@[rule "BLK-012"]
theorem merkleFailure_not_cached_invalid (kind : MerkleFailure)
    (e : Bitcoin.Block.Params.IndexEntry) :
    (invalidBlockFound (checkMerkleRootResult kind) e).failed = e.failed := by
  rw [checkMerkleRootResult_blockMutated]
  rfl

/-- BLK-012: the mutated-tree arm (CVE-2012-2459) leaves `failed` unchanged. -/
@[rule "BLK-012"]
theorem mutatedFailure_not_cached_invalid (leaves : List ByteArray) (fuel : Nat)
    (e : Bitcoin.Block.Params.IndexEntry)
    (_hm : merkleMutationFree leaves fuel = false) (he : e.failed = false) :
    (invalidBlockFound (checkMerkleRootResult (merkleFailureKind leaves fuel)) e).failed
      = false := by
  rw [merkleFailure_not_cached_invalid, he]

/-- BLK-012: the root-mismatch arm (`plainMismatch` in the model's
mutation-free bucket) is also `BLOCK_MUTATED`, so it too leaves `failed`
unchanged. This replaces the audit-rejected claim that a mutation-free
root mismatch was `BLOCK_CONSENSUS` and cached permanently invalid. -/
@[rule "BLK-012"]
theorem plainMismatch_not_cached_invalid (leaves : List ByteArray) (fuel : Nat)
    (e : Bitcoin.Block.Params.IndexEntry)
    (hf : merkleMutationFree leaves fuel = true) (he : e.failed = false) :
    (invalidBlockFound (checkMerkleRootResult (merkleFailureKind leaves fuel)) e).failed
      = false := by
  have hk : merkleFailureKind leaves fuel = MerkleFailure.plainMismatch :=
    merkleFailureKind_plain_of_free leaves fuel hf
  rw [hk, merkleFailure_not_cached_invalid, he]

@[rule "BLK-021"]
theorem contextualChecksOrdered_row (segwitActive : Bool)
    (txs : List Bitcoin.Data.Tx) (cb : Bitcoin.Data.Tx) (totalSize : Nat) :
    contextualChecksOrdered segwitActive txs cb totalSize
      = (Bitcoin.Capstone.Block.weightOk txs totalSize
      && Bitcoin.Capstone.Merkle.commitmentGate segwitActive txs cb) :=
  contextualChecksOrdered_swap segwitActive txs cb totalSize

/-- BLK-021: the operational order of the ConnectBlock contextual prelude
(validation.cpp:4179-4187) — the witness-commitment gate runs FIRST; the
weight check is consulted only after it passes.  Reading the composite as
the nested conditional `if commitmentGate then weightOk else false` is
the check-timing content, not merely the commutative-conjunction
identity. -/
@[rule "BLK-021"]
theorem contextualChecksOrdered_commitment_first (segwitActive : Bool)
    (txs : List Bitcoin.Data.Tx) (cb : Bitcoin.Data.Tx) (totalSize : Nat) :
    contextualChecksOrdered segwitActive txs cb totalSize =
      (if Bitcoin.Capstone.Merkle.commitmentGate segwitActive txs cb then
        Bitcoin.Capstone.Block.weightOk txs totalSize else false) := by
  unfold contextualChecksOrdered
  cases Bitcoin.Capstone.Merkle.commitmentGate segwitActive txs cb <;> simp

/-- BLK-021: a commitment-gate failure rejects the contextual prelude
without the weight result being reached (the hash-invariance discipline:
the weight datum cannot by itself cause a permanently-invalid mark before
the commitment binds the witness tree). -/
@[rule "BLK-021"]
theorem contextualChecksOrdered_commitment_gate (segwitActive : Bool)
    (txs : List Bitcoin.Data.Tx) (cb : Bitcoin.Data.Tx) (totalSize : Nat)
    (h : Bitcoin.Capstone.Merkle.commitmentGate segwitActive txs cb = false) :
    contextualChecksOrdered segwitActive txs cb totalSize = false := by
  rw [contextualChecksOrdered_commitment_first, h]
  rfl

/-- BLK-021: every contextual-prelude rejection is attributable either to
the commitment gate (which is sequenced first) or, once it has passed, to
the weight check. -/
@[rule "BLK-021"]
theorem contextualChecksOrdered_failure_cases (segwitActive : Bool)
    (txs : List Bitcoin.Data.Tx) (cb : Bitcoin.Data.Tx) (totalSize : Nat)
    (h : contextualChecksOrdered segwitActive txs cb totalSize = false) :
    Bitcoin.Capstone.Merkle.commitmentGate segwitActive txs cb = false ∨
      Bitcoin.Capstone.Block.weightOk txs totalSize = false := by
  rw [contextualChecksOrdered_commitment_first] at h
  by_cases hc : Bitcoin.Capstone.Merkle.commitmentGate segwitActive txs cb = true
  · right
    rw [hc] at h
    simpa using h
  · left
    cases hb : Bitcoin.Capstone.Merkle.commitmentGate segwitActive txs cb with
    | false => rfl
    | true => exact absurd hb hc

/-! ### BLK-021 pipeline face (F-W04-005 closed)

`contextualChecksOrdered` still pins the helper's order, and the REAL
pipeline now matches it: `Capstone/Block.lean` checks the witness
commitment (gate + value + nonce) before `weightOk`. The theorem below
is stated on `validateBlock` itself: with an identical earlier-gate set,
a commitment-gate failure returns the commitment verdict even though
`weightOk = false`, so a commitment failure pre-empts `badBlkWeight`.
Core's `ContextualCheckBlock` comment (validation.cpp:4179-4187) gives
the hash-invariance reason for that order. -/

/-- BLK-021 (pipeline face): the REAL `validateBlock` prelude checks the
witness commitment before the block weight; a commitment-gate failure is
returned even when `weightOk` is also false. -/
@[rule "BLK-021"]
theorem validateBlock_commitment_preempts_weight_row
    (raw : ByteArray) (st : Bitcoin.Capstone.Block.CapState)
    (h : Bitcoin.Chain.BlockHeader) (txs : List Bitcoin.Data.Tx)
    (hdec : Bitcoin.Serialization.decodeBlock raw = .ok (h, txs))
    (hstruct : Bitcoin.Capstone.Merkle.vtxNonempty txs = true)
    (hcbpos : Bitcoin.Capstone.Block.cbPositionOk txs = true)
    (hcblen : Bitcoin.Capstone.Block.cbLengthOk (txs.getD 0
      Bitcoin.Capstone.Block.dummyTx) = true)
    (hver : Bitcoin.Capstone.Block.versionOk st.height h.version = true)
    (hbip34 : Bitcoin.Capstone.Block.bip34Ok st.height (txs.getD 0
      Bitcoin.Capstone.Block.dummyTx) = true)
    (htarget : Bitcoin.Capstone.Pow.targetOk h.bits = true)
    (hpow : Bitcoin.Capstone.Pow.powOk h = true)
    (hlink : Bitcoin.Data.bytesBEq h.hashPrevBlock st.prevHash = true)
    (hmerkle : Bitcoin.Capstone.Merkle.merkleOk h txs = true)
    (hmut : Bitcoin.Capstone.Merkle.merkleMutationOk txs = true)
    (hcg : Bitcoin.Capstone.Merkle.commitmentGate
      (Bitcoin.Activation.SEGWIT_HEIGHT ≤ st.height) txs
      (txs.getD 0 Bitcoin.Capstone.Block.dummyTx) = false)
    (hweight : Bitcoin.Capstone.Block.weightOk txs raw.size = false) :
    Bitcoin.Capstone.Block.validateBlock raw st =
      .error (if Bitcoin.Capstone.Merkle.anyWitness txs then
                Bitcoin.Capstone.Block.CapError.badWitnessCommitment
              else Bitcoin.Capstone.Block.CapError.unexpectedWitness) :=
  Bitcoin.Capstone.Block.validateBlock_commitment_preempts_weight
    raw st h txs hdec hstruct hcbpos hcblen hver hbip34 htarget hpow hlink
    hmerkle hmut hcg hweight

/-- BLK-021: a commitment failure never yields `badBlkWeight`, even when
the weight gate would also fail — the weight verdict is pre-empted. -/
@[rule "BLK-021"]
theorem validateBlock_commitment_failure_ne_badBlkWeight
    (raw : ByteArray) (st : Bitcoin.Capstone.Block.CapState)
    (h : Bitcoin.Chain.BlockHeader) (txs : List Bitcoin.Data.Tx)
    (hdec : Bitcoin.Serialization.decodeBlock raw = .ok (h, txs))
    (hstruct : Bitcoin.Capstone.Merkle.vtxNonempty txs = true)
    (hcbpos : Bitcoin.Capstone.Block.cbPositionOk txs = true)
    (hcblen : Bitcoin.Capstone.Block.cbLengthOk (txs.getD 0
      Bitcoin.Capstone.Block.dummyTx) = true)
    (hver : Bitcoin.Capstone.Block.versionOk st.height h.version = true)
    (hbip34 : Bitcoin.Capstone.Block.bip34Ok st.height (txs.getD 0
      Bitcoin.Capstone.Block.dummyTx) = true)
    (htarget : Bitcoin.Capstone.Pow.targetOk h.bits = true)
    (hpow : Bitcoin.Capstone.Pow.powOk h = true)
    (hlink : Bitcoin.Data.bytesBEq h.hashPrevBlock st.prevHash = true)
    (hmerkle : Bitcoin.Capstone.Merkle.merkleOk h txs = true)
    (hmut : Bitcoin.Capstone.Merkle.merkleMutationOk txs = true)
    (hcg : Bitcoin.Capstone.Merkle.commitmentGate
      (Bitcoin.Activation.SEGWIT_HEIGHT ≤ st.height) txs
      (txs.getD 0 Bitcoin.Capstone.Block.dummyTx) = false)
    (hweight : Bitcoin.Capstone.Block.weightOk txs raw.size = false) :
    Bitcoin.Capstone.Block.validateBlock raw st ≠
      .error Bitcoin.Capstone.Block.CapError.badBlkWeight := by
  rw [validateBlock_commitment_preempts_weight_row raw st h txs hdec hstruct
    hcbpos hcblen hver hbip34 htarget hpow hlink hmerkle hmut hcg hweight]
  split <;> intro hbad <;> cases hbad

@[rule "BLK-109"]
theorem connectGenesis_utxo_row (utxo : List (Bitcoin.Data.OutPoint × Bitcoin.Ledger.Coin))
    (h : Bitcoin.Chain.BlockHeader) : (connectGenesis utxo h).1 = utxo :=
  connectGenesis_utxo_unchanged utxo h

@[rule "INV-107"]
theorem connectGenesis_hash_row (utxo : List (Bitcoin.Data.OutPoint × Bitcoin.Ledger.Coin))
    (h : Bitcoin.Chain.BlockHeader) :
    (connectGenesis utxo h).2 = Bitcoin.Capstone.Pow.headerHash h := rfl

@[rule "INV-108"]
theorem blockSequenceLocksOk_gate_off (txs : List Bitcoin.Data.Tx)
    (prevDataOf : Bitcoin.Data.Tx → List (Int × Int)) (blockHeight blockMTP : Int) :
    blockSequenceLocksOk txs false prevDataOf blockHeight blockMTP = true := by
  unfold blockSequenceLocksOk
  simp

end BitcoinProofs.AF.PDW53
