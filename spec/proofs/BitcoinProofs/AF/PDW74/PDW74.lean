import Bitcoin.Block.Sigops
import Bitcoin.Interpreter.Defs
import Bitcoin.Interpreter.Rules
import Bitcoin.Crypto.Ecdsa.Der
import Bitcoin.Consensus.TxCheck

/-! # PDW74 — TOP-391..395 row faces (sigop budget / policy gates). Route B. -/

namespace BitcoinProofs.AF.PDW74
open Bitcoin.Data (Tx TxIn)
open Bitcoin.Block.Sigops Bitcoin.Interpreter Bitcoin.Consensus

@[rule "INV-040"]
theorem legacySigOpBudgetOk_iff (vtx : List Tx) :
    legacySigOpBudgetOk vtx = true ↔
      legacySigOpCountBlock vtx * Bitcoin.Block.Sigops.WITNESS_SCALE_FACTOR ≤
        Bitcoin.Block.Sigops.MAX_BLOCK_SIGOPS_COST := by
  unfold legacySigOpBudgetOk
  by_cases h : legacySigOpCountBlock vtx * Bitcoin.Block.Sigops.WITNESS_SCALE_FACTOR ≤
      Bitcoin.Block.Sigops.MAX_BLOCK_SIGOPS_COST
  · simp [h]
  · simp [h]

@[rule "TPR-027"]
theorem evalChecksigTapscript_unknown_pubkey_discouraged
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (h0 : pk.size ≠ 0) (h32 : pk.size ≠ 32)
    (hd : pol.discourageUpgradablePubkeyType = true)
    (hbudget : sig.size = 0 ∨ ¬ ((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED < 0)) :
    evalChecksigTapscript pol chk ed sig pk vw
      = .error .discourageUpgradablePubkeyType := by
  unfold evalChecksigTapscript
  by_cases hs : sig.size = 0
  · simp [hs, h0, h32, hd]
  · have hb : ¬ ((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED < 0) := by
      rcases hbudget with h | h
      · exact absurd h hs
      · exact h
    simp [hs, hb, h0, h32, hd]

@[rule "SGN-108"]
theorem isLowDERSignature_true_iff (b : ByteArray) :
    Bitcoin.Crypto.Ecdsa.Der.isLowDERSignature b = true ↔
      Bitcoin.Crypto.Ecdsa.Der.isDERSignature b = true ∧
        ∃ r s, Bitcoin.Crypto.Ecdsa.Der.parseDerLax
          (Bitcoin.Crypto.Ecdsa.Der.dropLastByte b) = some (r, s) ∧
          s % Bitcoin.Crypto.Curve.Secp.n ≤ Bitcoin.Crypto.Ecdsa.Der.halfN := by
  unfold Bitcoin.Crypto.Ecdsa.Der.isLowDERSignature
  rw [Bool.and_eq_true]
  constructor
  · rintro ⟨hd, hp⟩
    refine ⟨hd, ?_⟩
    cases h : Bitcoin.Crypto.Ecdsa.Der.parseDerLax (Bitcoin.Crypto.Ecdsa.Der.dropLastByte b) with
    | none => simp [h] at hp
    | some rs => exact ⟨rs.1, rs.2, rfl, by simpa [h] using hp⟩
  · rintro ⟨hd, r, s, hp, hle⟩
    exact ⟨hd, by simp [hp, hle]⟩

@[rule "SCR-039"]
theorem MAX_STANDARD_TX_SIGOPS_COST_eq :
    Bitcoin.Interpreter.MAX_STANDARD_TX_SIGOPS_COST = 16000 := rfl

/-! ## SGN-108 — low-S is a policy gate, never a consensus gate

`CheckSignatureEncoding` (interpreter.cpp:120-160) reads LOW_S from the
**policy** word (`pol.lowS`), not from the consensus `ScriptFlags` (BIP146
dropped the consensus bit). `CPubKey::Verify` (pubkey.cpp:283-298) calls
`secp256k1_ecdsa_signature_normalize` (pubkey.cpp:294-296) only because raw
libsecp verify demands `!scalar_is_high`; normalizing `s ↦ n − s` is
verdict-invariant (`(u₁,u₂) ↦ (−u₁,−u₂)`, same R.x), so high-S signatures
still verify. `CPubKey::CheckLowS` is the policy word. The three theorems
below pin the split at the encoding gate. -/

/-- SGN-108: with `pol.lowS = false`, `checkSigEncoding` can never produce
`SCRIPT_ERR_SIG_HIGH_S` — no consensus path reads low-S. -/
@[rule "SGN-108"]
theorem checkSigEncoding_no_highS_of_lowS_false
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags) (sig : ByteArray)
    (hls : pol.lowS = false) :
    checkSigEncoding flags pol sig ≠ some .sigHighS := by
  intro h
  unfold checkSigEncoding at h
  by_cases h0 : sig.size = 0
  · simp [h0] at h
  · simp only [h0, if_false] at h
    by_cases hder : (flags.dersig ∨ pol.lowS ∨ pol.strictEnc) ∧
        !isValidSigEncoding sig
    · simp [hder] at h
    · simp only [hder, if_false] at h
      simp only [hls, if_false] at h
      cases hs : pol.strictEnc <;> cases hd : isDefinedHashtype sig <;>
        simp [hs, hd] at h

/-- SGN-108 (policy off): a valid-DER, non-empty high-S signature passes
the encoding gate when `lowS`, `strictEnc` and DERSIG are all off. -/
@[rule "SGN-108"]
theorem checkSigEncoding_highS_policy_off
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags) (sig : ByteArray)
    (hls : pol.lowS = false) (hse : pol.strictEnc = false)
    (hd : flags.dersig = false) (hne : sig.size ≠ 0) :
    checkSigEncoding flags pol sig = none := by
  unfold checkSigEncoding
  simp [hls, hse, hd, hne]

