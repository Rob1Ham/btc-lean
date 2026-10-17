import Bitcoin.Interpreter.Defs
import Mathlib.Tactic

/-! # PDW82 — TOP-431..435 row faces (BIP66 DER + tapscript CHECKSIG ordering)

Route B: proofs-side row-face theorems for `implemented` Interpreter/Defs
rows. Zero core writes; tags ride these theorems.
-/

namespace BitcoinProofs.AF.PDW82

open Bitcoin.Interpreter

/-! ## SCR-102 — `IsValidSignatureEncoding` (BIP66) -/

/-- SCR-102: every accepted DER signature is 9..73 bytes. -/
@[rule "SCR-102"]
theorem isValidSigEncoding_size (sig : ByteArray)
    (h : isValidSigEncoding sig = true) :
    9 ≤ sig.size ∧ sig.size ≤ 73 := by
  by_contra hb
  have hc : sig.size < 9 ∨ 73 < sig.size := by omega
  unfold isValidSigEncoding at h
  rw [if_pos hc] at h
  simp at h

/-- SCR-102: accepted signatures carry the strict-DER outer tag `0x30`
and the BIP66 length byte `size - 3`. -/
@[rule "SCR-102"]
theorem isValidSigEncoding_der_prefix (sig : ByteArray)
    (h : isValidSigEncoding sig = true) :
    byteOr sig 0 = 0x30 ∧ (byteOr sig 1).toNat = sig.size - 3 := by
  have hs := isValidSigEncoding_size sig h
  have hg : ¬ (sig.size < 9 ∨ 73 < sig.size) := by omega
  have h0 : byteOr sig 0 = 0x30 := by
    by_contra hc
    unfold isValidSigEncoding at h
    rw [if_neg hg, if_pos hc] at h
    simp at h
  refine ⟨h0, ?_⟩
  by_contra hc
  unfold isValidSigEncoding at h
  rw [if_neg hg, if_neg (by intro hne; exact hne h0)] at h
  rw [if_pos hc] at h
  simp at h

