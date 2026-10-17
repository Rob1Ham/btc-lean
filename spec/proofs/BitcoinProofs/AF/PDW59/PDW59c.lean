import Bitcoin.Interpreter.Defs

/-! # PDW59c.lean — TOP-319/320: taproot future-version witness programs

PDW59 (review RC29), claim `da681d5` (swapped rows, see findings §3).
Route B, zero core writes. Row faces for
`Bitcoin.Interpreter.verifyWitnessProgram` (Defs.lean:1214,
interpreter.cpp:2020-2032 @ cce32b168), the last two `else` arms:
SCR-151 (unknown witness versions, wrong-size v1, P2SH-wrapped v1 are
consensus-success unless the policy discouragement flag is set) and
SCR-150 (the v1 `4e73` pay-to-anchor program succeeds). -/

namespace BitcoinProofs.AF.PDW59

open Bitcoin.Interpreter

/-- SCR-151: every unknown witness version (≥ 2) succeeds when the
`discourageUpgradableWitnessProgram` policy flag is off (upgrade hook). -/
@[rule "SCR-151"]
theorem verifyWitnessProgram_future_ok (fuel : Nat) (witness : Bitcoin.Data.WitnessStack)
    (version : Nat) (program : ByteArray) (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (chk : ScriptChecker) (isP2SH : Bool)
    (h : 2 ≤ version) (hp : pol.discourageUpgradableWitnessProgram = false) :
    verifyWitnessProgram fuel witness version program flags pol chk isP2SH = .ok := by
  unfold verifyWitnessProgram
  rw [ite_eq_right (by omega : version ≠ 0)]
  rw [ite_eq_right (by rintro ⟨h1, _⟩; omega)]
  by_cases ha : !isP2SH ∧ isPayToAnchor version program
  · rw [ite_eq_left ha]
  · rw [ite_eq_right ha, ite_eq_right (by simp [hp])]

/-- SCR-151: a v1 program of the wrong size (≠ 32) succeeds (no taproot
interpretation) when the policy gate is off. -/
@[rule "SCR-151"]
theorem verifyWitnessProgram_v1_wrong_size_ok (fuel : Nat)
    (witness : Bitcoin.Data.WitnessStack) (program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (hs : program.size ≠ 32) (hp : pol.discourageUpgradableWitnessProgram = false) :
    verifyWitnessProgram fuel witness 1 program flags pol chk isP2SH = .ok := by
  unfold verifyWitnessProgram
  rw [ite_eq_right (by omega : (1 : Nat) ≠ 0)]
  rw [ite_eq_right (by rintro ⟨_, h2, _⟩; exact hs h2)]
  by_cases ha : !isP2SH ∧ isPayToAnchor 1 program
  · rw [ite_eq_left ha]
  · rw [ite_eq_right ha, ite_eq_right (by simp [hp])]

/-- SCR-151: a P2SH-wrapped v1 program is not taproot (BIP341 excludes
P2SH wrapping) and succeeds when the policy gate is off. -/
@[rule "SCR-151"]
theorem verifyWitnessProgram_v1_p2sh_ok (fuel : Nat)
    (witness : Bitcoin.Data.WitnessStack) (program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (hp2sh : isP2SH = true)
    (hp : pol.discourageUpgradableWitnessProgram = false) :
    verifyWitnessProgram fuel witness 1 program flags pol chk isP2SH = .ok := by
  unfold verifyWitnessProgram
  rw [ite_eq_right (by omega : (1 : Nat) ≠ 0)]
  rw [ite_eq_right (by rintro ⟨_, _, h3⟩; simp [hp2sh] at h3)]
  rw [ite_eq_right (by simp [hp2sh]), ite_eq_right (by simp [hp])]

/-- SCR-151, policy-on arm: every unknown witness version (≥ 2) fails with
`SCRIPT_ERR_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM` when the
`discourageUpgradableWitnessProgram` policy flag is set
(interpreter.cpp:2005-2007: `if (flags & SCRIPT_VERIFY_DISCOURAGE_...
WITNESS_PROGRAM) { return set_error(...); }`). -/
@[rule "SCR-151"]
theorem verifyWitnessProgram_future_discourage (fuel : Nat)
    (witness : Bitcoin.Data.WitnessStack) (version : Nat) (program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (h : 2 ≤ version) (hp : pol.discourageUpgradableWitnessProgram = true) :
    verifyWitnessProgram fuel witness version program flags pol chk isP2SH
      = .fail .discourageUpgradableWitnessProgram := by
  have hpa : isPayToAnchor version program = false := by
    unfold isPayToAnchor
    simp [show version ≠ 1 by omega]
  unfold verifyWitnessProgram
  rw [ite_eq_right (by omega : version ≠ 0)]
  rw [ite_eq_right (by rintro ⟨h1, _⟩; omega)]
  rw [ite_eq_right (by simp [hpa])]
  rw [ite_eq_left (by simp [hp])]

/-- SCR-151, policy-on arm: a v1 program of the wrong size (≠ 32) that is
not a pay-to-anchor program fails with
`SCRIPT_ERR_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM` when the policy gate is
set (the P2A program itself is the SCR-150 success arm). -/
@[rule "SCR-151"]
theorem verifyWitnessProgram_v1_wrong_size_discourage (fuel : Nat)
    (witness : Bitcoin.Data.WitnessStack) (program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (hs : program.size ≠ 32)
    (hpa : ¬ (!isP2SH ∧ isPayToAnchor 1 program))
    (hp : pol.discourageUpgradableWitnessProgram = true) :
    verifyWitnessProgram fuel witness 1 program flags pol chk isP2SH
      = .fail .discourageUpgradableWitnessProgram := by
  unfold verifyWitnessProgram
  rw [ite_eq_right (by omega : (1 : Nat) ≠ 0)]
  rw [ite_eq_right (by rintro ⟨_, h2, _⟩; exact hs h2)]
  rw [ite_eq_right hpa]
  rw [ite_eq_left (by simp [hp])]

/-- SCR-151, policy-on arm: a P2SH-wrapped v1 program is never taproot and
fails with `SCRIPT_ERR_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM` when the
policy gate is set. -/
@[rule "SCR-151"]
theorem verifyWitnessProgram_v1_p2sh_discourage (fuel : Nat)
    (witness : Bitcoin.Data.WitnessStack) (program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (hp2sh : isP2SH = true)
    (hp : pol.discourageUpgradableWitnessProgram = true) :
    verifyWitnessProgram fuel witness 1 program flags pol chk isP2SH
      = .fail .discourageUpgradableWitnessProgram := by
  unfold verifyWitnessProgram
  rw [ite_eq_right (by omega : (1 : Nat) ≠ 0)]
  rw [ite_eq_right (by rintro ⟨_, _, h3⟩; simp [hp2sh] at h3)]
  rw [ite_eq_right (by simp [hp2sh])]
  rw [ite_eq_left (by simp [hp])]

/-- SCR-150: the 2-byte v1 `4e73` program is pay-to-anchor and succeeds
without executing a script (consensus, independent of the policy flag). -/
@[rule "SCR-150"]
theorem verifyWitnessProgram_v1_anchor_ok (fuel : Nat)
    (witness : Bitcoin.Data.WitnessStack) (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (chk : ScriptChecker) (hp2sh : isP2SH = false) :
    verifyWitnessProgram fuel witness 1 (ByteArray.mk #[0x4e, 0x73])
      flags pol chk isP2SH = .ok := by
  unfold verifyWitnessProgram
  rw [ite_eq_right (by omega : (1 : Nat) ≠ 0)]
  rw [ite_eq_right (by rintro ⟨_, h2, _⟩; exact absurd h2 (by decide))]
  have ha : !isP2SH ∧ isPayToAnchor 1 (ByteArray.mk #[0x4e, 0x73]) := by
    simp [isPayToAnchor, hp2sh]
    decide
  rw [ite_eq_left ha]

end BitcoinProofs.AF.PDW59
