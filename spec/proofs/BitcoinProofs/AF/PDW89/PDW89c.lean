import Bitcoin.Interpreter.Defs

/-! # PDW89c — SCR-104 LOW_S row face (S ≤ order/2 under the policy bit). -/

namespace BitcoinProofs.AF.PDW89c
open Bitcoin.Interpreter

/-- SCR-104: `checkLowS` accepts iff the DER re-encoding gate passes and
the decoded big-endian S value is at most the secp256k1 half order
(interpreter.cpp:183-198); the bit is policy-only (BIP146). -/
@[rule "SCR-104"]
theorem checkLowS_row (sig : ByteArray) :
    checkLowS sig = true ↔
      isValidSigEncoding (sig.push 0x01) = true ∧
      (List.range ((byteOr sig (5 + (byteOr sig 3).toNat)).toNat)).foldl
        (fun acc j => acc * 256 + (byteOr sig (6 + (byteOr sig 3).toNat + j)).toNat)
        0 ≤ SIG_S_HALF_ORDER := by
  unfold checkLowS
  by_cases h : isValidSigEncoding (sig.push 0x01) = true
  · simp [h]
  · simp [h]

/-- SCR-104 (gate law): a signature failing the BIP66 DER shape gate is
never LOW_S-accepted. -/
@[rule "SCR-104"]
theorem checkLowS_not_der (sig : ByteArray)
    (h : isValidSigEncoding (sig.push 0x01) = false) :
    checkLowS sig = false := by
  unfold checkLowS
  rw [if_pos (by simp [h])]

end BitcoinProofs.AF.PDW89c

#print axioms BitcoinProofs.AF.PDW89c.checkLowS_row
#print axioms BitcoinProofs.AF.PDW89c.checkLowS_not_der