/-- SGN-108 (policy on): the *same* high-S signature (`checkLowS = false`)
is rejected `SIG_HIGH_S` once `pol.lowS = true` and the DER gate has
passed. This is the policy-only rejection, not a consensus rule. -/
@[rule "SGN-108"]
theorem checkSigEncoding_highS_policy_on
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags) (sig : ByteArray)
    (hls : pol.lowS = true) (hne : sig.size ≠ 0)
    (hder : ¬ ((flags.dersig ∨ pol.lowS ∨ pol.strictEnc) ∧
      !isValidSigEncoding sig))
    (hhigh : checkLowS (sig.extract 0 (sig.size - 1)) = false) :
    checkSigEncoding flags pol sig = some .sigHighS := by
  have hvalid : isValidSigEncoding sig = true := by
    cases hv : isValidSigEncoding sig with
    | false => exact absurd ⟨by simp [hls], by simp [hv]⟩ hder
    | true => rfl
  unfold checkSigEncoding
  simp [hls, hne, hvalid, hhigh]

@[rule "TXV-008"]
theorem checkTransaction_ok_cbLength (tx : Tx)
    (h : checkTransaction tx = none) (hcb : tx.isCoinBase = true)
    (i : TxIn) (hvin : tx.vin = [i]) :
    MIN_CB_LENGTH ≤ i.scriptSig.bytes.size ∧ i.scriptSig.bytes.size ≤ MAX_CB_LENGTH := by
  unfold checkTransaction at h
  split at h; · exact absurd h (by simp)
  split at h; · exact absurd h (by simp)
  split at h; · exact absurd h (by simp)
  split at h
  · exact absurd h (by simp)
  · split at h
    · exact absurd h (by simp)
    · split at h
      · next hcoin =>
        rw [hvin] at hcoin
        cases hcoin <;> simp_all
      · next hany =>
        have habs := hany i hvin
        nomatch habs

#print axioms legacySigOpBudgetOk_iff
#print axioms evalChecksigTapscript_unknown_pubkey_discouraged
#print axioms isLowDERSignature_true_iff
#print axioms MAX_STANDARD_TX_SIGOPS_COST_eq
#print axioms checkTransaction_ok_cbLength

end BitcoinProofs.AF.PDW74
