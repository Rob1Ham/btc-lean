import Bitcoin.Interpreter.Defs

/-! # BitcoinProofs.AF.PDW75 — TOP-396..400 row faces, v0 witness programs

Route B: proofs-side row faces of `verifyWitnessProgram`'s segwit-v0
branches (interpreter.cpp:1900-1955). Zero core writes; `@[rule]` tags
ride these theorems. Axiom pin target: `[propext, Classical.choice,
Quot.sound]`.
-/

namespace BitcoinProofs.AF.PDW75

open Bitcoin.Interpreter Bitcoin.Data

/-! ## SCR-133/134/135 — P2WSH (v0, 32-byte program) -/

/-- **SCR-133**: with a non-empty witness and
`SHA256(witnessScript) = program`, the 32-byte v0 branch delegates to
`executeWitnessScript` on the witness script (last item) and the rest. -/
@[rule "SCR-133"]
theorem verifyWitnessProgram_v0_p2wsh_script
    (fuel : Nat) (witness : WitnessStack) (program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (h32 : program.size = 32) (hne : witness.length ≠ 0)
    (heq : (hashSha256 (witness.getLast!) == program) = true) :
    verifyWitnessProgram fuel witness 0 program flags pol chk isP2SH
      = executeWitnessScript fuel witness.dropLast (witnessSerSize witness)
          (witness.getLast!) flags pol chk .witnessV0 := by
  unfold verifyWitnessProgram
  rw [ite_eq_left rfl, ite_eq_left h32, ite_eq_right hne]
  have hb : ¬ ((hashSha256 (witness.getLast!) != program) = true) := by
    rw [bne, heq]; simp
  rw [ite_eq_right hb]

/-- **SCR-134**: an empty witness on a 32-byte v0 program is
`WITNESS_PROGRAM_WITNESS_EMPTY` (checked before hashing). -/
@[rule "SCR-134"]
theorem verifyWitnessProgram_v0_p2wsh_empty
    (fuel : Nat) (witness : WitnessStack) (program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (h32 : program.size = 32) (hemp : witness.length = 0) :
    verifyWitnessProgram fuel witness 0 program flags pol chk isP2SH
      = VerifyOutcome.fail .witnessProgramWitnessEmpty := by
  unfold verifyWitnessProgram
  rw [ite_eq_left rfl, ite_eq_left h32, ite_eq_left hemp]

/-- **SCR-135**: a non-empty witness whose last item does not hash to the
program is `WITNESS_PROGRAM_MISMATCH` (fail-closed, no script run). -/
@[rule "SCR-135"]
theorem verifyWitnessProgram_v0_p2wsh_mismatch
    (fuel : Nat) (witness : WitnessStack) (program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (h32 : program.size = 32) (hne : witness.length ≠ 0)
    (hmis : (hashSha256 (witness.getLast!) == program) = false) :
    verifyWitnessProgram fuel witness 0 program flags pol chk isP2SH
      = VerifyOutcome.fail .witnessProgramMismatch := by
  unfold verifyWitnessProgram
  rw [ite_eq_left rfl, ite_eq_left h32, ite_eq_right hne]
  have hb : (hashSha256 (witness.getLast!) != program) = true := by
    rw [bne, hmis]; simp
  rw [ite_eq_left hb]

/-! ## SCR-136 / SWT-006 — P2WPKH (v0, 20-byte program) -/

/-- **SCR-136**: a 20-byte v0 program requires exactly two witness items;
any other length is `WITNESS_PROGRAM_MISMATCH`. -/
@[rule "SCR-136"]
theorem verifyWitnessProgram_v0_p2wpkh_wrong_len
    (fuel : Nat) (witness : WitnessStack) (program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (h20 : program.size = 20) (hw : witness.length ≠ 2) :
    verifyWitnessProgram fuel witness 0 program flags pol chk isP2SH
      = VerifyOutcome.fail .witnessProgramMismatch := by
  have hsz : program.size ≠ 32 := by omega
  unfold verifyWitnessProgram
  rw [ite_eq_left rfl, ite_eq_right hsz, ite_eq_left h20, ite_eq_left hw]

/-- **SWT-006**: the script executed for a P2WPKH spend is exactly
`OP_DUP OP_HASH160 <program> OP_EQUALVERIFY OP_CHECKSIG`. -/
@[rule "SWT-006"]
theorem verifyWitnessProgram_v0_p2wpkh_script
    (fuel : Nat) (witness : WitnessStack) (program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (h20 : program.size = 20) (hw : witness.length = 2) :
    verifyWitnessProgram fuel witness 0 program flags pol chk isP2SH
      = executeWitnessScript fuel witness (witnessSerSize witness)
          (List.toByteArray [0x76, 0xa9, 0x14] ++ program ++
            List.toByteArray [0x88, 0xac]) flags pol chk .witnessV0 := by
  have hsz : program.size ≠ 32 := by omega
  have hw' : ¬ (witness.length ≠ 2) := by omega
  unfold verifyWitnessProgram
  rw [ite_eq_left rfl, ite_eq_right hsz, ite_eq_left h20, ite_eq_right hw']

end BitcoinProofs.AF.PDW75
