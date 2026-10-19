import BitcoinProofs.Theorems.CapstonePowCor
import Bitcoin.Block.Pow
import Bitcoin.Block.Index
import Bitcoin.Block.Connect
import Bitcoin.Block.Sigops
import Bitcoin.Block.Params

/-!
# BitcoinProofs.Theorems.BlockCor — X08 block-layer consolidation (sorry-free)

Cross-module corollaries over the five X08 block modules
(`Bitcoin.Block.{Pow,Index,Connect,Sigops,Params}`): compositions that no
single module states, pinning the block rule family (BLK-*) closed at
130/130 implemented + tagged.

Highlights:

| theorem | statement |
|---|---|
| `genesis_pow_target_cap`  | the genesis target is strictly below the full mainnet powLimit (Params ∘ Pow) |
| `genesis_header_well_formed` | full genesis field pin + non-null (Params) |
| `workOf_genesis_eq`       | genesis work = the difficulty-1 GetBlockProof value (Index ∘ Params) |
| `txSigOpCost_ge_legacy`   | the full cost dominates 4× legacy (Sigops) |
| `txSigOpCost_emptyTx`     | an empty transaction costs 0 (Sigops) |
| `coinbase_sigop_cost_legacy_only` | a coinbase's cost is exactly 4× legacy — P2SH/witness terms vanish (Sigops) |
| `blockSigOpCostOk_of_per_tx_bound` | per-tx bounds × count ≤ 80000 ⇒ the block budget passes (Sigops fold law) |
| `legacySigOpBudgetOk_le_20000` | the legacy budget caps the raw count at 20000 (Sigops) |
| `genesis_blockSigOpCostOk` | the REAL genesis block passes the sigop budget over an empty UTXO view (Sigops ∘ Params; kernel-decided through the actual byte scan) |
| `betterThan_trans`        | the tip comparator is transitive (Index) |
| `chainWork_append_nil`    | appending nothing preserves accumulated work (Index) |
| `mostWork?_singleton`     | a single candidate always wins (Index) |
| `minChainWorkOk_of_ge`    | the DoS gate is upward-closed (Params) |
| `merklePathRoot_empty`    | the empty path replays to the leaf itself (Params) |

No Mathlib. Every theorem is sorry-free with axiom pins at the bottom
(`#guard_msgs` L3 discipline, X10 pattern).
-/

namespace BitcoinProofs.Theorems.BlockCor

open Bitcoin.Data
open Bitcoin.Ledger (UtxoSet Coin)
open Bitcoin.Block.Index
open Bitcoin.Block.Sigops
open Bitcoin.Block.Params

/-! ## Genesis block composition (Params ∘ Pow / Index) -/

/-- Genesis uses the rounded difficulty-one target, strictly below the full
mainnet consensus limit (BLK-040 ∘ BLK-111). -/
theorem genesis_pow_target_cap :
    Bitcoin.Chain.compactTarget genesisHeader.bits < Bitcoin.Block.Pow.powLimitMainnet := by
  rw [genesis_header_bits]
  exact Bitcoin.Block.Pow.difficultyOne_lt_powLimitMainnet

/-- Exact difficulty-one magnitude, distinct from the full chain parameter. -/
theorem genesis_pow_target_exact :
    Bitcoin.Chain.compactTarget genesisHeader.bits = 0xffff * 256 ^ 26 := by
  rw [genesis_header_bits]
  decide

/-- The full genesis header pin: version 1, the Times timestamp,
difficulty-1 nBits, the famous nonce — and not a null header (BLK-111 ∘
BLK-004). -/
theorem genesis_header_well_formed :
    genesisHeader.version = 1 ∧ genesisHeader.time = 1231006505 ∧
      genesisHeader.bits = 0x1d00ffff ∧ genesisHeader.nonce = 2083236893 ∧
      headerIsNull genesisHeader = false := by
  decide

/-- Genesis work equals the difficulty-1 `GetBlockProof` value
(BLK-113 ∘ BLK-111). -/
theorem workOf_genesis_eq :
    workOf genesisHeader.bits = workOf 0x1d00ffff := by
  rw [genesis_header_bits]

/-! ## Sigop cost composition (Sigops) -/

/-- The full sigop cost always dominates 4× the legacy count: the P2SH
and witness terms are nonnegative (BLK-035). -/
theorem txSigOpCost_ge_legacy (u : UtxoSet) (tx : Tx) :
    4 * legacySigOpCountTx tx ≤ txSigOpCost u tx := by
  have h := txSigOpCost_decompose u tx
  simp only [WITNESS_SCALE_FACTOR] at h
  omega

