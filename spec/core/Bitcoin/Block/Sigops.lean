import Bitcoin.RuleAttr
import Bitcoin.Data.Tx
import Bitcoin.Ledger.Utxo
import Bitcoin.Interpreter.Defs
import Bitcoin.Interpreter.SigOps
import Bitcoin.TxValidation.SigOpsCost

/-!
# Bitcoin.Block.Sigops — signature-operation accounting (the block-validation module)

The block-level sigop budget (`src/policy/policy.cpp` `GetLegacySigOpCount`
/ `GetP2SHSigOpCount`, `src/consensus/tx_verify.cpp`
`GetTransactionSigOpCost`, enforced in `ConnectBlock` @`cce32b168`):

* **BLK-033** — `legacySigOpCountTx`: count `OP_CHECKSIG(VERIFY)` as 1 and
  `OP_CHECKMULTISIG(VERIFY)` as `MAX_PUBKEYS_PER_MULTISIG = 20`, over the
  scriptSigs **and** scriptPubKeys of every tx.
* **BLK-034** — the legacy block budget: Σ legacy sigops ×
  `WITNESS_SCALE_FACTOR ≤ MAX_BLOCK_SIGOPS_COST = 80000`
  (`bad-blk-sigops`). Static counting: a truncated push
  terminates the scan with the count accumulated so far, and witness
  sigops for future witness versions (v1+, taproot) are 0 — Core only
  counts those at script-execution time.
* **BLK-035** — the full sigop cost of one transaction:
  `cost = 4 × (legacy + P2SH) + witness`, where the P2SH redeem script
  and the v0-32 witness script use Core's accurate `GetSigOpCount(true)`
  count, the P2SH and witness terms exclude the coinbase (its prevout is
  not a real coin), and witness sigops weight 1, not 4 (BIP141).
* **BLK-036** — the cumulative budget during ConnectBlock:
  Σ `txSigOpCost` over `vtx ≤ 80000` (`bad-blk-sigops`).

The scanner mirrors `GetOp`'s push decoding (direct `OP_0..OP_75`,
`OP_PUSHDATA1/2/4` with little-endian lengths) so pushed data is skipped
rather than scanned for opcode look-alikes.
-/

namespace Bitcoin.Block.Sigops

open Bitcoin.Data
open Bitcoin.Ledger
open Bitcoin.Interpreter (isWitnessProgram)

/-! ## Constants -/

/-- `MAX_BLOCK_SIGOPS_COST` (consensus.h:27). -/
def MAX_BLOCK_SIGOPS_COST : Nat := 80000

/-- `WITNESS_SCALE_FACTOR` (consensus.h:23). -/
def WITNESS_SCALE_FACTOR : Nat := 4

/-- `MAX_PUBKEYS_PER_MULTISIG` (script.h): flat cost of one
`OP_CHECKMULTISIG(VERIFY)`. -/
def MAX_PUBKEYS_PER_MULTISIG : Nat := 20

/-! ## Generic fold plumbing (zero-dependency) -/

/-- If every summand is bounded by `c`, the fold is bounded by
`c × length`. -/
theorem foldl_const_le {α : Type} (xs : List α) (f : α → Nat) (c : Nat)
    (h : ∀ x, f x ≤ c) : xs.foldl (fun a x => a + f x) 0 ≤ c * xs.length := by
  have gen : ∀ ys : List α, ∀ acc : Nat,
      ys.foldl (fun a x => a + f x) acc ≤ acc + c * ys.length := by
    intro ys
    induction ys with
    | nil => intro acc; simpa using Nat.le_add_right acc _
    | cons y ys ih =>
      intro acc
      rw [List.foldl_cons, List.length_cons, Nat.mul_succ]
      have h1 : f y ≤ c := h y
      calc List.foldl (fun a x => a + f x) (acc + f y) ys
          ≤ (acc + f y) + c * ys.length := ih (acc + f y)
        _ ≤ (acc + c) + c * ys.length :=
            Nat.add_le_add_right (Nat.add_le_add (Nat.le_refl acc) h1) _
        _ = acc + (c * ys.length + c) := by
            rw [Nat.add_assoc, Nat.add_comm c (c * ys.length)]
  simpa using gen xs 0

