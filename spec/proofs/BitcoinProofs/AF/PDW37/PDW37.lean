import Bitcoin.Crypto.Taproot.Sighash

/-! # PDW37 — TOP-181..185: BIP341 transaction-level sub-hash belt.

Row-face theorems for `Bitcoin/Crypto/Taproot/Sighash.lean`:

* **TPR-034** `shaPrevouts`  — SHA256 of all input outpoints, in order.
* **TPR-035** `shaSpentAmounts` — SHA256 of the spent amounts (8-byte LE).
* **TPR-036** `shaSpentScripts` — SHA256 of the spent scriptPubKeys.
* **TPR-037** `shaSequences` — SHA256 of every input nSequence (¬ACP lane).
* **TPR-038** `shaOutputs` — SHA256 of the CTxOut serializations.

Honest tier: the promoted law is the byte-level coverage/order law and the
sigMsg inclusion gate. SHA256 preimage/collision resistance is the X02 seam
and is deliberately NOT claimed here. Zero core writes (route B). -/

namespace BitcoinProofs.AF.PDW37

open Bitcoin.Crypto.Taproot
open Bitcoin.Data
open Bitcoin.Crypto.Seam (ScriptExecutionData SigVersion)
open Bitcoin.Crypto.Seam.Hash (sha256_size)
open Bitcoin.Crypto.Seam.Hash.Sha256 (sha256)

/-- Generic append-fold decomposition (the serialization accumulator law). -/
theorem foldl_ser_append {α : Type} (g : α → ByteArray) (l : List α)
    (acc : ByteArray) :
    l.foldl (fun a x => a ++ g x) acc
      = acc ++ l.foldl (fun a x => a ++ g x) ByteArray.empty := by
  induction l generalizing acc with
  | nil => simp
  | cons x xs ih =>
      calc
        (x :: xs).foldl (fun a y => a ++ g y) acc
            = xs.foldl (fun a y => a ++ g y) (acc ++ g x) := by
              rw [List.foldl_cons]
        _ = (acc ++ g x) ++ xs.foldl (fun a y => a ++ g y) ByteArray.empty :=
              ih (acc ++ g x)
        _ = acc ++ (g x ++ xs.foldl (fun a y => a ++ g y) ByteArray.empty) := by
              rw [ByteArray.append_assoc]
        _ = acc ++ (x :: xs).foldl (fun a y => a ++ g y) ByteArray.empty := by
              rw [List.foldl_cons, ByteArray.empty_append, ih (g x)]

/-- Cons decomposition of the same fold. -/
theorem foldl_ser_cons {α : Type} (g : α → ByteArray) (x : α) (xs : List α) :
    (x :: xs).foldl (fun a y => a ++ g y) ByteArray.empty
      = g x ++ xs.foldl (fun a y => a ++ g y) ByteArray.empty := by
  rw [List.foldl_cons, ByteArray.empty_append, foldl_ser_append]

/-- TPR-034: `sha_prevouts` is SHA256 over the input outpoints, in vin order. -/
@[rule "TPR-034"]
theorem shaPrevouts_bytes (tx : Tx) :
    shaPrevouts tx = sha256
      (tx.vin.foldl (fun a i => a ++ serOutPoint i.prevout) ByteArray.empty) := rfl

/-- TPR-034 (decomposition): the first input's outpoint is the fold head. -/
@[rule "TPR-034"]
theorem shaPrevouts_cons (tx : Tx) (i : TxIn) (rest : List TxIn)
    (h : tx.vin = i :: rest) :
    shaPrevouts tx = sha256
      (serOutPoint i.prevout
        ++ rest.foldl (fun a j => a ++ serOutPoint j.prevout) ByteArray.empty) := by
  rw [shaPrevouts_bytes, h, foldl_ser_cons]

/-- TPR-034: the sub-hash is exactly 32 bytes (single SHA256). -/
@[rule "TPR-034"]
theorem shaPrevouts_width (tx : Tx) : (shaPrevouts tx).size = 32 := sha256_size _

