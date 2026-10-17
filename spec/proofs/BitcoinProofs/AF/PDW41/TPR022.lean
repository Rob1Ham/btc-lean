import Bitcoin.Crypto.Taproot.Program

/-! # PDW41/TPR022.lean — TPR-022 row face (BIP342 weight budget)

Claim v2 `d87a0cb`. Route B, zero core writes.

TPR-022: `validation_weight_left = GetSerializeSize(witness.stack) +
VALIDATION_WEIGHT_OFFSET` (interpreter.cpp:1991; offset 50 per
BIP342 §Resource limits). Row faces: the offset pin, the empty-witness
base, the append fold law, and strict growth (any appended witness
element increases the budget base). -/

namespace BitcoinProofs.AF.PDW41

open Bitcoin.Crypto.Taproot.Program
open Bitcoin.Data (compactSizeEnc)

/-- TPR-022 (row face): the budget is exactly witness serialized size
plus the 50 WU offset. -/
@[rule "TPR-022"]
theorem validationWeightInit_row (witness : List ByteArray) :
    validationWeightInit witness =
      witnessSerSize witness + VALIDATION_WEIGHT_OFFSET := rfl

/-- TPR-022 (offset pin): the constant is 50 weight units. -/
theorem validationWeightInit_offset : VALIDATION_WEIGHT_OFFSET = 50 := rfl

/-- TPR-022 (empty witness): an empty stack starts at exactly 50 WU. -/
theorem validationWeightInit_nil : validationWeightInit [] = 50 := by
  unfold validationWeightInit witnessSerSize VALIDATION_WEIGHT_OFFSET
  rfl

/-- TPR-022 (append law): appending one witness element adds its
CompactSize length prefix plus its bytes. -/
theorem witnessSerSize_append_single (items : List ByteArray) (a : ByteArray) :
    witnessSerSize (items ++ [a]) =
      witnessSerSize items + Int.ofNat ((compactSizeEnc a.size).size + a.size) := by
  unfold witnessSerSize
  rw [List.foldl_append]
  simp

/-- TPR-022 (strict growth): every appended element (even the empty
byte string) strictly increases the budget base — the initial budget
is monotone in the witness. -/
theorem validationWeightInit_strict_growth (items : List ByteArray)
    (a : ByteArray) : witnessSerSize items < witnessSerSize (items ++ [a]) := by
  rw [witnessSerSize_append_single]
  have hpos : 0 < (compactSizeEnc a.size).size + a.size := by
    have := compactSizeEnc_size_pos a.size; omega
  have hb : (0 : Int) < Int.ofNat ((compactSizeEnc a.size).size + a.size) :=
    Int.ofNat_lt.mpr hpos
  omega

end BitcoinProofs.AF.PDW41
