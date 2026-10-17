import Bitcoin.SigHash.Theorems

/-! # PDW58D.lean — TOP-314: SCR-140 BIP143 preimage field order
(PDW58, review RC29). Row face for `Bitcoin.SigHash.bip143MsgL`
(interpreter.cpp:1633-1670 @ cce32b168; BIP143 §6).
Route B: zero core writes. -/

namespace BitcoinProofs.AF.PDW58

open Bitcoin.Data Bitcoin.SigHash Bitcoin.Serialization

/-- SCR-140 (field order): the preimage is exactly the 10-field BIP143
concatenation, with the 8-byte LE `amount` at field 6 (after the
length-prefixed scriptCode, before nSequence). -/
@[rule "SCR-140"]
theorem bip143MsgL_field_order (tx : Tx) (nIn : Nat) (sc : Bytes) (ht : UInt32)
    (amount : Amount) :
    bip143MsgL tx nIn sc ht amount =
      serU32L tx.version.toUInt32
        ++ hashPrevoutsL tx ht
        ++ hashSequenceL tx ht
        ++ serOutpointL (tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩).prevout
        ++ encCSL sc.length ++ sc
        ++ serAmountL amount
        ++ serU32L (tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩).sequence
        ++ hashOutputsL tx nIn ht
        ++ serU32L tx.locktime
        ++ serU32L ht := by
  unfold bip143MsgL
  rfl

/-- SCR-140 (amount slot): factoring the message around the amount field
shows the amount sits strictly between scriptCode and nSequence. -/
@[rule "SCR-140"]
theorem bip143MsgL_amount_slot (tx : Tx) (nIn : Nat) (sc : Bytes) (ht : UInt32)
    (amount : Amount) :
    bip143MsgL tx nIn sc ht amount =
      (serU32L tx.version.toUInt32
        ++ hashPrevoutsL tx ht
        ++ hashSequenceL tx ht
        ++ serOutpointL (tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩).prevout
        ++ encCSL sc.length ++ sc)
      ++ serAmountL amount
      ++ (serU32L (tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩).sequence
        ++ hashOutputsL tx nIn ht
        ++ serU32L tx.locktime
        ++ serU32L ht) := by
  unfold bip143MsgL
  simp only [List.append_assoc]

/-- SCR-140 (8-byte amount): `serAmountL` is exactly an 8-byte little-endian
field. -/
@[rule "SCR-140"]
theorem serAmountL_length (amount : Amount) : (serAmountL amount).length = 8 := rfl

/-- SCR-140 (amount is committed): two preimages that agree must agree on
the serialized 8-byte amount field — changing the amount changes the
message (append-cancellation around the field-6 slot). -/
@[rule "SCR-140"]
theorem bip143MsgL_amount_eq (tx : Tx) (nIn : Nat) (sc : Bytes) (ht : UInt32)
    (a1 a2 : Amount)
    (h : bip143MsgL tx nIn sc ht a1 = bip143MsgL tx nIn sc ht a2) :
    serAmountL a1 = serAmountL a2 := by
  rw [bip143MsgL_amount_slot, bip143MsgL_amount_slot] at h
  exact List.append_cancel_left (List.append_cancel_right h)

end BitcoinProofs.AF.PDW58
