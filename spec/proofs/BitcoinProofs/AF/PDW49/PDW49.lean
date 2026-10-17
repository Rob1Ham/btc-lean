import Bitcoin.Block.Params
import Bitcoin.Block.Connect

/-! # PDW49.lean — proof-promotion review RC27, items TOP-161..165
(PDW49, 2026-10-17).

D-PARAMS c-true status-debt head of `Bitcoin/Block/Params.lean`:

* **INV-145** `prevNotFailed` — `bad-prevblk` parent gate: pass iff the
  parent is known and not BLOCK_FAILED_VALID.
* **INV-147** `minChainWorkOk` — headers-first anti-DoS gate: pass iff
  accumulated work ≥ mainnet `nMinimumChainWork`.
* **BLK-124** `scriptVerdicts` — serial verdicts = `map check`; any
  partition (CCheckQueue chunking) gives the same list.
* **BLK-109 / INV-107** `connectGenesis` — genesis connection skips tx
  connection: UTXO set unchanged, only the header hash is committed.

Route B: zero core writes, pins ⊆ [propext, Classical.choice, Quot.sound]. -/

namespace BitcoinProofs.AF.PDW49

open Bitcoin.Block.Params Bitcoin.Block.Connect Bitcoin.Data Bitcoin.Ledger Bitcoin.Capstone.Pow

/-- INV-145: the parent gate passes exactly on a known, non-failed parent. -/
@[rule "INV-145"]
theorem prevNotFailed_iff (idx : Nat → Option IndexEntry) (h : Nat) :
    prevNotFailed idx h = true ↔ ∃ e, idx h = some e ∧ e.failed = false := by
  unfold prevNotFailed
  cases idx h with
  | none => simp
  | some e => simp

/-- INV-145 reject lane: an unknown parent fails `prev-blk-not-found`. -/
@[rule "INV-145"]
theorem prevNotFailed_missing (idx : Nat → Option IndexEntry) (h : Nat)
    (hh : idx h = none) : prevNotFailed idx h = false := by
  simp [prevNotFailed, hh]

/-- INV-147: the chain-work gate is exactly `nMinimumChainWork ≤ work`. -/
@[rule "INV-147"]
theorem minChainWorkOk_iff (work : Nat) :
    minChainWorkOk work = true ↔ nMinimumChainWorkMainnet ≤ work := by
  unfold minChainWorkOk
  simp

/-- INV-147 reject lane: work below the mainnet minimum is rejected. -/
@[rule "INV-147"]
theorem minChainWorkOk_below (work : Nat) (h : work < nMinimumChainWorkMainnet) :
    minChainWorkOk work = false := by
  unfold minChainWorkOk
  simp only [decide_eq_false_iff_not]
  exact Nat.not_le.mpr h

/-- BLK-124: serial execution is the per-tx verdict map. -/
@[rule "BLK-124"]
theorem scriptVerdicts_serial (check : Tx → Bool) (vtx : List Tx) :
    scriptVerdicts check vtx = vtx.map check := rfl

/-- BLK-124: chunk boundaries do not change the verdict list. -/
@[rule "BLK-124"]
theorem scriptVerdicts_partition_face (check : Tx → Bool) (vtx : List Tx) (n : Nat) :
    scriptVerdicts check (vtx.take n ++ vtx.drop n) = scriptVerdicts check vtx :=
  scriptVerdicts_partition_invariant check vtx n

/-- BLK-124: concatenating two chunks concatenates their verdicts. -/
@[rule "BLK-124"]
theorem scriptVerdicts_append (check : Tx → Bool) (a b : List Tx) :
    scriptVerdicts check (a ++ b) = scriptVerdicts check a ++ scriptVerdicts check b := by
  simp [scriptVerdicts]

/-- BLK-124: a parallel script-check execution model. Each `CCheckQueue`
worker consumes one chunk independently and the coordinator concatenates
the per-chunk verdict lists in input order. -/
@[rule "BLK-124"]
def scriptVerdictsParallel (check : Tx → Bool) (chunks : List (List Tx)) : List Bool :=
  (chunks.map (fun c => scriptVerdicts check c)).flatten

/-- BLK-124: for ANY partition of `vtx` into worker chunks, parallel
verification returns exactly the serial verdict list. -/
@[rule "BLK-124"]
theorem scriptVerdictsParallel_eq_serial (check : Tx → Bool)
    (chunks : List (List Tx)) (vtx : List Tx) (h : chunks.flatten = vtx) :
    scriptVerdictsParallel check chunks = scriptVerdicts check vtx := by
  subst h
  unfold scriptVerdictsParallel scriptVerdicts
  induction chunks with
  | nil => rfl
  | cons c cs ih =>
    simp only [List.map_cons, List.flatten_cons, List.map_append, ih]

/-- BLK-124: the two-worker instance (`vtx.take n` / `vtx.drop n`) — the
concrete `CCheckQueue` split — has the serial verdict list. -/
@[rule "BLK-124"]
theorem scriptVerdictsParallel_two_workers (check : Tx → Bool) (vtx : List Tx)
    (n : Nat) :
    scriptVerdictsParallel check [vtx.take n, vtx.drop n] = scriptVerdicts check vtx :=
  scriptVerdictsParallel_eq_serial check [vtx.take n, vtx.drop n] vtx
    (by simp [List.take_append_drop])

