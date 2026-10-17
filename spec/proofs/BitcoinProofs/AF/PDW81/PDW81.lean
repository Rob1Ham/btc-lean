import Bitcoin.TxValidation.Full

/-! # PDW81 — TOP-426..430 (claim `5ca3f3a`)

Route B: proofs-side row faces, zero core writes.
TXV-072 (coinbase exemption) + the three signature/pubkey encoding gates
INV-053 `checkLowS`, INV-054 `checkPubKeyEncoding`, SCR-105
`isDefinedHashtype`, plus INV-046 `checkMinimalPush`.

Pins target: ⊆ `[propext, Classical.choice, Quot.sound]`.
-/

namespace BitcoinProofs.AF.PDW81

open Bitcoin.Interpreter

/-! ## TXV-072 — coinbases are exempt from input checks -/

/-- **TXV-072**: a coinbase that clears the stateless prefix and
`IsFinalTx` validates with fee `0`, never touching `HaveInputs`/
`CheckTxInputs` (validation.cpp:2556 early-exit). -/
@[rule "TXV-072"]
theorem validateTx_coinbase_ok (tx : Bitcoin.Data.Tx)
    (u : Bitcoin.Ledger.UtxoSet) (height mtp : UInt32)
    (flags : Bitcoin.Activation.ScriptFlags)
    (hc : Bitcoin.Consensus.checkTransaction tx = none)
    (hfin : Bitcoin.DataLaws.isFinalTx tx height mtp = true)
    (hcb : tx.isCoinBase = true) :
    Bitcoin.TxValidation.validateTx tx u height mtp flags = .ok 0 := by
  unfold Bitcoin.TxValidation.validateTx
  rw [hc, if_pos hfin, if_pos hcb]

