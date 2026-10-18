import Bitcoin.Block.Sigops
import Bitcoin.Interpreter.Rules

/-! # PDW29Sigops.lean — TOP-141..145, Sigops pair BLK-033 / BLK-035

Route B: zero core writes; tags ride the theorems below.
BLK-033 = `GetLegacySigOpCount` (tx_verify.cpp:118-130); BLK-035 =
`GetTransactionSigOpCost` (tx_verify.cpp:149-168).

The interpreter, transaction and block layers share the raw script
counter. Malformed scripts retain their valid prefix; P2SH scriptSigs
must parse fully and be push-only; witness input indexing does not
truncate at a missing witness stack. Activation flags and the live
cumulative block budget remain separate caller-side checks.
-/

namespace BitcoinProofs.AF.PDW29

open Bitcoin.Block.Sigops

/-! ## BLK-033 — legacy sigop count -/

/-- The row's exact composition: scriptSig fold + scriptPubKey fold. -/
@[rule "BLK-033"]
theorem legacySigOpCountTx_eq (tx : Bitcoin.Data.Tx) :
    legacySigOpCountTx tx =
      tx.vin.foldl (fun a i => a + legacySigOpCountScript i.scriptSig) 0 +
      tx.vout.foldl (fun a o => a + legacySigOpCountScript o.scriptPubKey) 0 := rfl

/-- Under-counting bound: at most `MAX_PUBKEYS_PER_MULTISIG` per script
byte (truncated pushes end the scan early; BLK-034 design). -/
@[rule "BLK-033"]
theorem legacySigOpCountScript_bound (s : Bitcoin.Data.Script) :
    legacySigOpCountScript s ≤ 20 * s.bytes.size := by
  simpa [MAX_PUBKEYS_PER_MULTISIG] using legacySigOpCountScript_le s

/-- 1-in/1-out witness-free tx with raw script bytes (vector carrier). -/
private def sigTx (s1 s2 : ByteArray) : Bitcoin.Data.Tx :=
  Bitcoin.Data.Tx.mk 1
    [⟨Bitcoin.Data.OutPoint.null, ⟨s1⟩, 0xffffffff⟩]
    [⟨0, ⟨s2⟩⟩] 0 []