/-- BLK-109: genesis connection leaves the UTXO set untouched. -/
@[rule "BLK-109"]
theorem connectGenesis_utxo_face (utxo : List (OutPoint × Coin))
    (h : Bitcoin.Chain.BlockHeader) : (connectGenesis utxo h).1 = utxo :=
  connectGenesis_utxo_unchanged utxo h

/-- INV-107: the genesis state commits only the genesis header hash. -/
@[rule "INV-107"]
theorem connectGenesis_hash_face (utxo : List (OutPoint × Coin))
    (h : Bitcoin.Chain.BlockHeader) : (connectGenesis utxo h).2 = headerHash h := rfl

/-! ## BLK-109 / INV-107: the full genesis state transition -/

/-- The connection state the genesis special case acts on: the UTXO set
plus the committed best-block hash. -/
structure GenesisState where
  utxo : List (OutPoint × Coin)
  bestBlock : Option ByteArray

/-- BLK-109: the genesis state transition, composing the frozen
`connectGenesis` (UTXO unchanged, header hash committed, no tx fold) with
the best-block write (`validation.cpp:2330-2334`). -/
@[rule "BLK-109", rule "INV-107"]
def connectGenesisState (s : GenesisState) (h : Bitcoin.Chain.BlockHeader) :
    GenesisState :=
  let r := connectGenesis s.utxo h
  { utxo := r.1, bestBlock := some r.2 }

/-- BLK-109: connecting genesis leaves the UTXO set untouched and sets the
best block to the genesis header hash — the two halves of the special case
in one conclusion. -/
@[rule "BLK-109"]
theorem connectGenesisState_utxo_bestBlock (s : GenesisState)
    (h : Bitcoin.Chain.BlockHeader) :
    (connectGenesisState s h).utxo = s.utxo ∧
    (connectGenesisState s h).bestBlock = some (headerHash h) := by
  dsimp only [connectGenesisState]
  rw [connectGenesis_utxo_unchanged, connectGenesis_hash_face]
  exact ⟨rfl, rfl⟩

/-- INV-107: connecting genesis skips the tx-connection fold entirely: the
post-state equals the pre-state with ONLY the best block updated (no coins
were created or spent). -/
@[rule "INV-107"]
theorem connectGenesisState_skips_tx_fold (s : GenesisState)
    (h : Bitcoin.Chain.BlockHeader) :
    connectGenesisState s h = { s with bestBlock := some (headerHash h) } := by
  dsimp only [connectGenesisState]
  rw [connectGenesis_utxo_unchanged, connectGenesis_hash_face]

/-! ## BLK-109 / INV-107: the wired genesis branch

The declarations above describe the branch body.  The following row faces
are stated at the real `Bitcoin.Block.Connect.connectBlock` router: the
genesis predicate `isGenesisHeader` selects `connectGenesis` BEFORE the
`applyBlockExec` fold, so the genesis transaction list is never connected. -/

/-- BLK-109 on the real connect path: the genesis predicate selects the
early-return branch, leaving the UTXO set unchanged and writing only the
best block. -/
@[rule "BLK-109"]
theorem connectBlock_genesis_utxo_bestBlock_wired
    (s : Bitcoin.Block.Connect.ConnectState) (h : Bitcoin.Chain.BlockHeader)
    (txs : List Tx) (height : UInt32)
    (hg : Bitcoin.Block.Connect.isGenesisHeader h = true) :
    ∃ s', Bitcoin.Block.Connect.connectBlock h txs height s = Except.ok s' ∧
      s'.utxo = s.utxo ∧ s'.bestBlock = some (headerHash h) :=
  Bitcoin.Block.Connect.connectBlock_genesis_utxo_bestBlock s h txs height hg

/-- INV-107 on the real connect path: the genesis branch returns before the
tx fold.  The post-state equals the pre-state with only `bestBlock`
updated — the block's transaction list is never consulted. -/
@[rule "INV-107"]
theorem connectBlock_genesis_skips_tx_fold_wired
    (s : Bitcoin.Block.Connect.ConnectState) (h : Bitcoin.Chain.BlockHeader)
    (txs : List Tx) (height : UInt32)
    (hg : Bitcoin.Block.Connect.isGenesisHeader h = true) :
    Bitcoin.Block.Connect.connectBlock h txs height s =
      Except.ok { s with bestBlock := some (headerHash h) } :=
  Bitcoin.Block.Connect.connectBlock_genesis s h txs height hg

/-- INV-107 on the real connect path: the actual genesis coinbase
transaction is not routed through the fold — connecting it yields exactly
the state of connecting the empty transaction list. -/
@[rule "INV-107"]
theorem connectBlock_genesis_coinbase_not_connected_wired
    (s : Bitcoin.Block.Connect.ConnectState) (height : UInt32) :
    Bitcoin.Block.Connect.connectBlock
        Bitcoin.Block.Params.genesisHeader
        [Bitcoin.Block.Params.genesisCoinbaseTx] height s =
      Bitcoin.Block.Connect.connectBlock
        Bitcoin.Block.Params.genesisHeader [] height s :=
  Bitcoin.Block.Connect.connectBlock_genesis_coinbase_not_connected s height

end BitcoinProofs.AF.PDW49
