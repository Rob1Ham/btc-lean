import Bitcoin.Interpreter.Defs

/-! # PDW45 — TOP-181..185: X05 witness-program admission band (route B)

Row-face theorems for the BIP141 witness-program admission gate in
`Bitcoin/Interpreter/Defs.lean`:

* **SWT-001** `isWitnessProgram` — template closure (4..42 bytes,
  OP_0/OP_1..OP_16, length byte + 2 = size, program 2..40, v ∈ {0}∪[1,16]).
* **SWT-005** `verifyWitnessProgram` — v0-20 requires exactly 2 witness items.
* **SWT-007** `verifyWitnessProgram` — v0-32 empty witness fails closed.
* **SWT-008** `verifyWitnessProgram` — single-SHA256(last item) mismatch fails.
* **SWT-009** `verifyWitnessProgram` — v0 program size ∉ {20,32} ⇒ wrong length.

Status-debt class (PDW32 precedent): the X05 development
`Theorems/WitnessRulesCor.lean` already carries these proofs; the DB rows
were never flipped. Zero core writes, tags on my row-face theorems. -/

namespace BitcoinProofs.AF.PDW45

open Bitcoin.Interpreter Bitcoin.Data Bitcoin.Activation

/-- SWT-001: an accepted witness-program byte string closes on the Core
template: 4..42 bytes, OP_0/OP_1..OP_16 version, `len + 2 = size`,
2..40-byte program, version in `{0} ∪ [1,16]`. -/
@[rule "SWT-001"]
theorem isWitnessProgram_template (b : ByteArray) (v : Nat) (prog : ByteArray)
    (h : isWitnessProgram b = some (v, prog)) :
    4 ≤ b.size ∧ b.size ≤ 42 ∧ 2 ≤ prog.size ∧ prog.size ≤ 40 ∧
      prog.size + 2 = b.size ∧ (v = 0 ∨ (1 ≤ v ∧ v ≤ 16)) := by
  unfold isWitnessProgram at h
  by_cases h4 : 4 ≤ b.size ∧ b.size ≤ 42
  · by_cases hv : (b.get! 0).toNat = 0 ∨ (0x51 ≤ (b.get! 0).toNat ∧ (b.get! 0).toNat ≤ 0x60)
    · by_cases hplen : (b.get! 1).toNat + 2 = b.size
      · simp only [h4, ite_true, hv, hplen] at h
        obtain ⟨rfl, rfl⟩ := h
        have hsz : (b.extract 2 b.size).size = b.size - 2 := by
          rw [ByteArray.size_extract]; omega
        refine ⟨h4.1, h4.2, by omega, by omega, by omega, ?_⟩
        rcases hv with hv | hv
        · left; simp [hv]
        · right
          have hv0 : ¬((b.get! 0).toNat = 0) := by omega
          simp only [hv0, ite_false]
          omega
      · simp [h4, hv, hplen] at h
    · simp [h4, hv] at h
  · simp [h4] at h

/-- SWT-005: a v0-20 (P2WPKH) program accepts only a 2-item witness;
every other arity fails with `witnessProgramMismatch`. -/
@[rule "SWT-005"]
theorem verifyWitnessProgram_v0_p2wpkh_arity (fuel : Nat) (witness : WitnessStack)
    (program : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (h20 : program.size = 20) (harity : witness.length ≠ 2) :
    verifyWitnessProgram fuel witness 0 program flags pol chk isP2SH
      = .fail .witnessProgramMismatch := by
  simp [verifyWitnessProgram, h20, harity]

/-- SWT-007: a v0-32 (P2WSH) program with an empty witness fails closed
(`witnessProgramWitnessEmpty`) before any script execution. -/
@[rule "SWT-007"]
theorem verifyWitnessProgram_v0_p2wsh_empty_witness (fuel : Nat)
    (program : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool) (h32 : program.size = 32) :
    verifyWitnessProgram fuel [] 0 program flags pol chk isP2SH
      = .fail .witnessProgramWitnessEmpty := by
  simp [verifyWitnessProgram, h32]

/-- SWT-008: for a v0-32 program with non-empty witness, a differing
single-SHA256 of the last item fails with `witnessProgramMismatch`. -/
@[rule "SWT-008"]
theorem verifyWitnessProgram_v0_p2wsh_mismatch (fuel : Nat) (witness : WitnessStack)
    (program : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (h32 : program.size = 32) (hne : witness ≠ [])
    (hhash : (hashSha256 ((witness.getLast?).getD default) != program) = true) :
    verifyWitnessProgram fuel witness 0 program flags pol chk isP2SH
      = .fail .witnessProgramMismatch := by
  have hlen : witness.length ≠ 0 := by simp [hne]
  simp [verifyWitnessProgram, h32, hlen, hhash]

/-- SWT-009: a v0 program whose size is neither 20 nor 32 fails with
`witnessProgramWrongLength` (checked before any witness item). -/
@[rule "SWT-009"]
theorem verifyWitnessProgram_v0_wrongLength (fuel : Nat) (witness : WitnessStack)
    (program : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (h20 : program.size ≠ 20) (h32 : program.size ≠ 32) :
    verifyWitnessProgram fuel witness 0 program flags pol chk isP2SH
      = .fail .witnessProgramWrongLength := by
  simp [verifyWitnessProgram, h32, h20]