/-- TPR-035: `sha_amounts` is SHA256 over the spent amounts, 8-byte LE each,
in spent-output order (the fee commitment input). -/
@[rule "TPR-035"]
theorem shaSpentAmounts_bytes (outs : List TxOut) :
    shaSpentAmounts outs = sha256
      (outs.foldl (fun a o =>
        a ++ serU64 (UInt64.ofNat (amtToU64 o.value))) ByteArray.empty) := rfl

/-- TPR-035 (decomposition): first amount is the serialization fold head. -/
@[rule "TPR-035"]
theorem shaSpentAmounts_cons (o : TxOut) (rest : List TxOut) :
    shaSpentAmounts (o :: rest) = sha256
      (serU64 (UInt64.ofNat (amtToU64 o.value))
        ++ rest.foldl (fun a x =>
          a ++ serU64 (UInt64.ofNat (amtToU64 x.value))) ByteArray.empty) := by
  rw [shaSpentAmounts_bytes, foldl_ser_cons]

/-- TPR-035: 32-byte sub-hash (single SHA256). -/
@[rule "TPR-035"]
theorem shaSpentAmounts_width (outs : List TxOut) :
    (shaSpentAmounts outs).size = 32 := sha256_size _

/-- TPR-036: `sha_scriptpubkeys` is SHA256 over CompactSize+script bytes,
in spent-output order. -/
@[rule "TPR-036"]
theorem shaSpentScripts_bytes (outs : List TxOut) :
    shaSpentScripts outs = sha256
      (outs.foldl (fun a o => a ++ serSpk o.scriptPubKey) ByteArray.empty) := rfl

/-- TPR-036 (decomposition): first scriptPubKey is the fold head. -/
@[rule "TPR-036"]
theorem shaSpentScripts_cons (o : TxOut) (rest : List TxOut) :
    shaSpentScripts (o :: rest) = sha256
      (serSpk o.scriptPubKey
        ++ rest.foldl (fun a x => a ++ serSpk x.scriptPubKey) ByteArray.empty) := by
  rw [shaSpentScripts_bytes, foldl_ser_cons]

/-- TPR-036: 32-byte sub-hash (single SHA256). -/
@[rule "TPR-036"]
theorem shaSpentScripts_width (outs : List TxOut) :
    (shaSpentScripts outs).size = 32 := sha256_size _

/-- TPR-037: `sha_sequences` is SHA256 over every input nSequence, 4-byte LE,
INCLUDING NONE/SINGLE hashtypes (the ¬ACP lane). -/
@[rule "TPR-037"]
theorem shaSequences_bytes (tx : Tx) :
    shaSequences tx = sha256
      (tx.vin.foldl (fun a i => a ++ serU32 i.sequence) ByteArray.empty) := rfl

/-- TPR-037 (decomposition): first nSequence is the fold head. -/
@[rule "TPR-037"]
theorem shaSequences_cons (tx : Tx) (i : TxIn) (rest : List TxIn)
    (h : tx.vin = i :: rest) :
    shaSequences tx = sha256
      (serU32 i.sequence
        ++ rest.foldl (fun a j => a ++ serU32 j.sequence) ByteArray.empty) := by
  rw [shaSequences_bytes, h, foldl_ser_cons]

/-- TPR-037: 32-byte sub-hash (single SHA256). -/
@[rule "TPR-037"]
theorem shaSequences_width (tx : Tx) : (shaSequences tx).size = 32 := sha256_size _

/-- TPR-038: `sha_outputs` is SHA256 over the CTxOut serializations, in
vout order. -/
@[rule "TPR-038"]
theorem shaOutputs_bytes (tx : Tx) :
    shaOutputs tx = sha256
      (tx.vout.foldl (fun a o => a ++ serTxOut o) ByteArray.empty) := rfl

/-- TPR-038 (decomposition): first output is the fold head. -/
@[rule "TPR-038"]
theorem shaOutputs_cons (tx : Tx) (o : TxOut) (rest : List TxOut)
    (h : tx.vout = o :: rest) :
    shaOutputs tx = sha256
      (serTxOut o ++ rest.foldl (fun a x => a ++ serTxOut x) ByteArray.empty) := by
  rw [shaOutputs_bytes, h, foldl_ser_cons]