/-- An empty transaction costs nothing — no inputs, no outputs, no
witness (BLK-035 edge). -/
theorem txSigOpCost_emptyTx (u : UtxoSet) :
    txSigOpCost u (Tx.mk 0 [] [] 0 []) = 0 := by
  unfold txSigOpCost legacySigOpCountTx p2shSigOpCount witnessSigOps
  simp [Bitcoin.TxValidation.SigOpsCost.witnessSigOpsTx,
    Bitcoin.TxValidation.SigOpsCost.witnessSigOpsTxFrom]

/-- A coinbase's sigop cost is EXACTLY 4× its legacy count: both the P2SH
and witness terms exclude the coinbase by design (BLK-035 ∘ BLK-033). -/
theorem coinbase_sigop_cost_legacy_only (u : UtxoSet) (tx : Tx)
    (hcb : tx.isCoinBase = true) :
    txSigOpCost u tx = 4 * legacySigOpCountTx tx := by
  refine txSigOpCost_legacy_only u tx ?_ ?_
  · exact p2shSigOpCount_coinbase_zero u tx hcb
  · exact witnessSigOps_coinbase_zero u tx hcb

/-- Per-tx bound × tx count ≤ 80000 ⇒ the ConnectBlock budget passes
(BLK-036; the fold law `foldl_const_le` lifted to the block gate). -/
@[rule "BLK-036", rule "TXV-053"]
theorem blockSigOpCostOk_of_per_tx_bound (u : UtxoSet) (vtx : List Tx) (c : Nat)
    (hper : ∀ t, txSigOpCost u t ≤ c)
    (hbudget : vtx.length * c ≤ MAX_BLOCK_SIGOPS_COST) :
    blockSigOpCostOk u vtx = true := by
  unfold blockSigOpCostOk
  have hb2 : c * vtx.length ≤ MAX_BLOCK_SIGOPS_COST := by
    rw [Nat.mul_comm]; exact hbudget
  have h := foldl_const_le vtx (txSigOpCost u) c hper
  simp only [MAX_BLOCK_SIGOPS_COST] at h hb2 ⊢
  exact decide_eq_true (by omega)

/-- The legacy budget caps the raw sigop count at 20000 (BLK-034:
80000 / WITNESS_SCALE_FACTOR). -/
@[rule "BLK-034"]
theorem legacySigOpBudgetOk_le_20000 (vtx : List Tx)
    (h : legacySigOpBudgetOk vtx = true) : legacySigOpCountBlock vtx ≤ 20000 := by
  unfold legacySigOpBudgetOk at h
  simp only [WITNESS_SCALE_FACTOR, MAX_BLOCK_SIGOPS_COST] at h
  have h'' : legacySigOpCountBlock vtx * 4 ≤ 80000 := of_decide_eq_true h
  omega

/-- **BLK-034**: pass is exactly the ×4 gate `Σ legacy sigops × 4 ≤ 80,000`
(`bad-blk-sigops`, validation.cpp:3979-3986). -/
@[rule "BLK-034"]
theorem legacySigOpBudgetOk_iff (vtx : List Tx) :
    legacySigOpBudgetOk vtx = true ↔
      legacySigOpCountBlock vtx * 4 ≤ 80_000 := by
  unfold legacySigOpBudgetOk
  simp only [WITNESS_SCALE_FACTOR, MAX_BLOCK_SIGOPS_COST]
  exact decide_eq_true_iff

/-- **BLK-034** reject face: `legacySigOpBudgetOk = false` iff the ×4
budget is exceeded. -/
@[rule "BLK-034"]
theorem legacySigOpBudgetOk_eq_false_iff (vtx : List Tx) :
    legacySigOpBudgetOk vtx = false ↔ 80_000 < legacySigOpCountBlock vtx * 4 := by
  unfold legacySigOpBudgetOk
  rw [decide_eq_false_iff_not]
  simp only [WITNESS_SCALE_FACTOR, MAX_BLOCK_SIGOPS_COST]
  exact Nat.not_le

/-- **BLK-034** (under-counting by design): the legacy count is at most 20
per script byte — a truncated push terminates the scan with the count
accumulated so far. -/
@[rule "BLK-034"]
theorem legacySigOpCountScript_le_20_per_byte (s : Script) :
    legacySigOpCountScript s ≤ 20 * s.bytes.size := by
  simpa [MAX_PUBKEYS_PER_MULTISIG] using legacySigOpCountScript_le s