/-- SCR-102 row face: the FULL strict-DER structure required by
`IsValidSignatureEncoding` (interpreter.cpp:118-181 / BIP66), not merely
the 9..73 size band: outer `0x30` tag, BIP66 length byte `size - 3`, two
`0x02` INTEGER tags, non-zero R/S lengths, non-negative R/S high bits, and
the minimal-encoding (no redundant leading zero) rules. -/
@[rule "SCR-102"]
theorem isValidSigEncoding_strict_der (sig : ByteArray)
    (h : isValidSigEncoding sig = true) :
    9 ≤ sig.size ∧ sig.size ≤ 73 ∧
    byteOr sig 0 = 0x30 ∧
    (byteOr sig 1).toNat = sig.size - 3 ∧
    5 + (byteOr sig 3).toNat < sig.size ∧
    (byteOr sig 3).toNat + (byteOr sig (5 + (byteOr sig 3).toNat)).toNat + 7 = sig.size ∧
    byteOr sig 2 = 0x02 ∧
    (byteOr sig 3).toNat ≠ 0 ∧
    (byteOr sig 4) &&& 0x80 = 0 ∧
    ¬(1 < (byteOr sig 3).toNat ∧ byteOr sig 4 = 0 ∧ (byteOr sig 5) &&& 0x80 = 0) ∧
    byteOr sig ((byteOr sig 3).toNat + 4) = 0x02 ∧
    (byteOr sig (5 + (byteOr sig 3).toNat)).toNat ≠ 0 ∧
    (byteOr sig ((byteOr sig 3).toNat + 6)) &&& 0x80 = 0 ∧
    ¬(1 < (byteOr sig (5 + (byteOr sig 3).toNat)).toNat ∧
      byteOr sig ((byteOr sig 3).toNat + 6) = 0 ∧
      (byteOr sig ((byteOr sig 3).toNat + 7)) &&& 0x80 = 0) := by
  have hsz := isValidSigEncoding_size sig h
  unfold isValidSigEncoding at h
  dsimp only at h
  by_cases h1 : sig.size < 9 ∨ 73 < sig.size
  · rw [if_pos h1] at h; simp at h
  · rw [if_neg h1] at h
    by_cases h2 : byteOr sig 0 ≠ 0x30
    · rw [if_pos h2] at h; simp at h
    · rw [if_neg h2] at h
      by_cases h3 : (byteOr sig 1).toNat ≠ sig.size - 3
      · rw [if_pos h3] at h; simp at h
      · rw [if_neg h3] at h
        by_cases h4 : 5 + (byteOr sig 3).toNat ≥ sig.size
        · rw [if_pos h4] at h; simp at h
        · rw [if_neg h4] at h
          by_cases h5 : (byteOr sig 3).toNat
                + (byteOr sig (5 + (byteOr sig 3).toNat)).toNat + 7 ≠ sig.size
          · rw [if_pos h5] at h; simp at h
          · rw [if_neg h5] at h
            by_cases h6 : byteOr sig 2 ≠ 0x02
            · rw [if_pos h6] at h; simp at h
            · rw [if_neg h6] at h
              by_cases h7 : (byteOr sig 3).toNat = 0
              · rw [if_pos h7] at h; simp at h
              · rw [if_neg h7] at h
                by_cases h8 : byteOr sig 4 &&& 0x80 ≠ 0
                · rw [if_pos h8] at h; simp at h
                · rw [if_neg h8] at h
                  by_cases h9 : (byteOr sig 3).toNat > 1 ∧ byteOr sig 4 = 0
                      ∧ byteOr sig 5 &&& 0x80 = 0
                  · rw [if_pos h9] at h; simp at h
                  · rw [if_neg h9] at h
                    by_cases h10 : byteOr sig ((byteOr sig 3).toNat + 4) ≠ 0x02
                    · rw [if_pos h10] at h; simp at h
                    · rw [if_neg h10] at h
                      by_cases h11 : (byteOr sig (5 + (byteOr sig 3).toNat)).toNat = 0
                      · rw [if_pos h11] at h; simp at h
                      · rw [if_neg h11] at h
                        by_cases h12 : byteOr sig ((byteOr sig 3).toNat + 6) &&& 0x80 ≠ 0
                        · rw [if_pos h12] at h; simp at h
                        · rw [if_neg h12] at h
                          by_cases h13 : (byteOr sig (5 + (byteOr sig 3).toNat)).toNat > 1
                              ∧ byteOr sig ((byteOr sig 3).toNat + 6) = 0
                              ∧ byteOr sig ((byteOr sig 3).toNat + 7) &&& 0x80 = 0
                          · rw [if_pos h13] at h; simp at h
                          · rw [if_neg h13] at h
                            refine ⟨hsz.1, hsz.2, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_,
                              ?_, ?_, ?_, ?_⟩
                            · simpa using h2
                            · simpa using h3
                            · omega
                            · simpa using h5
                            · simpa using h6
                            · simpa using h7
                            · simpa using h8
                            · simpa using h9
                            · simpa using h10
                            · simpa using h11
                            · simpa using h12
                            · simpa using h13

/-! ## SCR-159 — tapscript budget check precedes the pubkey rules -/

/-- SCR-159: a non-empty signature whose 50 WU charge would underflow the
budget fails with `TAPSCRIPT_VALIDATION_WEIGHT` *before* any pubkey
inspection (in particular before `TAPSCRIPT_EMPTY_PUBKEY`). -/
@[rule "SCR-159"]
theorem evalChecksigTapscript_weight_before_pubkey
    (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hvw : vw.getD 0 < 50) :
    evalChecksigTapscript pol chk ed sig pk vw
      = .error .tapscriptValidationWeight := by
  unfold evalChecksigTapscript
  rw [if_pos hsig]
  rw [if_pos (by show (vw.getD 0) - 50 < 0; omega)]

/-! ## SCR-160 — empty signature: failed check, no verify, no weight -/

/-- SCR-160: an empty tapscript signature against a 32-byte key is a
false check that continues, with the validation-weight budget unchanged
(no Schnorr verification and no 50 WU charge). -/
@[rule "SCR-160"]
theorem evalChecksigTapscript_empty_sig_no_weight
    (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (pk : ByteArray) (vw : Option Int) (h32 : pk.size = 32) :
    evalChecksigTapscript pol chk ed ByteArray.empty pk vw
      = .ok (false, vw) := by
  unfold evalChecksigTapscript
  rw [if_neg (by simp)]
  rw [if_neg (by simp [h32])]
  rw [if_pos h32]

end BitcoinProofs.AF.PDW82
