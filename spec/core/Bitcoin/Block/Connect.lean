import Bitcoin.Chain.Basic
import Bitcoin.Block.Pow
import Bitcoin.RuleAttr
import Bitcoin.Data.Basic
import Bitcoin.DataLaws.Interface
import Bitcoin.Consensus.TxCheck
import Bitcoin.TxValidation.Interface
import Bitcoin.Ledger.Interface
import Bitcoin.Conservation.Interface
import Bitcoin.Capstone.Merkle
import Bitcoin.Capstone.Block
import Bitcoin.Block.Params

/-!
# Bitcoin.Block.Connect — ConnectBlock-phase semantics (the block-validation module)

The checks Core performs AT CONNECTION TIME (validation.cpp
ConnectBlock @cce32b168), in Core's order, as pure functions over the
decoded block + running view:

* **Order (doc + theorems)** — ConnectBlock's discipline is per-tx
  checks FIRST (finality → inputs/fee → sequence locks → script →
  ledger step), block-level accumulators AFTER the loop (coinbase
  amount, fee range). Within the contextual prelude, the witness
  commitment gate precedes the weight check (BLK-021 — both are pure
  over the decoded block, so the ORDER is invariant-hygiene, not
  semantics; theorem `contextualChecksOrdered_swap`).
* `finalityCutoff` — **BLK-067**: BIP113 — cutoff = MTP(prev) when CSV
  is active, else the block's own time.
* `blockFinalityOk` — **BLK-068**: every tx final at (height, cutoff).
* `blockSequenceLocksOk` — **BLK-104**: BIP68 aggregated at block level
  over `sequenceLocksOk` + field algebra; CSV-gated,
  coinbase-skipped, enforced only in ConnectBlock.