/-- **BLK-034** (under-counting by design): future witness versions (v1+,
taproot) contribute 0 to the block sigop budget; their sigops are priced
only at script-execution time (BIP342 §5). -/
@[rule "BLK-034"]
theorem witnessInputSigOps_future_version_zero (u : UtxoSet) (i : TxIn)
    (w : WitnessStack) (c : Coin) (hc : u i.prevout = some c)
    (v : Nat) (prog : ByteArray)
    (hp : Bitcoin.Interpreter.isWitnessProgram c.scriptPubKey.bytes = some (v, prog))
    (hv : v ≠ 0) : witnessInputSigOps u i w = 0 :=
  witnessInputSigOps_v1_zero u i w c hc v prog hp hv

/-- Auxiliary: the connect-time cost fold with an arbitrary accumulator. -/
theorem foldl_txSigOpCost_add (u : UtxoSet) (l : List Tx) (a : Nat) :
    l.foldl (fun acc t => acc + txSigOpCost u t) a =
      a + (l.map (txSigOpCost u)).sum := by
  induction l generalizing a with
  | nil => simp
  | cons t ts ih =>
    simp only [List.foldl_cons, List.map_cons, List.sum_cons]
    rw [ih (a + txSigOpCost u t)]
    omega

/-- **BLK-036/TXV-053**: the cumulative ConnectBlock sigop fold is the Σ
of per-tx costs. -/
@[rule "BLK-036", rule "TXV-053"]
theorem blockSigOpCost_fold_eq_sum (u : UtxoSet) (vtx : List Tx) :
    vtx.foldl (fun a t => a + txSigOpCost u t) 0 =
      (vtx.map (txSigOpCost u)).sum := by
  rw [foldl_txSigOpCost_add, Nat.zero_add]

/-- **BLK-036/TXV-053**: pass is exactly the fold gate
`Σ sigopCost ≤ 80,000` (`bad-blk-sigops`, validation.cpp:2563-2568). -/
@[rule "BLK-036", rule "TXV-053"]
theorem blockSigOpCostOk_iff (u : UtxoSet) (vtx : List Tx) :
    blockSigOpCostOk u vtx = true ↔
      vtx.foldl (fun a t => a + txSigOpCost u t) 0 ≤ 80_000 := by
  unfold blockSigOpCostOk
  simp only [MAX_BLOCK_SIGOPS_COST]
  exact decide_eq_true_iff

/-- **BLK-036/TXV-053**: the Σ form of the block sigop gate. -/
@[rule "BLK-036", rule "TXV-053"]
theorem blockSigOpCostOk_iff_sum (u : UtxoSet) (vtx : List Tx) :
    blockSigOpCostOk u vtx = true ↔
      (vtx.map (txSigOpCost u)).sum ≤ 80_000 := by
  rw [blockSigOpCostOk_iff, blockSigOpCost_fold_eq_sum]

/-- **BLK-036/TXV-053** reject face: `blockSigOpCostOk = false` iff the
Σ sigop cost exceeds 80,000 — exactly the `bad-blk-sigops` condition. -/
@[rule "BLK-036", rule "TXV-053"]
theorem blockSigOpCostOk_eq_false_iff (u : UtxoSet) (vtx : List Tx) :
    blockSigOpCostOk u vtx = false ↔
      80_000 < (vtx.map (txSigOpCost u)).sum := by
  unfold blockSigOpCostOk
  rw [decide_eq_false_iff_not]
  simp only [MAX_BLOCK_SIGOPS_COST]
  rw [blockSigOpCost_fold_eq_sum]
  exact Nat.not_le

set_option maxHeartbeats 1000000 in
/-- The REAL genesis block passes the cumulative ConnectBlock sigop
budget over an empty UTXO view — decided through the actual byte scan of
the genesis scriptSig (0 sigops: pushes only) and scriptPubKey (1
CHECKSIG), costing 4 (BLK-036 ∘ BLK-112). -/
theorem genesis_blockSigOpCostOk :
    blockSigOpCostOk emptyUtxoScan [genesisCoinbaseTx] = true := by
  unfold blockSigOpCostOk
  decide

/-! ## Tip-comparator laws (Index) -/

/-- `betterThan` is transitive (BLK-116): work dominates, and on the
tie-branch the sequence ids chain. -/
theorem betterThan_trans (a b c : Tip) (h1 : betterThan a b = true)
    (h2 : betterThan b c = true) : betterThan a c = true := by
  unfold betterThan at h1 h2 ⊢
  simp only [Bool.or_eq_true, decide_eq_true_eq, Bool.and_eq_true] at h1 h2
  rcases h1 with h1 | ⟨heq1, hseq1⟩
  · rcases h2 with h2 | ⟨heq2, hseq2⟩
    · have hg : a.chainWork > c.chainWork := Nat.lt_of_lt_of_le h2 (Nat.le_of_lt h1)
      simp [hg]
    · rw [heq2] at h1
      simp [h1]
  · rcases h2 with h2 | ⟨heq2, hseq2⟩
    · rw [← heq1] at h2
      simp [h2]
    · have ht : a.chainWork = c.chainWork ∧ a.sequence < c.sequence :=
        ⟨by rw [heq1, heq2], Nat.lt_trans hseq1 hseq2⟩
      simp [ht]

