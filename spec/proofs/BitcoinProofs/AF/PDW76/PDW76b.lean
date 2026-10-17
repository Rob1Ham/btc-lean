import Bitcoin.Capstone.Merkle

/-! # PDW76b.lean — SWT-031 coinbase witness-nonce shape (TOP-403) -/

namespace BitcoinProofs.AF.PDW76
open Bitcoin.Capstone.Merkle Bitcoin.Data

/-- **SWT-031** (validation.cpp:3886-3893, `bad-witness-nonce-size`): the
coinbase scriptWitness is exactly one item and that item is 32 bytes. -/
@[rule "SWT-031"]
theorem commitmentNonceOk_eq_true (cb : Tx) :
    commitmentNonceOk cb = true ↔
      ∃ (nonce : ByteArray) (rest : List WitnessStack),
        cb.witness = [nonce] :: rest ∧ nonce.size = 32 := by
  constructor
  · intro h
    cases hl : cb.witness with
    | nil =>
      rw [commitmentNonceOk, hl] at h
      simp at h
    | cons w rest =>
      cases hw : w with
      | nil =>
        rw [commitmentNonceOk, hl, hw] at h
        simp at h
      | cons n0 ws =>
        cases hws : ws with
        | nil =>
          refine ⟨n0, rest, ?_, ?_⟩
          · rfl
          · rw [commitmentNonceOk, hl, hw, hws] at h
            simpa using h
        | cons n1 ws' =>
          rw [commitmentNonceOk, hl, hw, hws] at h
          simp at h
  · rintro ⟨nonce, rest, heq, hs⟩
    rw [commitmentNonceOk, heq]
    simp [hs]

end BitcoinProofs.AF.PDW76


/-! ## Axiom pin (subset of [propext, Classical.choice, Quot.sound]) -/

/-- info: 'BitcoinProofs.AF.PDW76.commitmentNonceOk_eq_true' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW76.commitmentNonceOk_eq_true