* `cbAmountOk` — **BLK-089**: Σ coinbase outputs ≤ fees + subsidy,
  composing `chainFeesL` (THM-037's executable fee fold) with
  `blockSubsidy` (BLK-090).
* `feeAccumInRange` — **BLK-091**: the accumulated fee must be in
  MoneyRange (`bad-txns-accumulated-fee-outofrange`).
* `vtxCountWeightOk` — **BLK-023**: vtx.size × 4 ≤ 4,000,000.
* `merkleMutationFree`/`merkleFailureKind` — **BLK-011/BLK-012**: the
  CVE-2012-2459 pair-aligned-duplicate detector (even-offset pairs
  `hashes[2i] == hashes[2i+1]`) over the level fold, and the
  BLOCK_MUTATED-vs-CONSENSUS taxonomy (mutated ⇒ not cached
  permanently invalid).
* `connectGenesis` — **BLK-109**: the genesis connection skips the tx
  fold entirely (validation.cpp:2330-2334).

Every theorem sorry-free; axiom pins at the bottom.
-/

namespace Bitcoin.Block.Connect

open Bitcoin.Data Bitcoin.DataLaws Bitcoin.Consensus Bitcoin.TxValidation
open Bitcoin.Ledger Bitcoin.Conservation
open Bitcoin.Capstone.Pow Bitcoin.Capstone.Block Bitcoin.Capstone.Merkle

/-! ## BLK-023: the vtx-count pre-bound -/

/-- **BLK-023** (CheckBlock's first size gate): `vtx.size() × 4 ≤
4,000,000` — rejects absurd tx counts before any per-tx work. -/
@[rule "BLK-023"]
def vtxCountWeightOk (txs : List Tx) : Bool :=
  txs.length * 4 ≤ MAX_BLOCK_WEIGHT

/-- The bound is decidable-correct: it fails exactly above 1,000,000
txs. -/
theorem vtxCountWeightOk_iff (txs : List Tx) :
    vtxCountWeightOk txs = true ↔ txs.length ≤ 1_000_000 := by
  unfold vtxCountWeightOk MAX_BLOCK_WEIGHT
  constructor
  · intro h; have hp := of_decide_eq_true h; omega
  · intro h; rw [decide_eq_true (by omega)]

/-! ## BLK-067/068: block-level finality -/

/-- **BLK-067** (BIP113, validation.cpp:4143-4155): the finality cutoff
is the parent's median-time-past once CSV is active, else the block's
own time. -/
@[rule "BLK-067"]
def finalityCutoff (csvActive : Bool) (mtp blockTime : UInt32) : UInt32 :=
  if csvActive then mtp else blockTime

/-- The switch in both positions. -/
theorem finalityCutoff_csv (mtp blockTime : UInt32) :
    finalityCutoff true mtp blockTime = mtp := rfl

theorem finalityCutoff_no_csv (mtp blockTime : UInt32) :
    finalityCutoff false mtp blockTime = blockTime := rfl

/-- **BLK-067** at the ConnectBlock call site: the BIP113 cutoff is built
from the *parent block's* `GetMedianTimePast` (`MTP(prev)`), not from an
unconstrained parameter.  `get` is the same height→time spine used by
`Bitcoin.Block.Pow.medianTimePast`; `parentHeight` is `height − 1` in
ConnectBlock.  `none` means the parent window is not resolved, exactly as
`medianTimePast` itself is partial over the map model. -/
@[rule "BLK-067"]
def finalityCutoffAtParent (csvActive : Bool) (get : Nat → Option UInt32)
    (parentHeight : Nat) (blockTime : UInt32) : Option UInt32 :=
  (Bitcoin.Block.Pow.medianTimePast get parentHeight).map
    (fun mtp => finalityCutoff csvActive mtp blockTime)

/-- **BLK-068** (validation.cpp:4157-4161): EVERY tx of the block must
be final at (height, cutoff) — `bad-txns-nonfinal`. -/
@[rule "BLK-068"]
def blockFinalityOk (txs : List Tx) (height cutoff : UInt32) : Bool :=
  txs.all (fun t => isFinalTx t height cutoff)

/-- Pointwise reading of the block-level finality gate. -/
@[rule "BLK-068"]
theorem blockFinalityOk_all (txs : List Tx) (height cutoff : UInt32)
    (h : blockFinalityOk txs height cutoff = true)
    (t : Tx) (ht : t ∈ txs) : isFinalTx t height cutoff = true :=
  List.all_eq_true.mp h t ht

/-- The singleton block is final iff its coinbase is. -/
theorem blockFinalityOk_singleton (cb : Tx) (height cutoff : UInt32) :
    blockFinalityOk [cb] height cutoff = isFinalTx cb height cutoff := by
  simp [blockFinalityOk]

/-! ## BLK-104: sequence locks at block level -/

/-- **BLK-104** (validation.cpp:2525-2538 + tx_verify.cpp
`CalculateSequenceLocks`/`EvaluateSequenceLocks` via the transaction validator): BIP68
aggregated over the block — per tx, the sequence lock evaluated against
the coin-view's (creation-height, parent-MTP) data; CSV-gated
(`CHECKSEQUENCEVERIFY` in the block's flags), coinbase-skipped, and
enforced ONLY here (the mempool cannot know the connect height).
`prevDataOf` is the seam: per tx, the per-input pairs built from the
running view (TXV-034..038 field algebra underneath). -/
@[rule "BLK-104", rule "INV-108"]
def blockSequenceLocksOk (txs : List Tx) (csvFlag : Bool)
    (prevDataOf : Tx → List (Int × Int)) (blockHeight blockMTP : Int) : Bool :=
  txs.all (fun tx =>
    tx.isCoinBase || !csvFlag ||
      sequenceLocksOk tx csvFlag (prevDataOf tx) blockHeight blockMTP)

/-- Aggregation is complete: per-tx coinbase-exemption-or-satisfied-lock
for every tx ⇒ the block-level gate passes. -/
theorem blockSequenceLocksOk_all (txs : List Tx) (csvFlag : Bool)
    (prevDataOf : Tx → List (Int × Int)) (blockHeight blockMTP : Int)
    (hall : ∀ t ∈ txs, t.isCoinBase = true ∨
      sequenceLocksOk t csvFlag (prevDataOf t) blockHeight blockMTP = true) :
    blockSequenceLocksOk txs csvFlag prevDataOf blockHeight blockMTP = true := by
  unfold blockSequenceLocksOk
  apply List.all_eq_true.mpr
  intro t tm
  rcases hall t tm with hcb | hok
  · rw [hcb]; rfl
  · simp [hok]

/-! ## BLK-089/091: the coinbase amount + fee-range gates -/

/-- **BLK-089** (validation.cpp:2608-2612, `bad-cb-amount`): the
coinbase's total output value must not exceed fees + subsidy. `fees` is
The executable fee fold `chainFeesL` at the REAL view — the exact
composition point of the THM-037 lane with the issuance schedule
(BLK-090). -/
@[rule "BLK-089"]
def cbAmountOk (cb : Tx) (fees : Amount) (height : UInt32) : Bool :=
  cb.getValueOut ≤ fees + blockSubsidy height

theorem cbAmountOk_iff (cb : Tx) (fees : Amount) (height : UInt32) :
    cbAmountOk cb fees height = true ↔ cb.getValueOut ≤ fees + blockSubsidy height := by
  simp [cbAmountOk, decide_eq_true_iff]

/-- The subsidy never jeopardizes the gate: it is bounded by MAX_MONEY
(50·COIN at most), so any MoneyRange-legal fee keeps the RHS sane. -/
theorem blockSubsidy_le_MAX_MONEY (height : UInt32) :
    blockSubsidy height ≤ MAX_MONEY := by
  unfold blockSubsidy MAX_MONEY COIN
  have h1 : ((5000000000 / 2 ^ (min (halvingsAt height) 64) : Nat) : Amount)
      ≤ ((5000000000 : Nat) : Amount) :=
    Int.ofNat_le.mpr (Nat.div_le_self _ _)
  have h2 : (((5000000000 : Nat) : Amount) : Amount) ≤ 2100000000000000 := by
    decide
  exact Int.le_trans h1 h2

/-- **BLK-091** (validation.cpp:2543-2548): the accumulated fee must be
in MoneyRange — the SUM is re-checked, not just the per-tx fees
(two in-range fees can jointly leave the range). **TXV-026**
(TXV-A route-A alias, attr-only): the same check @cce32b168 is
validation.cpp:2540-2545 (`nFees += txfee;` + `if (!MoneyRange(nFees))`
→ `bad-txns-accumulated-fee-outofrange`); the row anchor 2548–2552 and
BLK-091's 2543–2548 both drift to 2540–2545 (report 05/08 drift). -/
@[rule "BLK-091", rule "TXV-026"]
def feeAccumInRange (fees : Amount) : Bool := MoneyRange fees

/-- The executable fee fold's accumulation passes BLK-091 whenever it is
capped: nonnegativity comes from THM-037 (`chainFees_nonneg` lifted
through `chainFees_viewOf`), the cap from the caller. -/
theorem chainFeesL_feeAccumInRange (l : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32)
    (hcap : chainFeesL l kf txs height ≤ MAX_MONEY) :
    feeAccumInRange (chainFeesL l kf txs height) = true := by
  unfold feeAccumInRange
  rw [moneyRange_eq_true_iff]
  refine ⟨?_, hcap⟩
  rw [← chainFees_viewOf kf]
  exact chainFees_nonneg (viewOf l) kf txs height

/-- **The block-validation module composition headline**: at the real fee fold, the coinbase
draw is bounded by subsidy + fees, and the fee side is nonnegative —
the two halves of `bad-cb-amount`'s economics in one statement. -/
theorem coinbase_draw_le_subsidy_plus_fees (cb : Tx)
    (l : List (OutPoint × Coin)) (kf : Tx → Key) (txs : List Tx) (height : UInt32)
    (hok : cbAmountOk cb (chainFeesL l kf txs height) height = true) :
    cb.getValueOut ≤ (blockSubsidy height : Amount) + chainFeesL l kf txs height ∧
    0 ≤ chainFeesL l kf txs height := by
  have hle := (cbAmountOk_iff cb _ _).mp hok
  rw [Int.add_comm] at hle
  refine ⟨hle, ?_⟩
  rw [← chainFees_viewOf kf]
  exact chainFees_nonneg (viewOf l) kf txs height

/-! ## BLK-011/012: merkle mutation -/

/-- **BLK-011** (merkle.cpp:55-63 + validation.cpp:3853-3864): a level
containing an equal pair at an EVEN offset (`hashes[2i] == hashes[2i+1]`)
marks the block as a mutation (CVE-2012-2459's shape). Core's
`ComputeMerkleRoot` walks `for (i = 0; i < tree.size(); i += 2)` and only
compares `tree[i]` with `tree[i+1]`; an odd-tail pair such as
`[A, B, B]` is therefore NOT a mutation (the fixed 2012 rule). The name
is retained for API stability. -/
@[rule "BLK-011"]
def levelHasAdjacentDup : List ByteArray → Bool
  | [] => false
  | [_] => false
  | a :: b :: rest => (a == b) || levelHasAdjacentDup rest

/-- The mutation detector over the whole tree: every level of the
`merkleLevel` fold is pair-aligned-duplicate-free. -/
def merkleMutationFree : List ByteArray → Nat → Bool
  | _, 0 => true
  | l, f+1 =>
    if l.length ≤ 1 then true
    else !(levelHasAdjacentDup l) && merkleMutationFree (merkleLevel l) f

/-- A single-leaf tree (one-tx block) is always mutation-free — there is
no pair to duplicate. -/
theorem merkleMutationFree_singleton (a : ByteArray) :
    merkleMutationFree [a] (0 + 1) = true := by
  unfold merkleMutationFree; simp

/-- **BLK-012** (validation.cpp:1987-1996): the failure taxonomy. A
merkle mismatch on a mutation-free tree is plain CONSENSUS; a mismatch
with a pair-aligned-duplicate level is BLOCK_MUTATED — which must NOT
mark the block permanently invalid (the duplicate shape is
attacker-chosen relay data, not a chain-consensus fact). -/
inductive MerkleFailure where
  | plainMismatch     -- BLOCK_CONSENSUS "bad-txnmrklroot"
  | mutatedDuplicate  -- BLOCK_MUTATED "bad-txns-duplicate" (not cached invalid)
deriving Repr, DecidableEq

@[rule "BLK-012"]
def merkleFailureKind (leaves : List ByteArray) (fuel : Nat) : MerkleFailure :=
  if merkleMutationFree leaves fuel then MerkleFailure.plainMismatch
  else MerkleFailure.mutatedDuplicate

/-- The taxonomy is exhaustive and disjoint: mutated ⇒ not
mutation-free. -/
theorem merkleFailureKind_mutated_iff (leaves : List ByteArray) (fuel : Nat) :
    merkleFailureKind leaves fuel = MerkleFailure.mutatedDuplicate ↔
      merkleMutationFree leaves fuel = false := by
  unfold merkleFailureKind
  cases h : merkleMutationFree leaves fuel with
  | true => simp [h]
  | false => simp [h]

/-! ## BLK-021: the commitment-before-weight order -/

/-- **BLK-021** (validation.cpp:4179-4187's discipline): in the
contextual prelude the witness-commitment gate precedes the weight
check — the weight datum depends on witness framing, which only the
commitment binds. Both checks are PURE functions of the decoded block,
so the semantic verdict is order-invariant (theorem below); the order
is hash-invariance/cost hygiene. -/
@[rule "BLK-021"]
def contextualChecksOrdered (segwitActive : Bool) (txs : List Tx) (cb : Tx)
    (totalSize : Nat) : Bool :=
  commitmentGate segwitActive txs cb && weightOk txs totalSize

/-- The swapped composition is verdict-equal (pure-check order
independence). -/
theorem contextualChecksOrdered_swap (segwitActive : Bool) (txs : List Tx)
    (cb : Tx) (totalSize : Nat) :
    contextualChecksOrdered segwitActive txs cb totalSize =
      (weightOk txs totalSize && commitmentGate segwitActive txs cb) := by
  unfold contextualChecksOrdered
  exact Bool.and_comm _ _

/-- **ConnectBlock check order** (validation.cpp:2378-2630), the block-validation module
normative composite: per-tx finality first, the block-level accumulators
(cofee? no — coinbase amount + fee range) after the whole loop. Failing
the per-tx phase fails the composite regardless of the accumulators. -/
def connectChecks (txs : List Tx) (cb : Tx) (l : List (OutPoint × Coin))
    (kf : Tx → Key) (height cutoff : UInt32) : Bool :=
  blockFinalityOk txs height cutoff &&
    (cbAmountOk cb (chainFeesL l kf txs height) height &&
      feeAccumInRange (chainFeesL l kf txs height))

/-- Per-tx phase first: a finality failure forces the composite false. -/
theorem connectChecks_finality_gate (txs : List Tx) (cb : Tx)
    (l : List (OutPoint × Coin)) (kf : Tx → Key) (height cutoff : UInt32)
    (hf : blockFinalityOk txs height cutoff = false) :
    connectChecks txs cb l kf height cutoff = false := by
  unfold connectChecks
  rw [hf]; rfl

/-! ## BLK-109 / INV-107 / BLK-110: the genesis connection -/

/-- The chain-parameter genesis block hash:
`params.GetConsensus().hashGenesisBlock` (kernel/chainparams.cpp:169-172,
derived from the pinned mainnet genesis header BLK-111). -/
@[rule "BLK-109", rule "INV-107", rule "BLK-110"]
def hashGenesisBlock : ByteArray :=
  headerHash Bitcoin.Block.Params.genesisHeader

/-- **BLK-109** genesis predicate: Core's `block_hash ==
params.GetConsensus().hashGenesisBlock` (validation.cpp:2337-2343). -/
@[rule "BLK-109", rule "INV-107", rule "BLK-110"]
def isGenesisHeader (h : Bitcoin.Chain.BlockHeader) : Bool :=
  bytesBEq (headerHash h) hashGenesisBlock

/-- The pinned mainnet genesis header satisfies the predicate.  The
digest itself is opaque to the kernel (SHA256d is a seam), so the
proof uses byte-equality reflexivity rather than evaluating the hash. -/
@[rule "BLK-109"]
theorem isGenesisHeader_genesisHeader :
    isGenesisHeader Bitcoin.Block.Params.genesisHeader = true := by
  unfold isGenesisHeader hashGenesisBlock
  exact bytesBEq_self _

/-- **BLK-109**: connecting the genesis block skips the tx fold entirely —
the state just records the block (its 50-COIN output never enters the
UTXO set, BLK-110).  This is the branch body; `connectBlock` is the
router that reaches it. -/
@[rule "BLK-109", rule "INV-107"]
def connectGenesis (utxo : List (OutPoint × Coin)) (h : Bitcoin.Chain.BlockHeader) :
    List (OutPoint × Coin) × ByteArray :=
  (utxo, headerHash h)

/-- Genesis connection leaves the UTXO set untouched — no coins are
created by the fold (the empty-set genesis state). -/
theorem connectGenesis_utxo_unchanged (utxo : List (OutPoint × Coin))
    (h : Bitcoin.Chain.BlockHeader) : (connectGenesis utxo h).1 = utxo := rfl

/-- The UTXO view plus committed best block that `ConnectBlock` writes. -/
structure ConnectState where
  utxo : List (OutPoint × Coin)
  bestBlock : Option ByteArray

/-- **BLK-109 / INV-107 / BLK-110** at the real call site
(validation.cpp:2337-2343): `ConnectBlock` tests the genesis hash BEFORE
the per-tx loop.  On genesis it returns through `connectGenesis` with the
UTXO set untouched and only the best block committed; every other block
runs the frozen executable `applyBlockExec` fold first and then commits
its hash. -/
@[rule "BLK-109", rule "INV-107", rule "BLK-110"]
def connectBlock (h : Bitcoin.Chain.BlockHeader) (txs : List Tx) (height : UInt32)
    (s : ConnectState) : Except BlockError ConnectState :=
  if isGenesisHeader h then
    let r := connectGenesis s.utxo h
    Except.ok { utxo := r.1, bestBlock := some r.2 }
  else
    match applyBlockExec s.utxo txs height with
    | Except.error e => Except.error e
    | Except.ok u => Except.ok { utxo := u, bestBlock := some (headerHash h) }

/-- **BLK-109 / INV-107**: the wired genesis branch returns before the tx
loop.  The result has the pre-state UTXO set and only the best block
updated; the transaction list is never consulted. -/
@[rule "BLK-109", rule "INV-107"]
theorem connectBlock_genesis (s : ConnectState)
    (h : Bitcoin.Chain.BlockHeader) (txs : List Tx) (height : UInt32)
    (hg : isGenesisHeader h = true) :
    connectBlock h txs height s =
      Except.ok { s with bestBlock := some (headerHash h) } := by
  simp [connectBlock, hg, connectGenesis]

/-- **BLK-109**: the genesis connection leaves the UTXO set unchanged and
sets `bestBlock` to the genesis header hash. -/
@[rule "BLK-109"]
theorem connectBlock_genesis_utxo_bestBlock (s : ConnectState)
    (h : Bitcoin.Chain.BlockHeader) (txs : List Tx) (height : UInt32)
    (hg : isGenesisHeader h = true) :
    ∃ s', connectBlock h txs height s = Except.ok s' ∧
      s'.utxo = s.utxo ∧ s'.bestBlock = some (headerHash h) := by
  refine ⟨_, connectBlock_genesis s h txs height hg, rfl, rfl⟩

/-- **INV-107**: no transaction is folded or connected on the genesis
branch — the post-state is independent of the block's transaction list. -/
@[rule "INV-107"]
theorem connectBlock_genesis_ignores_txs (s : ConnectState)
    (h : Bitcoin.Chain.BlockHeader) (txs txs' : List Tx) (height : UInt32)
    (hg : isGenesisHeader h = true) :
    connectBlock h txs height s = connectBlock h txs' height s := by
  rw [connectBlock_genesis s h txs height hg,
    connectBlock_genesis s h txs' height hg]

/-- **INV-107**: in particular the real genesis coinbase transaction is
not routed through `applyBlock` — connecting `[genesisCoinbaseTx]` has
the same state as connecting the empty transaction list. -/
@[rule "INV-107"]
theorem connectBlock_genesis_coinbase_not_connected (s : ConnectState)
    (height : UInt32) :
    connectBlock Bitcoin.Block.Params.genesisHeader
        [Bitcoin.Block.Params.genesisCoinbaseTx] height s =
      connectBlock Bitcoin.Block.Params.genesisHeader [] height s :=
  connectBlock_genesis_ignores_txs s _ _ _ height isGenesisHeader_genesisHeader

/-- **BLK-110** at the wired call site: connecting the real genesis block
from the pre-genesis empty view leaves the genesis 50-BTC coinbase output
absent from the post-state UTXO.  Contrast
`PDW68.genesis_applyBlock_output_present`, which is the non-genesis
`applyBlock` branch and therefore still inserts the coin. -/
@[rule "BLK-110"]
theorem connectBlock_genesis_coinbase_output_absent :
    ∃ s', connectBlock Bitcoin.Block.Params.genesisHeader
        [Bitcoin.Block.Params.genesisCoinbaseTx] 0
        { utxo := [], bestBlock := none } = Except.ok s' ∧
      viewOf s'.utxo (txidPreimageKey Bitcoin.Block.Params.genesisCoinbaseTx
        OutPoint.null (UInt32.ofNat 0)) = none := by
  refine ⟨_, connectBlock_genesis _ _ _ _ isGenesisHeader_genesisHeader, ?_⟩
  rfl

/-- The non-genesis branch is the real fold: it runs `applyBlockExec` and
only then commits the best block. -/
theorem connectBlock_nonGenesis (s : ConnectState)
    (h : Bitcoin.Chain.BlockHeader) (txs : List Tx) (height : UInt32)
    (hng : isGenesisHeader h = false) :
    connectBlock h txs height s =
      (match applyBlockExec s.utxo txs height with
       | Except.error e => Except.error e
       | Except.ok u => Except.ok { utxo := u, bestBlock := some (headerHash h) }) := by
  simp [connectBlock, hng]

/-! ## Axiom pins -/

#print axioms vtxCountWeightOk_iff
#print axioms blockFinalityOk_all
#print axioms blockFinalityOk_singleton
#print axioms blockSequenceLocksOk_all
#print axioms cbAmountOk_iff
#print axioms blockSubsidy_le_MAX_MONEY
#print axioms chainFeesL_feeAccumInRange
#print axioms coinbase_draw_le_subsidy_plus_fees
#print axioms merkleMutationFree_singleton
#print axioms merkleFailureKind_mutated_iff
#print axioms contextualChecksOrdered_swap
#print axioms connectChecks_finality_gate
#print axioms connectGenesis_utxo_unchanged
#print axioms isGenesisHeader_genesisHeader
#print axioms connectBlock_genesis
#print axioms connectBlock_genesis_utxo_bestBlock
#print axioms connectBlock_genesis_ignores_txs
#print axioms connectBlock_genesis_coinbase_output_absent
#print axioms connectBlock_nonGenesis

end Bitcoin.Block.Connect