/-- **TXV-072** (exemption law): for a coinbase the verdict is independent
of the UTXO view — the input-check lane is unreachable. -/
@[rule "TXV-072"]
theorem validateTx_coinbase_utxo_indep (tx : Bitcoin.Data.Tx)
    (u u' : Bitcoin.Ledger.UtxoSet) (height mtp : UInt32)
    (flags : Bitcoin.Activation.ScriptFlags)
    (hc : Bitcoin.Consensus.checkTransaction tx = none)
    (hfin : Bitcoin.DataLaws.isFinalTx tx height mtp = true)
    (hcb : tx.isCoinBase = true) :
    Bitcoin.TxValidation.validateTx tx u height mtp flags =
      Bitcoin.TxValidation.validateTx tx u' height mtp flags := by
  rw [validateTx_coinbase_ok tx u height mtp flags hc hfin hcb,
    validateTx_coinbase_ok tx u' height mtp flags hc hfin hcb]

/-! ## INV-046 — `CheckMinimalPush` (BIP62, script.cpp) -/

/-- **INV-046** (empty operand): only `OP_0` is minimal. -/
@[rule "INV-046"]
theorem checkMinimalPush_empty (opcode : Nat) :
    checkMinimalPush .empty opcode = true ↔ opcode = 0 := by
  simp [checkMinimalPush]

/-- **INV-046** (1-byte operand): a 1..16 value must use `OP_1..16` and
`0x81` must use `OP_1NEGATE`, so the direct `0x01` push is non-minimal. -/
@[rule "INV-046"]
theorem checkMinimalPush_one_small (data : ByteArray)
    (hs : data.size = 1) (hv : 1 ≤ (data.get! 0).toNat ∧ (data.get! 0).toNat ≤ 16) :
    checkMinimalPush data 1 = false := by
  unfold checkMinimalPush
  rw [if_neg (by omega), if_pos (by exact ⟨hs, hv⟩)]

/-- **INV-046** (`0x81` operand): `OP_1NEGATE` is the only minimal push. -/
@[rule "INV-046"]
theorem checkMinimalPush_one_neg (data : ByteArray)
    (hs : data.size = 1) (hv : (data.get! 0).toNat = 0x81) :
    checkMinimalPush data 1 = false := by
  unfold checkMinimalPush
  have h1 : ¬ (data.size = 1 ∧ 1 ≤ (data.get! 0).toNat ∧ (data.get! 0).toNat ≤ 16) := by
    intro h; omega
  rw [if_neg (by omega), if_neg h1, if_pos (by exact ⟨hs, hv⟩)]

/-- **INV-046**: exact BIP62 acceptance characterization for operands of
at least 2 bytes: direct push for 2..75, `OP_PUSHDATA1` for 76..255,
`OP_PUSHDATA2` for 256..65535, and anything minimal above that. -/
@[rule "INV-046"]
theorem checkMinimalPush_iff (data : ByteArray) (opcode : Nat)
    (h2 : 2 ≤ data.size) :
    checkMinimalPush data opcode = true ↔
      (data.size ≤ 75 ∧ opcode = data.size) ∨
      (76 ≤ data.size ∧ data.size ≤ 0xff ∧ opcode = 0x4c) ∨
      (0x100 ≤ data.size ∧ data.size ≤ 0xffff ∧ opcode = 0x4d) ∨
      0xffff < data.size := by
  unfold checkMinimalPush
  have hs0 : data.size ≠ 0 := by omega
  have hs1 : data.size ≠ 1 := by omega
  rw [if_neg (by omega)]
  have h1 : ¬ (data.size = 1 ∧ 1 ≤ (data.get! 0).toNat ∧ (data.get! 0).toNat ≤ 16) := by
    intro h; omega
  have h2' : ¬ (data.size = 1 ∧ (data.get! 0).toNat = 0x81) := by
    intro h; omega
  rw [if_neg h1, if_neg h2']
  by_cases h75 : data.size ≤ 75
  · rw [if_pos h75]
    have h76 : ¬ 76 ≤ data.size := by omega
    have h256 : ¬ 0x100 ≤ data.size := by omega
    have hbig : ¬ 0xffff < data.size := by omega
    constructor
    · intro hop; exact Or.inl ⟨h75, by simpa using hop⟩
    · rintro (⟨_, hop⟩ | ⟨h76', _, _⟩ | ⟨h256', _, _⟩ | hbig')
      · simpa using hop
      · omega
      · omega
      · omega
  · rw [if_neg h75]
    by_cases h255 : data.size ≤ 0xff
    · rw [if_pos h255]
      have h76 : 76 ≤ data.size := by omega
      have h256 : ¬ 0x100 ≤ data.size := by omega
      have hbig : ¬ 0xffff < data.size := by omega
      constructor
      · intro hop; exact Or.inr (Or.inl ⟨h76, h255, by simpa using hop⟩)
      · rintro (⟨h75', _⟩ | ⟨_, _, hop⟩ | ⟨h256', _, _⟩ | hbig')
        · omega
        · simpa using hop
        · omega
        · omega
    · rw [if_neg h255]
      by_cases h65535 : data.size ≤ 0xffff
      · rw [if_pos h65535]
        have h256 : 0x100 ≤ data.size := by omega
        have hbig : ¬ 0xffff < data.size := by omega
        constructor
        · intro hop; exact Or.inr (Or.inr (Or.inl ⟨h256, h65535, by simpa using hop⟩))
        · rintro (⟨h75', _⟩ | ⟨_, h255', _⟩ | ⟨_, _, hop⟩ | hbig')
          · omega
          · omega
          · simpa using hop
          · omega
      · rw [if_neg h65535]
        have hbig : 0xffff < data.size := by omega
        constructor
        · intro _; exact Or.inr (Or.inr (Or.inr hbig))
        · intro _; rfl

/-! ## INV-053 — `CheckLowS` (LOW_S, policy) -/

/-- **INV-053**: `checkLowS` accepts iff the DER re-encoding gate passes
and the big-endian S value is at most `n/2` (secp256k1 half order). -/
@[rule "INV-053"]
theorem checkLowS_iff (sig : ByteArray) :
    checkLowS sig = true ↔
      isValidSigEncoding (sig.push 0x01) = true ∧
      (List.range ((byteOr sig (5 + (byteOr sig 3).toNat)).toNat)).foldl
        (fun acc j => acc * 256 + (byteOr sig (6 + (byteOr sig 3).toNat + j)).toNat)
        0 ≤ SIG_S_HALF_ORDER := by
  unfold checkLowS
  by_cases h : isValidSigEncoding (sig.push 0x01) = true
  · simp [h]
  · simp [h]

/-- **INV-053** (gate law): a signature that fails the BIP66 DER shape
gate is never LOW_S-accepted, whatever its S bytes say. -/
@[rule "INV-053"]
theorem checkLowS_false_of_not_der (sig : ByteArray)
    (h : isValidSigEncoding (sig.push 0x01) = false) :
    checkLowS sig = false := by
  unfold checkLowS
  rw [if_pos (by simp [h])]

/-! ## INV-054 — `CheckPubKeyEncoding` -/

/-- **INV-054**: exact `none` (accept) characterization: STRICTENC rejects
non-33/65-byte shapes, and WITNESS_PUBKEYTYPE rejects uncompressed keys
on the witness-v0 path. Both bits are policy words (BIP146). -/
@[rule "INV-054"]
theorem checkPubKeyEncoding_none_iff (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (sv : Bitcoin.Crypto.Seam.SigVersion) (pk : ByteArray) :
    checkPubKeyEncoding flags pol sv pk = none ↔
      ¬ (pol.strictEnc = true ∧ isCompressedOrUncompressedPubKey pk = false) ∧
      ¬ (pol.witnessPubkeyType = true ∧ sv = .witnessV0 ∧ isCompressedPubKey pk = false) := by
  unfold checkPubKeyEncoding
  by_cases h1 : pol.strictEnc = true ∧ isCompressedOrUncompressedPubKey pk = false
  · rw [if_pos (by simp [h1])]; simp [h1]
  · rw [if_neg (by simp [h1])]
    by_cases h2 : pol.witnessPubkeyType = true ∧ sv = .witnessV0 ∧ isCompressedPubKey pk = false
    · rw [if_pos (by simp [h2])]; simp [h2]
    · rw [if_neg (by simp [h2])]; simp [h1, h2]

/-- **INV-054** (consensus path): with both policy bits off,
`CheckPubKeyEncoding` never rejects (the flag argument is unused). -/
@[rule "INV-054"]
theorem checkPubKeyEncoding_accepts_of_policy_off (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (sv : Bitcoin.Crypto.Seam.SigVersion) (pk : ByteArray)
    (hse : pol.strictEnc = false) (hwp : pol.witnessPubkeyType = false) :
    checkPubKeyEncoding flags pol sv pk = none := by
  rw [checkPubKeyEncoding_none_iff]
  simp [hse, hwp]

/-! ## SCR-105 — `IsDefinedHashtype` -/

/-- **SCR-105**: the hashtype byte (masked `&&& 0x7f`) is defined iff it
is in `{1,2,3}`; an empty signature has no defined hashtype. -/
@[rule "SCR-105"]
theorem isDefinedHashtype_iff (sig : ByteArray) :
    isDefinedHashtype sig = true ↔
      sig.size ≠ 0 ∧
      1 ≤ ((byteOr sig (sig.size - 1)).toNat &&& 0x7f) ∧
      ((byteOr sig (sig.size - 1)).toNat &&& 0x7f) ≤ 3 := by
  unfold isDefinedHashtype
  by_cases h : sig.size = 0
  · simp [h]
  · rw [if_neg h]
    simp [h]

/-- **SCR-105** (mask law): ANYONECANPAY (`0x80`) is masked away, so
`0x81`/`0x82`/`0x83` are accepted exactly like `1`/`2`/`3`. -/
@[rule "SCR-105"]
theorem isDefinedHashtype_anyonecanpay (sig : ByteArray)
    (h : sig.size ≠ 0)
    (hb : (byteOr sig (sig.size - 1)).toNat &&& 0x7f = 2) :
    isDefinedHashtype sig = true := by
  rw [isDefinedHashtype_iff]
  exact ⟨h, by omega, by omega⟩

end BitcoinProofs.AF.PDW81

/-! ## Axiom pins — all ⊆ [propext, Classical.choice, Quot.sound] -/

/-- info: 'BitcoinProofs.AF.PDW81.validateTx_coinbase_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW81.validateTx_coinbase_ok

/-- info: 'BitcoinProofs.AF.PDW81.validateTx_coinbase_utxo_indep' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW81.validateTx_coinbase_utxo_indep

/-- info: 'BitcoinProofs.AF.PDW81.checkMinimalPush_empty' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW81.checkMinimalPush_empty

/-- info: 'BitcoinProofs.AF.PDW81.checkMinimalPush_one_small' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW81.checkMinimalPush_one_small

/-- info: 'BitcoinProofs.AF.PDW81.checkMinimalPush_one_neg' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW81.checkMinimalPush_one_neg

/-- info: 'BitcoinProofs.AF.PDW81.checkMinimalPush_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW81.checkMinimalPush_iff

/-- info: 'BitcoinProofs.AF.PDW81.checkLowS_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW81.checkLowS_iff

/-- info: 'BitcoinProofs.AF.PDW81.checkLowS_false_of_not_der' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW81.checkLowS_false_of_not_der

/-- info: 'BitcoinProofs.AF.PDW81.checkPubKeyEncoding_none_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW81.checkPubKeyEncoding_none_iff

/-- info: 'BitcoinProofs.AF.PDW81.checkPubKeyEncoding_accepts_of_policy_off' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW81.checkPubKeyEncoding_accepts_of_policy_off

/-- info: 'BitcoinProofs.AF.PDW81.isDefinedHashtype_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW81.isDefinedHashtype_iff

/-- info: 'BitcoinProofs.AF.PDW81.isDefinedHashtype_anyonecanpay' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW81.isDefinedHashtype_anyonecanpay
