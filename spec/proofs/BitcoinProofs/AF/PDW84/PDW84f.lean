import Bitcoin.Interpreter.Defs

/-! # PDW84f — TOP-445 swap row face: LOW_S policy gate

Route B, zero core writes. `CheckSignatureEncoding`'s LOW_S branch
(interpreter.cpp:183-198; pubkey.cpp:393-399): under the POLICY word
`pol.lowS`, a well-formed DER signature whose S value exceeds order/2 is
rejected with `sigHighS`; a low-S signature passes the branch. -/

namespace BitcoinProofs.AF.PDW84

open Bitcoin.Interpreter

/-- **SCR-104 (high-S reject)**: for a non-empty DER-valid signature,
`pol.lowS` plus a failing `checkLowS` on the S-bearing prefix
(`sig` minus the hashtype byte) yields exactly `sigHighS`. -/
@[rule "SCR-104"]
theorem checkSigEncoding_lowS_highS_row (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (sig : ByteArray)
    (hne : sig.size ≠ 0) (hder : isValidSigEncoding sig = true)
    (hlow : pol.lowS = true)
    (hhigh : checkLowS (sig.extract 0 (sig.size - 1)) = false) :
    checkSigEncoding flags pol sig = some .sigHighS := by
  simp [checkSigEncoding, hne, hder, hlow, hhigh]

/-- **SCR-104 (low-S pass)**: with the same DER premise, `pol.lowS` and a
passing `checkLowS` leave the encoding gate at `none` (no STRICTENC
hashtype rejection either). -/
@[rule "SCR-104"]
theorem checkSigEncoding_lowS_pass_row (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (sig : ByteArray)
    (hne : sig.size ≠ 0) (hder : isValidSigEncoding sig = true)
    (hlow : pol.lowS = true) (hstrict : pol.strictEnc = false)
    (hlows : checkLowS (sig.extract 0 (sig.size - 1)) = true) :
    checkSigEncoding flags pol sig = none := by
  simp [checkSigEncoding, hne, hder, hlow, hstrict, hlows]

/-- info: 'BitcoinProofs.AF.PDW84.checkSigEncoding_lowS_highS_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.checkSigEncoding_lowS_highS_row

/-- info: 'BitcoinProofs.AF.PDW84.checkSigEncoding_lowS_pass_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.checkSigEncoding_lowS_pass_row

end BitcoinProofs.AF.PDW84