/-- If every summand is 0, the fold is 0. -/
theorem foldl_add_zero {α : Type} (xs : List α) (f : α → Nat)
    (h : ∀ x, f x = 0) : xs.foldl (fun a x => a + f x) 0 = 0 := by
  induction xs with
  | nil => rfl
  | cons y ys ih => rw [List.foldl_cons, h y, ih]

/-- A `+`-fold redistributes over its starting accumulator. -/
theorem foldl_add_split {α : Type} (xs : List α) (f : α → Nat) :
    ∀ acc : Nat, xs.foldl (fun a x => a + f x) acc
      = acc + xs.foldl (fun a x => a + f x) 0 := by
  induction xs with
  | nil => intro acc; simp
  | cons y ys ih =>
    intro acc
    rw [List.foldl_cons, List.foldl_cons, ih (acc + f y), ih (0 + f y)]
    omega

/-! ## BLK-033: legacy sigop counting -/

/-- `GetLegacySigOpCount` over one script. -/
@[rule "BLK-033"]
def legacySigOpCountScript (s : Script) : Nat :=
  Bitcoin.Interpreter.SigOps.scriptSigOpCount s.bytes false

/-- Legacy sigop count of one transaction: scriptSigs + scriptPubKeys
(policy.cpp:107-130). -/
@[rule "BLK-033", rule "INV-035"]
def legacySigOpCountTx (tx : Tx) : Nat :=
  tx.vin.foldl (fun a i => a + legacySigOpCountScript i.scriptSig) 0 +
  tx.vout.foldl (fun a o => a + legacySigOpCountScript o.scriptPubKey) 0

/-- Block-level legacy count: every tx in `vtx`. -/
def legacySigOpCountBlock (vtx : List Tx) : Nat :=
  vtx.foldl (fun a t => a + legacySigOpCountTx t) 0

/-- The script byte-length of a transaction (for size-based bounds). -/
def txScriptBytes (tx : Tx) : Nat :=
  tx.vin.foldl (fun a i => a + i.scriptSig.bytes.size) 0 +
  tx.vout.foldl (fun a o => a + o.scriptPubKey.bytes.size) 0

/-! ## BLK-034: the legacy block budget -/

/-- The legacy block budget (`bad-blk-sigops`, validation.cpp:3979-3986):
Σ legacy sigops × `WITNESS_SCALE_FACTOR ≤ MAX_BLOCK_SIGOPS_COST`. -/
@[rule "BLK-034", rule "INV-040"]
def legacySigOpBudgetOk (vtx : List Tx) : Bool :=
  legacySigOpCountBlock vtx * WITNESS_SCALE_FACTOR ≤ MAX_BLOCK_SIGOPS_COST

/-! ## INV-035: theorem faces for the legacy-count row

The row's target was the definition alone. These theorems state the
counting policy: the tx count is the sum over scriptSigs + scriptPubKeys,
CHECKSIG(VERIFY) counts 1 and CHECKMULTISIG(VERIFY) counts the flat 20
(`fAccurate = false`, no pubkey-count parse), pushed data is skipped
(the scanner is `GetOp`-shaped, not an opcode grep), and the witness
never contributes. -/

/-- INV-035: the legacy count of a transaction is exactly the sum of the
per-script counts over its scriptSigs and scriptPubKeys. -/
@[rule "INV-035"]
theorem legacySigOpCountTx_eq_scriptSigs_add_scriptPubKeys (tx : Tx) :
    legacySigOpCountTx tx =
      (tx.vin.foldl (fun a i => a + legacySigOpCountScript i.scriptSig) 0) +
      (tx.vout.foldl (fun a o => a + legacySigOpCountScript o.scriptPubKey) 0) := rfl

