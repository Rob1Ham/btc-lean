import Bitcoin.Interpreter.Defs

/-! # PDW68B.lean — TOP-364..365: pubkey-encoding gates
(PDW68, review RC29). Claim `94fac5e`. Route B, zero core writes.

Row faces for `Bitcoin.Interpreter.checkPubKeyEncoding`
(Defs.lean:380, interpreter.cpp:225-234 @ cce32b168).
* **SCR-106** — STRICTENC: 33-byte 02/03 or 65-byte 04, else
  `SCRIPT_ERR_PUBKEYTYPE`.
* **SCR-107** — WITNESS_PUBKEYTYPE (policy): v0 witness pubkeys must be
  compressed (33-byte 02/03).
-/

namespace BitcoinProofs.AF.PDW68

open Bitcoin.Interpreter

/-- Exact `none` characterization of `CheckPubKeyEncoding`. -/
theorem pubkey_none_iff (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (sv : Bitcoin.Crypto.Seam.SigVersion) (pk : ByteArray) :
    checkPubKeyEncoding flags pol sv pk = none ↔
      ¬ (pol.strictEnc = true ∧ isCompressedOrUncompressedPubKey pk = false) ∧
      ¬ (pol.witnessPubkeyType = true ∧ sv = .witnessV0 ∧ isCompressedPubKey pk = false) := by
  unfold checkPubKeyEncoding
  by_cases h1 : pol.strictEnc = true ∧ isCompressedOrUncompressedPubKey pk = false
  · rw [ite_eq_left (by simp [h1])]; simp [h1]
  · rw [ite_eq_right (by simp [h1])]
    by_cases h2 : pol.witnessPubkeyType = true ∧ sv = .witnessV0 ∧ isCompressedPubKey pk = false
    · rw [ite_eq_left (by simp [h2])]; simp [h2]
    · rw [ite_eq_right (by simp [h2])]; simp [h1, h2]

/-- SCR-106 (reject): STRICTENC rejects a pubkey that is neither
33-byte 02/03 nor 65-byte 04. -/
@[rule "SCR-106"]
theorem pubkey_strictenc_reject (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (sv : Bitcoin.Crypto.Seam.SigVersion) (pk : ByteArray)
    (h : pol.strictEnc = true) (hpk : isCompressedOrUncompressedPubKey pk = false) :
    checkPubKeyEncoding flags pol sv pk = some .pubKeyType := by
  unfold checkPubKeyEncoding
  rw [ite_eq_left (by simp [h, hpk])]

/-- SCR-106 (pass): a well-formed (33/65-byte) pubkey clears STRICTENC;
with WITNESS_PUBKEYTYPE off it is accepted outright. -/
@[rule "SCR-106"]
theorem pubkey_strictenc_pass (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (sv : Bitcoin.Crypto.Seam.SigVersion) (pk : ByteArray)
    (hpk : isCompressedOrUncompressedPubKey pk = true)
    (hw : pol.witnessPubkeyType = false ∨ sv ≠ .witnessV0 ∨ isCompressedPubKey pk = true) :
    checkPubKeyEncoding flags pol sv pk = none := by
  rw [pubkey_none_iff]
  refine ⟨by simp [hpk], ?_⟩
  rintro ⟨h1, h2, h3⟩
  rcases hw with hw | hw | hw
  · rw [hw] at h1; simp at h1
  · exact hw h2
  · rw [hw] at h3; simp at h3

/-- SCR-107 (reject): under witnessV0, an uncompressed pubkey fails
WITNESS_PUBKEYTYPE (first branch disabled: STRICTENC off). -/
@[rule "SCR-107"]
theorem witness_pubkeytype_reject (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (sv : Bitcoin.Crypto.Seam.SigVersion) (pk : ByteArray)
    (hse : pol.strictEnc = false) (h : pol.witnessPubkeyType = true)
    (hsv : sv = .witnessV0) (hk : isCompressedPubKey pk = false) :
    checkPubKeyEncoding flags pol sv pk = some .witnessPubkeyType := by
  unfold checkPubKeyEncoding
  rw [ite_eq_right (by simp [hse])]
  rw [ite_eq_left (by simp [h, hsv, hk])]

/-- SCR-107 (pass): a compressed pubkey under witnessV0 is accepted. -/
@[rule "SCR-107"]
theorem witness_pubkeytype_pass (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (sv : Bitcoin.Crypto.Seam.SigVersion) (pk : ByteArray)
    (hse : pol.strictEnc = false) (h : pol.witnessPubkeyType = true)
    (hsv : sv = .witnessV0) (hk : isCompressedPubKey pk = true) :
    checkPubKeyEncoding flags pol sv pk = none := by
  unfold checkPubKeyEncoding
  rw [ite_eq_right (by simp [hse])]
  rw [ite_eq_right (by simp [h, hsv, hk])]

end BitcoinProofs.AF.PDW68