/-- TPR-038: 32-byte sub-hash (single SHA256). -/
@[rule "TPR-038"]
theorem shaOutputs_width (tx : Tx) : (shaOutputs tx).size = 32 := sha256_size _

/-- TPR-038 (message face): in the ¬ACP lane the `sha_outputs` slot is
exactly gated by `output_type ∈ {ALL, DEFAULT}` (`htOutputAll`); NONE/SINGLE
leave it empty while the four ¬ACP sub-hashes above stay committed. -/
@[rule "TPR-038"]
theorem sigMsgTaproot_noAcp_outputs_gate
    (env : TapSighashEnv) (inPos : Nat) (ht : UInt8) (sv : SigVersion)
    (d : ScriptExecutionData) (a s e : ByteArray)
    (hg : sigMsgGate env inPos ht sv d = true) (hnot : htAcp ht = false)
    (ha : acpSlice env inPos ht = some a)
    (hs : singleSlice env inPos ht d = some s)
    (he : extSlice sv d = some e) :
    sigMsgTaproot env inPos ht sv d = some
      (serU8 ht ++ serU32 env.tx.version.toUInt32 ++ serU32 env.tx.locktime
        ++ (shaPrevouts env.tx ++ shaSpentAmounts env.spentOutputs
            ++ shaSpentScripts env.spentOutputs ++ shaSequences env.tx)
        ++ (if htOutputAll ht then shaOutputs env.tx else ByteArray.empty)
        ++ serU8 (spendType ((extFlagOf sv).getD 0) d.annexPresent)
        ++ a ++ (if d.annexPresent then d.annexHash else ByteArray.empty)
        ++ s ++ e) := by
  simp only [sigMsgTaproot, hg, hnot, Bool.not_false, ite_true, ha, hs, he]

/-- TPR-034 (message face): the message commits `shaPrevouts` as the first
of the four ¬ACP sub-hashes. -/
@[rule "TPR-034"]
theorem sigMsgTaproot_binds_prevouts
    (env : TapSighashEnv) (inPos : Nat) (ht : UInt8) (sv : SigVersion)
    (d : ScriptExecutionData) (a s e : ByteArray)
    (hg : sigMsgGate env inPos ht sv d = true) (hnot : htAcp ht = false)
    (ha : acpSlice env inPos ht = some a)
    (hs : singleSlice env inPos ht d = some s)
    (he : extSlice sv d = some e) :
    sigMsgTaproot env inPos ht sv d = some
      ((serU8 ht ++ serU32 env.tx.version.toUInt32 ++ serU32 env.tx.locktime)
        ++ shaPrevouts env.tx
        ++ (shaSpentAmounts env.spentOutputs ++ shaSpentScripts env.spentOutputs
            ++ shaSequences env.tx
            ++ (if htOutputAll ht then shaOutputs env.tx else ByteArray.empty)
            ++ serU8 (spendType ((extFlagOf sv).getD 0) d.annexPresent)
            ++ a ++ (if d.annexPresent then d.annexHash else ByteArray.empty)
            ++ s ++ e)) := by
  simpa only [ByteArray.append_assoc] using
    sigMsgTaproot_noAcp_outputs_gate env inPos ht sv d a s e hg hnot ha hs he

/-- TPR-035 (message face): the spent-amount commitment (`shaSpentAmounts`,
the fee-binding input) follows `shaPrevouts` in the ¬ACP block. -/
@[rule "TPR-035"]
theorem sigMsgTaproot_binds_amounts
    (env : TapSighashEnv) (inPos : Nat) (ht : UInt8) (sv : SigVersion)
    (d : ScriptExecutionData) (a s e : ByteArray)
    (hg : sigMsgGate env inPos ht sv d = true) (hnot : htAcp ht = false)
    (ha : acpSlice env inPos ht = some a)
    (hs : singleSlice env inPos ht d = some s)
    (he : extSlice sv d = some e) :
    sigMsgTaproot env inPos ht sv d = some
      ((serU8 ht ++ serU32 env.tx.version.toUInt32 ++ serU32 env.tx.locktime
          ++ shaPrevouts env.tx)
        ++ shaSpentAmounts env.spentOutputs
        ++ (shaSpentScripts env.spentOutputs ++ shaSequences env.tx
            ++ (if htOutputAll ht then shaOutputs env.tx else ByteArray.empty)
            ++ serU8 (spendType ((extFlagOf sv).getD 0) d.annexPresent)
            ++ a ++ (if d.annexPresent then d.annexHash else ByteArray.empty)
            ++ s ++ e)) := by
  simpa only [ByteArray.append_assoc] using
    sigMsgTaproot_noAcp_outputs_gate env inPos ht sv d a s e hg hnot ha hs he