/-- Appending nothing preserves the accumulated chain work (BLK-114). -/
theorem chainWork_append_nil (xs : List UInt32) :
    chainWork (xs ++ []) = chainWork xs := by
  rw [chainWork_append]
  have h0 : chainWork [] = 0 := rfl
  omega

/-- A single candidate always wins the most-work selection (BLK-115
edge). -/
theorem mostWork?_singleton (t : Tip) : mostWork? [t] = some t := by
  simp [mostWork?]

/-! ## Parameter laws (Params) -/

/-- The min-chain-work DoS gate is upward-closed (BLK-122). -/
theorem minChainWorkOk_of_ge (w : Nat) (hw : nMinimumChainWorkMainnet ≤ w) :
    minChainWorkOk w = true := by
  unfold minChainWorkOk
  exact decide_eq_true hw

/-- The empty merkle path replays to the leaf itself (BLK-129 edge). -/
theorem merklePathRoot_empty (leaf : ByteArray) :
    merklePathRoot leaf [] = leaf := rfl

/-! ## Axiom pins (L3 discipline) — verbatim from #print axioms -/

/-- info: 'BitcoinProofs.Theorems.BlockCor.genesis_pow_target_cap' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms genesis_pow_target_cap
/-- info: 'BitcoinProofs.Theorems.BlockCor.genesis_header_well_formed' does not depend on any axioms -/
#guard_msgs in #print axioms genesis_header_well_formed
/-- info: 'BitcoinProofs.Theorems.BlockCor.workOf_genesis_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms workOf_genesis_eq
/-- info: 'BitcoinProofs.Theorems.BlockCor.txSigOpCost_ge_legacy' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms txSigOpCost_ge_legacy
/-- info: 'BitcoinProofs.Theorems.BlockCor.txSigOpCost_emptyTx' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms txSigOpCost_emptyTx
/-- info: 'BitcoinProofs.Theorems.BlockCor.coinbase_sigop_cost_legacy_only' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms coinbase_sigop_cost_legacy_only
/-- info: 'BitcoinProofs.Theorems.BlockCor.blockSigOpCostOk_of_per_tx_bound' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms blockSigOpCostOk_of_per_tx_bound
/-- info: 'BitcoinProofs.Theorems.BlockCor.legacySigOpBudgetOk_le_20000' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms legacySigOpBudgetOk_le_20000
/-- info: 'BitcoinProofs.Theorems.BlockCor.genesis_blockSigOpCostOk' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms genesis_blockSigOpCostOk
/-- info: 'BitcoinProofs.Theorems.BlockCor.betterThan_trans' depends on axioms: [propext] -/
#guard_msgs in #print axioms betterThan_trans
/-- info: 'BitcoinProofs.Theorems.BlockCor.chainWork_append_nil' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms chainWork_append_nil
/-- info: 'BitcoinProofs.Theorems.BlockCor.mostWork?_singleton' depends on axioms: [propext] -/
#guard_msgs in #print axioms mostWork?_singleton
/-- info: 'BitcoinProofs.Theorems.BlockCor.minChainWorkOk_of_ge' does not depend on any axioms -/
#guard_msgs in #print axioms minChainWorkOk_of_ge
/-- info: 'BitcoinProofs.Theorems.BlockCor.merklePathRoot_empty' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms merklePathRoot_empty

#print axioms legacySigOpBudgetOk_iff
#print axioms legacySigOpBudgetOk_eq_false_iff
#print axioms legacySigOpCountScript_le_20_per_byte
#print axioms witnessInputSigOps_future_version_zero
#print axioms blockSigOpCost_fold_eq_sum
#print axioms blockSigOpCostOk_iff
#print axioms blockSigOpCostOk_iff_sum
#print axioms blockSigOpCostOk_eq_false_iff

end BitcoinProofs.Theorems.BlockCor

-- R07c exact footprint guards.
/-- info: 'BitcoinProofs.Theorems.BlockCor.genesis_pow_target_exact' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.Theorems.BlockCor.genesis_pow_target_exact