/-- INV-035: witness data is outside the legacy count (`fAccurate = false`
and the scanner reads only scriptSig/scriptPubKey). -/
@[rule "INV-035"]
theorem legacySigOpCountTx_witness_independent (tx : Tx) (w : List WitnessStack) :
    legacySigOpCountTx { tx with witness := w } = legacySigOpCountTx tx := by
  cases tx
  rfl

/-- INV-035: the four sigop opcodes carry the flat weights — CHECKSIG and
CHECKSIGVERIFY count 1, CHECKMULTISIG and CHECKMULTISIGVERIFY count
`MAX_PUBKEYS_PER_MULTISIG = 20` regardless of the pubkey count operand. -/
@[rule "INV-035"]
theorem legacySigOpCountScript_weights :
    legacySigOpCountScript ⟨ByteArray.mk #[0xac]⟩ = 1 ∧
    legacySigOpCountScript ⟨ByteArray.mk #[0xad]⟩ = 1 ∧
    legacySigOpCountScript ⟨ByteArray.mk #[0xae]⟩ = 20 ∧
    legacySigOpCountScript ⟨ByteArray.mk #[0xaf]⟩ = 20 := by
  decide

/-- INV-035, no accurate parse: a `CHECKSIG` byte carried inside a direct
push is data, not an opcode — it is skipped (not counted). -/
@[rule "INV-035"]
theorem legacySigOpCountScript_pushed_checksig_ignored :
    legacySigOpCountScript ⟨ByteArray.mk #[0x01, 0xac]⟩ = 0 := by
  decide

/-- INV-035: the push is skipped and the following real opcode is counted
(the scan resumes after the pushed payload). -/
@[rule "INV-035"]
theorem legacySigOpCountScript_push_then_checksig :
    legacySigOpCountScript ⟨ByteArray.mk #[0x01, 0xac, 0xac]⟩ = 1 := by
  decide

/-- INV-035: counts compose additively on a push-free opcode run. -/
@[rule "INV-035"]
theorem legacySigOpCountScript_opcode_run :
    legacySigOpCountScript ⟨ByteArray.mk #[0xac, 0xac, 0xae]⟩ = 22 := by
  decide

/-- The legacy count of a script never exceeds
`20` per script byte (truncated pushes terminate the scan early). -/
theorem legacySigOpCountScript_le (s : Script) :
    legacySigOpCountScript s ≤ MAX_PUBKEYS_PER_MULTISIG * s.bytes.size := by
  exact Bitcoin.Interpreter.SigOps.scriptSigOpCount_inaccurate_le s.bytes

theorem legacySigOpCountBlock_append (a b : List Tx) :
    legacySigOpCountBlock (a ++ b) =
      legacySigOpCountBlock a + legacySigOpCountBlock b := by
  unfold legacySigOpCountBlock
  rw [List.foldl_append, foldl_add_split]

/-! ## BLK-035: P2SH and witness sigops -/

/-- `CScript::IsPayToScriptHash` (BIP16 template): 23 bytes,
`OP_HASH160 (0xa9) 0x14 <20-byte hash> OP_EQUAL (0x87)`. -/
def isP2SH (s : Script) : Bool :=
  s.bytes.size = 23 ∧ (s.bytes.get! 0).toNat = 0xa9 ∧
    (s.bytes.get! 1).toNat = 0x14 ∧ (s.bytes.get! 22).toNat = 0x87

/-- The last GetOp data register of a fully parsed push-only scriptSig.
Malformed pushes and any opcode above OP_16 return none. -/
def lastPush (s : Script) : Option ByteArray :=
  Bitcoin.Interpreter.SigOps.pushOnlyLastData s.bytes

/-- Core `CScript::GetSigOpCount(true)` over raw script bytes: parse the
wire and count CHECKSIG/CHECKMULTISIG with the OP_1..OP_16 lookback;
a malformed push stops counting and retains the valid prefix. -/
def accurateSigOpCountBytes (b : ByteArray) : Nat :=
  Bitcoin.Interpreter.SigOps.witnessScriptSigOps b

