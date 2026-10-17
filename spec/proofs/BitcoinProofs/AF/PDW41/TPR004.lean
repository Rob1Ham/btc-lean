import Bitcoin.Crypto.Taproot.Program
import Bitcoin.Interpreter.Defs

/-! # PDW41/TPR004.lean — TPR-004 row face (P2A anchor template)

Claim v2 `d87a0cb`. Route B, zero core writes.

TPR-004: `CScript::IsPayToAnchor` (script.cpp:216-222) = witness v1 with
the 2-byte program `0x4e73`; `VerifyWitnessProgram` passes it
unconditionally (interpreter.cpp:2000-2001). Row faces: exact-template
iff, the canonical program instance, and the size partition against the
32-byte P2TR commitment template. -/

namespace BitcoinProofs.AF.PDW41

open Bitcoin.Crypto.Taproot.Program

/-- TPR-004 (template iff): the anchor predicate recognizes EXACTLY
version 1, size 2, bytes `0x4e 0x73` — no key material, no ambiguity. -/
@[rule "TPR-004"]
theorem isPayToAnchor_iff (version : Nat) (program : ByteArray) :
    isPayToAnchor version program = true ↔
      version = 1 ∧ program.size = 2 ∧ (program.get! 0).toNat = 0x4e ∧
        (program.get! 1).toNat = 0x73 := by
  unfold isPayToAnchor; simp

/-- TPR-004 (canonical instance): `OP_1 <0x4e73>` is the anchor. -/
theorem isPayToAnchor_p2a_row :
    isPayToAnchor 1 p2aProgram = true :=
  Bitcoin.Crypto.Taproot.Program.isPayToAnchor_p2a

/-- TPR-004 (partition): the anchor is NOT the v1-32 P2TR commitment
template — anchoring cannot be confused with a taproot output (and such
a spend is unencumbered: any witness validates). -/
theorem isPayToAnchor_partition :
    isPayToAnchor 1 p2aProgram = true ∧ p2trProgram 1 p2aProgram = false :=
  ⟨Bitcoin.Crypto.Taproot.Program.isPayToAnchor_p2a,
   Bitcoin.Crypto.Taproot.Program.isPayToAnchor_not_p2tr⟩

/-- TPR-004 (execution face): `VerifyWitnessProgram` on a NATIVE witness-v1
program `0x4e73` returns `.ok` for EVERY witness, flag set, policy set and
checker — no signature, key, stack or annex inspection. This is
interpreter.cpp:2000-2001: `else if (!isP2SH && IsPayToAnchor(version,
program)) return set_success(...)`. `isP2SH = false` is the native P2A
spend; the P2SH-wrapped form is deliberately outside the row. -/
@[rule "TPR-004"]
theorem verifyWitnessProgram_p2a_ok (fuel : Nat)
    (witness : Bitcoin.Data.WitnessStack)
    (flags : Bitcoin.Activation.ScriptFlags)
    (pol : Bitcoin.Interpreter.PolicyFlags)
    (chk : Bitcoin.Interpreter.ScriptChecker) :
    Bitcoin.Interpreter.verifyWitnessProgram fuel witness 1 p2aProgram
      flags pol chk false = Bitcoin.Interpreter.VerifyOutcome.ok := by
  have hsz : p2aProgram.size = 2 := by
    unfold p2aProgram Bitcoin.Data.serU8
    rw [ByteArray.size_append]; rfl
  have hp2a : Bitcoin.Interpreter.isPayToAnchor 1 p2aProgram = true := by
    unfold Bitcoin.Interpreter.isPayToAnchor p2aProgram Bitcoin.Data.serU8
    rfl
  unfold Bitcoin.Interpreter.verifyWitnessProgram
  rw [if_neg (by decide : (1 : Nat) ≠ 0)]
  rw [if_neg (by simp [hsz])]
  rw [if_pos]
  exact ⟨rfl, hp2a⟩

end BitcoinProofs.AF.PDW41
