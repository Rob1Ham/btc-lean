import Bitcoin.SigHash.Theorems

/-! # PDW64.lean — proof-promotion review RC29, items TOP-341..345
(PDW64, 2026-10-17). Claim 72bf5b4.

D-SHDIG / BIP143 digest status-debt band. Route B: zero core writes,
row-face theorems on my own `@[rule]` tags, core proof bank re-used.

* SCR-111 `htAcp` = 0x80 bit pass-through.
* INV-078 legacy digest class-determinism + out-of-range SINGLE = ONE.
* INV-071 BIP143 preimage class-determinism.
* SCR-140 10-field BIP143 preimage order, 8-byte LE amount included.
* SWT-042 SHA256d over the preimage; zero hash out of vin range.
-/

namespace BitcoinProofs.AF.PDW64

open Bitcoin.SigHash
open Bitcoin.Data
open Bitcoin.Serialization (Bytes bytesOfList encCSL)

/-- SCR-111: ACP is exactly bit 0x80 of the hashtype. -/
@[rule "SCR-111"]
theorem htAcp_bit_face (ht : UInt32) :
    htAcp ht = ((ht &&& 0x80) != 0) := rfl

/-- SCR-111: the ACP lane depends only on the 0x80 bit. -/
@[rule "SCR-111"]
theorem htAcp_determined {ht ht' : UInt32}
    (h : (ht &&& 0x80) = (ht' &&& 0x80)) : htAcp ht = htAcp ht' := by
  unfold htAcp
  rw [h]

/-- INV-078: legacy digest determined by class + raw hashtype bytes. -/
@[rule "INV-078"]
theorem legacy_digest_class_face (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht ht' : UInt32) (hcls : htClass ht = htClass ht')
    (hraw : serU32L ht = serU32L ht') :
    signatureHashLegacyImpl tx nIn sc ht = signatureHashLegacyImpl tx nIn sc ht' :=
  signatureHashLegacyImpl_determined tx nIn sc ht ht' hcls hraw

/-- INV-078: out-of-range SIGHASH_SINGLE fires before indexing = uint256::ONE. -/
@[rule "INV-078"]
theorem legacy_single_one_face (tx : Tx) (nIn : Nat) (sc : Bytes)
    (h : tx.vout.length ≤ nIn) :
    signatureHashLegacyImpl tx nIn sc 0x03 = singleOverflowOneB :=
  legacyImpl_single_oor tx nIn sc h

/-- INV-071: BIP143 preimage determined by class + raw hashtype bytes. -/
@[rule "INV-071"]
theorem bip143_msg_class_face (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht ht' : UInt32) (amount : Amount) (hcls : htClass ht = htClass ht')
    (hraw : serU32L ht = serU32L ht') :
    bip143MsgL tx nIn sc ht amount = bip143MsgL tx nIn sc ht' amount :=
  bip143MsgL_determined tx nIn sc ht ht' amount hcls hraw

/-- SCR-140: 10-field BIP143 preimage order; amount is field 6 (8-byte LE). -/
@[rule "SCR-140"]
theorem bip143MsgL_amount_field (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht : UInt32) (amount : Amount) :
    bip143MsgL tx nIn sc ht amount =
      serU32L tx.version.toUInt32 ++ hashPrevoutsL tx ht ++ hashSequenceL tx ht
        ++ serOutpointL (tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩).prevout
        ++ encCSL sc.length ++ sc ++ serAmountL amount
        ++ serU32L (tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩).sequence
        ++ hashOutputsL tx nIn ht ++ serU32L tx.locktime ++ serU32L ht := rfl

/-- SWT-042: in-range BIP143 digest = SHA256d of the 10-field preimage. -/
@[rule "SWT-042"]
theorem bip143_digest_dsha_face (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht : UInt32) (amount : Amount) (h : nIn < tx.vin.length) :
    signatureHashBip143Impl tx nIn sc ht amount =
      dshaL (bip143MsgL tx nIn sc ht amount) := by
  unfold signatureHashBip143Impl
  split
  · omega
  · rfl

/-- SWT-042: out-of-range vin totalizes to the 32-zero-byte digest. -/
@[rule "SWT-042"]
theorem bip143_digest_oor_face (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht : UInt32) (amount : Amount) (h : tx.vin.length ≤ nIn) :
    signatureHashBip143Impl tx nIn sc ht amount = bytesOfList zeroHashL := by
  unfold signatureHashBip143Impl
  split
  · rfl
  · omega

end BitcoinProofs.AF.PDW64

/-- info: 'BitcoinProofs.AF.PDW64.htAcp_bit_face' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW64.htAcp_bit_face

/-- info: 'BitcoinProofs.AF.PDW64.htAcp_determined' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW64.htAcp_determined

/-- info: 'BitcoinProofs.AF.PDW64.legacy_digest_class_face' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW64.legacy_digest_class_face

/-- info: 'BitcoinProofs.AF.PDW64.legacy_single_one_face' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW64.legacy_single_one_face

/-- info: 'BitcoinProofs.AF.PDW64.bip143_msg_class_face' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW64.bip143_msg_class_face

/-- info: 'BitcoinProofs.AF.PDW64.bip143MsgL_amount_field' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW64.bip143MsgL_amount_field

/-- info: 'BitcoinProofs.AF.PDW64.bip143_digest_dsha_face' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW64.bip143_digest_dsha_face

/-- info: 'BitcoinProofs.AF.PDW64.bip143_digest_oor_face' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW64.bip143_digest_oor_face