/-- `GetP2SHSigOpCount` (policy.cpp:132-160): for each **non-coinbase**
input whose prevout coin's scriptPubKey is P2SH, count legacy sigops in
the redeem script (the scriptSig's last data push). Missing coins count
0 — BIP16's "fail closed" is a script-verification concern, not a
counting one. -/
def p2shSigOpCount (u : UtxoSet) (tx : Tx) : Nat :=
  if tx.isCoinBase then 0
  else tx.vin.foldl (fun a i =>
    a + (match u i.prevout with
         | none => 0
         | some c =>
           if isP2SH c.scriptPubKey then
             match lastPush i.scriptSig with
             | none => 0
             | some r => accurateSigOpCountBytes r
           else 0)) 0

/-- Native and P2SH-wrapped witness programs share Core's counting arms.
Missing coins count zero here; transaction input checks precede this stage. -/
def witnessInputSigOps (u : UtxoSet) (i : TxIn) (w : WitnessStack) : Nat :=
  match u i.prevout with
  | none => 0
  | some c => Bitcoin.TxValidation.SigOpsCost.countWitnessSigOps
      i.scriptSig.bytes c.scriptPubKey.bytes w

/-- Every input is counted, including P2WPKH with an absent witness stack.
Coinbase transactions contribute only their legacy count. -/
def witnessSigOps (u : UtxoSet) (tx : Tx) : Nat :=
  if tx.isCoinBase then 0
  else Bitcoin.TxValidation.SigOpsCost.witnessSigOpsTx tx
    (fun o => (u o).map (fun c => c.scriptPubKey.bytes))

theorem p2shSigOpCount_coinbase_zero (u : UtxoSet) (tx : Tx)
    (h : tx.isCoinBase = true) : p2shSigOpCount u tx = 0 := by
  unfold p2shSigOpCount
  rw [if_pos h]

theorem witnessSigOps_coinbase_zero (u : UtxoSet) (tx : Tx)
    (h : tx.isCoinBase = true) : witnessSigOps u tx = 0 := by
  unfold witnessSigOps
  rw [if_pos h]

/-- The empty UTXO view (no coins at all). -/
def emptyUtxoScan : UtxoSet := fun _ => none

theorem p2shSigOpCount_none (tx : Tx) :
    p2shSigOpCount emptyUtxoScan tx = 0 := by
  unfold p2shSigOpCount
  split
  · rfl
  · apply foldl_add_zero
    intro i
    rfl

theorem witnessSigOps_none (tx : Tx) :
    witnessSigOps emptyUtxoScan tx = 0 := by
  unfold witnessSigOps
  split
  · rfl
  · unfold Bitcoin.TxValidation.SigOpsCost.witnessSigOpsTx
    have hz : ∀ n l, Bitcoin.TxValidation.SigOpsCost.witnessSigOpsTxFrom tx
        (fun _ => none) l n = 0 := by
      intro n l
      induction l generalizing n with
      | nil => rfl
      | cons i rest ih => exact ih (n+1)
    exact hz 0 tx.vin

/-- Future witness versions (v1+ — taproot & beyond) contribute 0 to the
block-level sigop budget; Core counts their sigops only at script
execution (BLK-034 under-counting by design, BIP342 §5). -/
theorem witnessInputSigOps_v1_zero (u : UtxoSet) (i : TxIn) (w : WitnessStack)
    (c : Coin) (hc : u i.prevout = some c) (v : Nat) (prog : ByteArray)
    (hp : isWitnessProgram c.scriptPubKey.bytes = some (v, prog)) (hv : v ≠ 0) :
    witnessInputSigOps u i w = 0 := by
  simp only [witnessInputSigOps, hc, Bitcoin.TxValidation.SigOpsCost.countWitnessSigOps, hp]
  exact Bitcoin.Interpreter.SigOps.witnessSigOps_future_zero v prog w (by omega)

/-! ## The full cost (BLK-035) and the connect-time budget (BLK-036) -/

/-- Cost with both optional lanes enabled. The block connector must use
`txSigOpCostWithFlags` with the actual block flags. This compatibility
helper also supports proofs of the all-enabled arithmetic decomposition.
`4 × (legacy + P2SH) + witness`. Witness sigops weight 1, not 4
(BIP141 §"sigop cost"). -/
@[rule "BLK-035"]
def txSigOpCost (u : UtxoSet) (tx : Tx) : Nat :=
  WITNESS_SCALE_FACTOR * (legacySigOpCountTx tx + p2shSigOpCount u tx) +
    witnessSigOps u tx

/-- Core GetTransactionSigOpCost: legacy always contributes; the P2SH
and witness terms require their respective script-verification flags.
Their counters are already zero for coinbase. Core's WITNESS ⇒ P2SH
flag invariant is supplied by the caller's GetBlockScriptFlags result. -/
def txSigOpCostWithFlags (u : UtxoSet) (tx : Tx)
    (flags : Bitcoin.Activation.ScriptFlags) : Nat :=
  WITNESS_SCALE_FACTOR *
    (legacySigOpCountTx tx + if flags.p2sh then p2shSigOpCount u tx else 0) +
    if flags.witness then witnessSigOps u tx else 0

theorem txSigOpCostWithFlags_enabled (u : UtxoSet) (tx : Tx)
    (flags : Bitcoin.Activation.ScriptFlags)
    (hp : flags.p2sh = true) (hw : flags.witness = true) :
    txSigOpCostWithFlags u tx flags = txSigOpCost u tx := by
  simp [txSigOpCostWithFlags, txSigOpCost, hp, hw]

theorem txSigOpCostWithFlags_coinbase (u : UtxoSet) (tx : Tx)
    (flags : Bitcoin.Activation.ScriptFlags) (hc : tx.isCoinBase = true) :
    txSigOpCostWithFlags u tx flags = 4 * legacySigOpCountTx tx := by
  simp [txSigOpCostWithFlags, p2shSigOpCount_coinbase_zero u tx hc,
    witnessSigOps_coinbase_zero u tx hc, WITNESS_SCALE_FACTOR]

/-- Cost decomposition pin (BLK-035). -/
theorem txSigOpCost_decompose (u : UtxoSet) (tx : Tx) :
    txSigOpCost u tx =
      WITNESS_SCALE_FACTOR * (legacySigOpCountTx tx + p2shSigOpCount u tx) +
        witnessSigOps u tx := rfl

/-- A transaction with no P2SH coins and no witness data costs exactly
4× its legacy count. -/
theorem txSigOpCost_legacy_only (u : UtxoSet) (tx : Tx)
    (hp : p2shSigOpCount u tx = 0) (hw : witnessSigOps u tx = 0) :
    txSigOpCost u tx = WITNESS_SCALE_FACTOR * legacySigOpCountTx tx := by
  rw [txSigOpCost_decompose, hp, hw, Nat.mul_add, Nat.mul_zero, Nat.add_zero]

/-- Over an empty UTXO view only the legacy term survives. -/
theorem txSigOpCost_none (tx : Tx) :
    txSigOpCost emptyUtxoScan tx
      = WITNESS_SCALE_FACTOR * legacySigOpCountTx tx := by
  rw [txSigOpCost_decompose, p2shSigOpCount_none, witnessSigOps_none,
    Nat.mul_add, Nat.mul_zero, Nat.add_zero]

/-- `ConnectBlock`'s cumulative budget (validation.cpp:2560-2568):
Σ `txSigOpCost` over `vtx ≤ MAX_BLOCK_SIGOPS_COST` (`bad-blk-sigops`). -/
@[rule "BLK-036"]
def blockSigOpCostOk (u : UtxoSet) (vtx : List Tx) : Bool :=
  vtx.foldl (fun a t => a + txSigOpCost u t) 0 ≤ MAX_BLOCK_SIGOPS_COST

end Bitcoin.Block.Sigops