/-- TPR-036 (message face): the spent-scriptPubKey commitment follows the
amount commitment in the ¬ACP block. -/
@[rule "TPR-036"]
theorem sigMsgTaproot_binds_scripts
    (env : TapSighashEnv) (inPos : Nat) (ht : UInt8) (sv : SigVersion)
    (d : ScriptExecutionData) (a s e : ByteArray)
    (hg : sigMsgGate env inPos ht sv d = true) (hnot : htAcp ht = false)
    (ha : acpSlice env inPos ht = some a)
    (hs : singleSlice env inPos ht d = some s)
    (he : extSlice sv d = some e) :
    sigMsgTaproot env inPos ht sv d = some
      ((serU8 ht ++ serU32 env.tx.version.toUInt32 ++ serU32 env.tx.locktime
          ++ shaPrevouts env.tx ++ shaSpentAmounts env.spentOutputs)
        ++ shaSpentScripts env.spentOutputs
        ++ (shaSequences env.tx
            ++ (if htOutputAll ht then shaOutputs env.tx else ByteArray.empty)
            ++ serU8 (spendType ((extFlagOf sv).getD 0) d.annexPresent)
            ++ a ++ (if d.annexPresent then d.annexHash else ByteArray.empty)
            ++ s ++ e)) := by
  simpa only [ByteArray.append_assoc] using
    sigMsgTaproot_noAcp_outputs_gate env inPos ht sv d a s e hg hnot ha hs he

/-- TPR-037 (message face): every input nSequence is committed in the ¬ACP
block — including NONE/SINGLE hashtypes (BIP341's divergence from BIP143). -/
@[rule "TPR-037"]
theorem sigMsgTaproot_binds_sequences
    (env : TapSighashEnv) (inPos : Nat) (ht : UInt8) (sv : SigVersion)
    (d : ScriptExecutionData) (a s e : ByteArray)
    (hg : sigMsgGate env inPos ht sv d = true) (hnot : htAcp ht = false)
    (ha : acpSlice env inPos ht = some a)
    (hs : singleSlice env inPos ht d = some s)
    (he : extSlice sv d = some e) :
    sigMsgTaproot env inPos ht sv d = some
      ((serU8 ht ++ serU32 env.tx.version.toUInt32 ++ serU32 env.tx.locktime
          ++ shaPrevouts env.tx ++ shaSpentAmounts env.spentOutputs
          ++ shaSpentScripts env.spentOutputs)
        ++ shaSequences env.tx
        ++ ((if htOutputAll ht then shaOutputs env.tx else ByteArray.empty)
            ++ serU8 (spendType ((extFlagOf sv).getD 0) d.annexPresent)
            ++ a ++ (if d.annexPresent then d.annexHash else ByteArray.empty)
            ++ s ++ e)) := by
  simpa only [ByteArray.append_assoc] using
    sigMsgTaproot_noAcp_outputs_gate env inPos ht sv d a s e hg hnot ha hs he

/-! ## Axiom pins (charter trio; zero sorryAx) -/

/-- info: 'BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_prevouts' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_prevouts

/-- info: 'BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_amounts' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_amounts

/-- info: 'BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_scripts' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_scripts

/-- info: 'BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_sequences' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW37.sigMsgTaproot_binds_sequences

/-- info: 'BitcoinProofs.AF.PDW37.sigMsgTaproot_noAcp_outputs_gate' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW37.sigMsgTaproot_noAcp_outputs_gate

/-- info: 'BitcoinProofs.AF.PDW37.shaPrevouts_width' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW37.shaPrevouts_width

/-- info: 'BitcoinProofs.AF.PDW37.shaSpentAmounts_cons' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW37.shaSpentAmounts_cons

end BitcoinProofs.AF.PDW37