/-- INV-035/BLK-033 vector: `OP_CHECKSIGVERIFY` (0xad) in the scriptSig = 1,
`OP_CHECKMULTISIG` (0xae) in the scriptPubKey = 20 ⇒ 21. -/
@[rule "BLK-033"]
theorem legacySigOpCountTx_row_vector :
    legacySigOpCountTx (sigTx (ByteArray.mk #[0xad]) (ByteArray.mk #[0xae])) = 21 := by
  decide

/-! ## BLK-033 — general scanned-opcode weight/count characterization -/

/-- The wire opcodes actually visited by the `GetOp`-shaped scan, in order
(push payloads are skipped). -/
def scanOps (b : ByteArray) (fuel i : Nat) : List Nat :=
  (Bitcoin.Interpreter.SigOps.parseWirePrefixFrom fuel b i).map (·.wire)

/-- Flat sigop weight of one scanned opcode (`CountSigOps`,
policy.cpp:83-93): CHECKSIG/CHECKSIGVERIFY = 1,
CHECKMULTISIG/CHECKMULTISIGVERIFY = `MAX_PUBKEYS_PER_MULTISIG` = 20. -/
def sigOpWeight (op : Nat) : Nat :=
  if op = 0xac then 1
  else if op = 0xad then 1
  else if op = 0xae then 20
  else if op = 0xaf then 20
  else 0

theorem MAX_PUBKEYS_PER_MULTISIG_eq : MAX_PUBKEYS_PER_MULTISIG = 20 := rfl

private theorem inaccurate_eq_weight_fold (ops : List Bitcoin.Interpreter.WireOp) :
    Bitcoin.Interpreter.SigOps.inaccurateSigOpCount ops =
      (ops.map (·.wire)).foldl (fun a op => a + sigOpWeight op) 0 := by
  induction ops with
  | nil => rfl
  | cons o rest ih =>
    simp only [Bitcoin.Interpreter.SigOps.inaccurateSigOpCount, List.map_cons, List.foldl_cons]
    rw [foldl_add_split]
    rw [ih]
    simp only [Nat.zero_add]
    unfold sigOpWeight Bitcoin.Interpreter.SigOps.isCheckSigWire
      Bitcoin.Interpreter.SigOps.isCheckMultiSigWire
    by_cases h1 : o.wire = 0xac <;> by_cases h2 : o.wire = 0xad <;>
      by_cases h3 : o.wire = 0xae <;> by_cases h4 : o.wire = 0xaf <;>
      simp [h1, h2, h3, h4, Bitcoin.Interpreter.MAX_PUBKEYS_PER_MULTISIG]

/-- One script's legacy count is the total flat weight of its scanned
opcodes. -/
theorem legacySigOpCountScript_eq_weight_sum (s : Bitcoin.Data.Script) :
    legacySigOpCountScript s =
      (scanOps s.bytes (s.bytes.size+1) 0).foldl
        (fun a op => a + sigOpWeight op) 0 := by
  exact inaccurate_eq_weight_fold (Bitcoin.Interpreter.SigOps.parseWirePrefix s.bytes)

/-- Number of occurrences of one wire byte among the scanned opcodes. -/
def countOp (op : Nat) : List Nat → Nat
  | [] => 0
  | x :: xs => (if x = op then 1 else 0) + countOp op xs

theorem foldl_weight_eq_counts_aux (ls : List Nat) (acc : Nat) :
    ls.foldl (fun a op => a + sigOpWeight op) acc =
      acc + countOp 0xac ls + countOp 0xad ls +
        20 * (countOp 0xae ls + countOp 0xaf ls) := by
  induction ls generalizing acc with
  | nil => simp [countOp]
  | cons x xs ih =>
    rw [List.foldl_cons, ih]
    simp only [countOp, sigOpWeight]
    by_cases h1 : x = 0xac <;> by_cases h2 : x = 0xad <;>
      by_cases h3 : x = 0xae <;> by_cases h4 : x = 0xaf <;>
      simp [h1, h2, h3, h4] <;> omega

theorem foldl_weight_eq_counts (ls : List Nat) :
    ls.foldl (fun a op => a + sigOpWeight op) 0 =
      countOp 0xac ls + countOp 0xad ls +
        20 * (countOp 0xae ls + countOp 0xaf ls) := by
  simpa using foldl_weight_eq_counts_aux ls 0

/-- **BLK-033** (general): over the opcodes a `GetOp`-shaped scan actually
visits, the legacy count is `#CHECKSIG + #CHECKSIGVERIFY +
20·(#CHECKMULTISIG + #CHECKMULTISIGVERIFY)`. Pushed data is skipped, so
opcode-lookalikes inside pushes are not counted. -/
@[rule "BLK-033"]
theorem legacySigOpCountScript_eq_counts (s : Bitcoin.Data.Script) :
    legacySigOpCountScript s =
      countOp 0xac (scanOps s.bytes (s.bytes.size+1) 0) +
      countOp 0xad (scanOps s.bytes (s.bytes.size+1) 0) +
      20 * (countOp 0xae (scanOps s.bytes (s.bytes.size+1) 0) +
            countOp 0xaf (scanOps s.bytes (s.bytes.size+1) 0)) := by
  rw [legacySigOpCountScript_eq_weight_sum, foldl_weight_eq_counts]

/-- **BLK-033** (tx level): the same weighted count, independently over
every scriptSig and every scriptPubKey of the transaction. -/
@[rule "BLK-033"]
theorem legacySigOpCountTx_eq_counts (tx : Bitcoin.Data.Tx) :
    legacySigOpCountTx tx =
      (tx.vin.foldl (fun a i =>
        a + (countOp 0xac (scanOps i.scriptSig.bytes (i.scriptSig.bytes.size+1) 0) +
             countOp 0xad (scanOps i.scriptSig.bytes (i.scriptSig.bytes.size+1) 0) +
             20 * (countOp 0xae (scanOps i.scriptSig.bytes (i.scriptSig.bytes.size+1) 0) +
                   countOp 0xaf (scanOps i.scriptSig.bytes (i.scriptSig.bytes.size+1) 0)))) 0) +
      (tx.vout.foldl (fun a o =>
        a + (countOp 0xac (scanOps o.scriptPubKey.bytes (o.scriptPubKey.bytes.size+1) 0) +
             countOp 0xad (scanOps o.scriptPubKey.bytes (o.scriptPubKey.bytes.size+1) 0) +
             20 * (countOp 0xae (scanOps o.scriptPubKey.bytes (o.scriptPubKey.bytes.size+1) 0) +
                   countOp 0xaf (scanOps o.scriptPubKey.bytes (o.scriptPubKey.bytes.size+1) 0)))) 0) := by
  unfold legacySigOpCountTx
  simp only [legacySigOpCountScript_eq_counts]

theorem sigOpWeight_spec :
    sigOpWeight 0xac = 1 ∧ sigOpWeight 0xad = 1 ∧
    sigOpWeight 0xae = 20 ∧ sigOpWeight 0xaf = 20 := by
  decide

/-! ## BLK-035 — full sigop cost -/

/-- Cost decomposition (block model): `4 × (legacy + P2SH) + witness`
(witness weight 1). The P2SH/witness terms use the accurate count; the
legacy term is the flat BLK-033 scan. -/
@[rule "BLK-035"]
theorem txSigOpCost_decompose_row (u : Bitcoin.Ledger.UtxoSet) (tx : Bitcoin.Data.Tx) :
    txSigOpCost u tx =
      4 * (legacySigOpCountTx tx + p2shSigOpCount u tx) + witnessSigOps u tx := by
  rw [txSigOpCost_decompose]
  simp [WITNESS_SCALE_FACTOR]

/-- **BLK-035 accuracy witness**: the canonical P2SH redeem script
`OP_1 OP_CHECKMULTISIG` counts 20 under the flat legacy scan
(`fAccurate = false`) and 1 under the block model's accurate
P2SH/witness counter, which decodes the preceding `OP_1` exactly like
Core's `GetSigOpCount(true)`. -/
@[rule "BLK-035"]
theorem p2sh_accurate_vs_flat_witness :
    legacySigOpCountScript ⟨ByteArray.mk #[0x51, 0xae]⟩ = 20 ∧
    accurateSigOpCountBytes (ByteArray.mk #[0x51, 0xae]) = 1 := by
  decide

/-- Coinbase: P2SH and witness terms are excluded ⇒ exactly 4×legacy. -/
@[rule "BLK-035"]
theorem txSigOpCost_coinbase_legacy (u : Bitcoin.Ledger.UtxoSet) (tx : Bitcoin.Data.Tx)
    (hcb : tx.isCoinBase = true) :
    txSigOpCost u tx = 4 * legacySigOpCountTx tx := by
  rw [txSigOpCost_decompose, p2shSigOpCount_coinbase_zero u tx hcb,
    witnessSigOps_coinbase_zero u tx hcb]
  simp [WITNESS_SCALE_FACTOR]

/-- The nonnegative P2SH/witness terms make cost dominate 4×legacy. -/
@[rule "BLK-035"]
theorem txSigOpCost_ge_legacy (u : Bitcoin.Ledger.UtxoSet) (tx : Bitcoin.Data.Tx) :
    4 * legacySigOpCountTx tx ≤ txSigOpCost u tx := by
  have h4 : WITNESS_SCALE_FACTOR = 4 := rfl
  rw [txSigOpCost_decompose, h4]
  omega

/-- BLK-035 vector: the 21-sigop witness-free tx over an empty UTXO view
costs 4 × 21 = 84. -/
@[rule "BLK-035"]
theorem txSigOpCost_row_vector :
    txSigOpCost emptyUtxoScan (sigTx (ByteArray.mk #[0xad]) (ByteArray.mk #[0xae])) = 84 := by
  rw [txSigOpCost_none, legacySigOpCountTx_row_vector]
  simp [WITNESS_SCALE_FACTOR]

end BitcoinProofs.AF.PDW29
