/-
Cell-local kernel check for SCR-040 — arbitrary-count budget composition.

This file is NOT imported by `spec/proofs/**` and does not modify any shared
Lean file.  It is evidence for the cell
`spec/equiv/cells/limits/C-L-scr-040-witness-budget` only.

It proves, for an *arbitrary* `List ByteArray` (no arity bound), that the
model's tapscript validation-weight budget is the actual BIP144 witness
encoding length plus the 50 WU offset, and the explicit two-term form

    Budget(items) = CompactSize(items.length)
                  + foldl (fun acc d => acc + CompactSize(d.size) + d.size) 0 items
                  + 50

The Lean term `encStackL` is the byte encoder:
`CompactSize(count) || flatMap (fun item => CompactSize(item.size) || item)`.
-/
import Bitcoin.Interpreter.Defs
import Bitcoin.Serialization.Interface

namespace Wave65.Scr040Budget

open Bitcoin.Data Bitcoin.Serialization Bitcoin.Crypto.Taproot.Program

/-- The per-item step of Core's `GetSerializeSize` loop / the Lean fold:
`CompactSize(len) + len`. -/
def witnessItemStep (acc : Int) (d : ByteArray) : Int :=
  acc + Int.ofNat ((compactSizeEnc d.size).size + d.size)

private theorem count_size (n : Nat) : (encCSL n).length = (compactSizeEnc n).size := by
  rw [← bL_compactSizeEnc]
  rfl

private theorem payload_size (items : List ByteArray) (seed : Int) :
    items.foldl (fun acc d => acc + Int.ofNat ((compactSizeEnc d.size).size + d.size)) seed =
      seed + Int.ofNat (items.flatMap (fun item => encCSL item.size ++ bL item)).length := by
  induction items generalizing seed with
  | nil => simp
  | cons d rest ih =>
    simp only [List.foldl_cons, List.flatMap_cons, List.length_append, count_size]
    rw [ih]
    have hd : (bL d).length = d.size := rfl
    simp only [hd, Int.ofNat_eq_natCast, Int.natCast_add]
    omega

/-- The payload fold is exactly the length of the encoder's item bytes. -/
theorem witnessPayloadSize_eq_encoder_payload (items : List ByteArray) :
    witnessPayloadSize items =
      Int.ofNat (items.flatMap (fun item => encCSL item.size ++ bL item)).length := by
  unfold witnessPayloadSize
  rw [payload_size]
  simp

/-- SCR-040, encoder form for an arbitrary list: the model budget equals the
length of the real BIP144 stack encoding plus 50 WU. -/
theorem validationWeightInit_eq_encoder_add_offset (items : List ByteArray) :
    validationWeightInit items = Int.ofNat (encStackL items).length + 50 := by
  unfold validationWeightInit witnessSerSize encStackL VALIDATION_WEIGHT_OFFSET
  rw [witnessPayloadSize_eq_encoder_payload]
  simp only [List.length_append, count_size, Int.ofNat_eq_natCast, Int.natCast_add]

/-- SCR-040, explicit two-term composition for an arbitrary item count: count
CompactSize + the per-item fold + 50.  No arity bound and no list-length
hypothesis are used. -/
theorem validationWeightInit_eq_count_add_fold (items : List ByteArray) :
    validationWeightInit items =
      Int.ofNat (compactSizeEnc items.length).size +
        items.foldl witnessItemStep 0 + 50 := by
  unfold validationWeightInit witnessSerSize witnessPayloadSize witnessItemStep
    VALIDATION_WEIGHT_OFFSET
  rfl

/-- The two forms agree: the count prefix plus the fold is the encoder length. -/
theorem count_add_fold_eq_encoder (items : List ByteArray) :
    Int.ofNat (compactSizeEnc items.length).size +
        items.foldl witnessItemStep 0 =
      Int.ofNat (encStackL items).length := by
  unfold encStackL witnessItemStep
  rw [payload_size]
  simp only [List.length_append, count_size, Int.ofNat_eq_natCast, Int.natCast_add,
    Int.zero_add]

-- Axiom audit: no `sorry`, no extra axioms beyond Lean's kernel axioms.
#print axioms validationWeightInit_eq_count_add_fold
#print axioms validationWeightInit_eq_encoder_add_offset

end Wave65.Scr040Budget
