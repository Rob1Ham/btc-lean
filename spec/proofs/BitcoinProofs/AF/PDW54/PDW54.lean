import Bitcoin.Interpreter.Defs

/-! # PDW54 — witness-program recognition + forward-compat belt (TOP-266..270)

Row-face theorems for {SCR-053, SWT-001, SWT-002, SWT-013, SWT-014}.
`isWitnessProgram` (Defs.lean:489, script.h) gates every segwit branch of
`verifyScriptFull`; `verifyWitnessProgram` (Defs.lean:1205,
interpreter.cpp:1827-2008) decides unknown-version pass-through/policy.
Route B: tags on my theorems, zero core writes. -/

namespace BitcoinProofs.AF.PDW54

open Bitcoin.Interpreter

/-- SCR-053: exact `some`-characterization of `IsWitnessProgram`. -/
@[rule "SCR-053"]
theorem isWitnessProgram_some_iff (b : ByteArray) (v : Nat) (prog : ByteArray) :
    isWitnessProgram b = some (v, prog) ↔
      4 ≤ b.size ∧ b.size ≤ 42 ∧
        ((b.get! 0).toNat = 0 ∨
          (0x51 ≤ (b.get! 0).toNat ∧ (b.get! 0).toNat ≤ 0x60)) ∧
        (if (b.get! 0).toNat = 0 then 0 else (b.get! 0).toNat - 0x50) = v ∧
        (b.get! 1).toNat + 2 = b.size ∧ b.extract 2 b.size = prog := by
  unfold isWitnessProgram
  by_cases h4 : 4 ≤ b.size ∧ b.size ≤ 42
  · rw [ite_eq_left h4]
    by_cases hv : (b.get! 0).toNat = 0 ∨
        (0x51 ≤ (b.get! 0).toNat ∧ (b.get! 0).toNat ≤ 0x60)
    · rw [ite_eq_left hv]
      by_cases hp : (b.get! 1).toNat + 2 = b.size
      · rw [ite_eq_left hp]
        simp [Option.some.injEq, Prod.mk.injEq, h4, hv, hp]
      · rw [ite_eq_right hp]
        constructor
        · intro h; cases h
        · intro h; exact (hp h.2.2.2.2.1).elim
    · rw [ite_eq_right hv]
      constructor
      · intro h; cases h
      · intro h; exact (hv h.2.2.1).elim
  · rw [ite_eq_right h4]
    constructor
    · intro h; cases h
    · intro h; exact (h4 ⟨h.1, h.2.1⟩).elim

/-- SCR-137: v0 accepts only 20-byte (P2WPKH) or 32-byte (P2WSH) programs. -/
@[rule "SCR-137"]
theorem verifyWitnessProgram_v0_wrongLength (fuel : Nat)
    (witness : Bitcoin.Data.WitnessStack) (program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : Bitcoin.Interpreter.PolicyFlags)
    (chk : Bitcoin.Interpreter.ScriptChecker)
    (h20 : program.size ≠ 20) (h32 : program.size ≠ 32) :
    verifyWitnessProgram fuel witness 0 program flags pol chk false
      = .fail .witnessProgramWrongLength := by
  simp [verifyWitnessProgram, h20, h32]

/-- SWT-002: version byte decoding (OP_0→0, OP_1..OP_16→1..16). -/
@[rule "SWT-002"]
theorem isWitnessProgram_version_decode (b : ByteArray) (v : Nat) (prog : ByteArray)
    (h : isWitnessProgram b = some (v, prog)) :
    (v = 0 ∧ (b.get! 0).toNat = 0) ∨
      (1 ≤ v ∧ v ≤ 16 ∧ (b.get! 0).toNat = v + 0x50) := by
  obtain ⟨-, -, hv, hif, -, -⟩ :=
    (isWitnessProgram_some_iff b v prog).mp h
  rcases hv with hv | hv
  · refine Or.inl ⟨?_, hv⟩
    simp only [hv, ite_true] at hif
    omega
  · have hv0 : (b.get! 0).toNat ≠ 0 := by omega
    simp only [hv0, ite_false] at hif
    exact Or.inr ⟨by omega, by omega, by omega⟩

/-- SWT-013: every unknown version (≥2) is anyone-can-spend. -/
@[rule "SWT-013"]
theorem verifyWitnessProgram_unknown_ok (fuel : Nat) (witness : Bitcoin.Data.WitnessStack)
    (v : Nat) (program : ByteArray) (flags : Bitcoin.Activation.ScriptFlags) (pol : Bitcoin.Interpreter.PolicyFlags)
    (chk : Bitcoin.Interpreter.ScriptChecker) (hv : 2 ≤ v)
    (hd : pol.discourageUpgradableWitnessProgram = false) :
    verifyWitnessProgram fuel witness v program flags pol chk false = .ok := by
  have hv0 : v ≠ 0 := by omega
  have hv1 : v ≠ 1 := by omega
  simp [verifyWitnessProgram, hv0, hv1, hd, isPayToAnchor]

/-- SWT-014: with DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM, unknown version fails. -/
@[rule "SWT-014"]
theorem verifyWitnessProgram_discourage_unknown (fuel : Nat) (witness : Bitcoin.Data.WitnessStack)
    (v : Nat) (program : ByteArray) (flags : Bitcoin.Activation.ScriptFlags) (pol : Bitcoin.Interpreter.PolicyFlags)
    (chk : Bitcoin.Interpreter.ScriptChecker) (hv : 2 ≤ v)
    (hd : pol.discourageUpgradableWitnessProgram = true) :
    verifyWitnessProgram fuel witness v program flags pol chk false
      = .fail .discourageUpgradableWitnessProgram := by
  have hv0 : v ≠ 0 := by omega
  have hv1 : v ≠ 1 := by omega
  simp [verifyWitnessProgram, hv0, hv1, hd, isPayToAnchor]

end BitcoinProofs.AF.PDW54

#print axioms BitcoinProofs.AF.PDW54.isWitnessProgram_some_iff
#print axioms BitcoinProofs.AF.PDW54.verifyWitnessProgram_v0_wrongLength
#print axioms BitcoinProofs.AF.PDW54.isWitnessProgram_version_decode
#print axioms BitcoinProofs.AF.PDW54.verifyWitnessProgram_unknown_ok
#print axioms BitcoinProofs.AF.PDW54.verifyWitnessProgram_discourage_unknown
