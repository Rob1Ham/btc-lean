import Bitcoin.Interpreter.Defs

/-! # PDW60 RowsC — replacement rows TOP-321/323/324 (RC29).

Swap-in rows after concurrent flips of SCR-163/SCR-172/INV-086:
SCR-150 (v1 anchor program succeeds unexecuted), SCR-151 (upgradable
witness versions succeed), SCR-152 (the legacy-disabled wire set).
Route B: row faces on `Bitcoin.Interpreter` declarations, zero core writes.
-/

namespace BitcoinProofs.AF.PDW60

open Bitcoin.Interpreter

/-- SCR-150: a v1 witness program `4e73` (pay-to-anchor) is accepted with
NO script execution, whatever the witness/flags/policy (unless the
P2SH-wrapped dispatch applies). -/
@[rule "SCR-150"]
theorem witnessV1_anchor_ok (fuel : Nat) (w : Bitcoin.Data.WitnessStack)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) :
    verifyWitnessProgram fuel w 1 (List.toByteArray [0x4e, 0x73]) flags pol chk false
      = .ok := by
  have h : isPayToAnchor 1 (List.toByteArray [0x4e, 0x73]) = true := by decide
  unfold verifyWitnessProgram
  simp [h]

/-- SCR-151: an unknown witness version (≥ 2) is upgradable — accepted
without execution unless the policy flag discourages it. -/
@[rule "SCR-151"]
theorem witnessUnknownVersion_ok (fuel : Nat) (w : Bitcoin.Data.WitnessStack)
    (version : Nat) (program : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (hv : 2 ≤ version)
    (hd : pol.discourageUpgradableWitnessProgram = false) :
    verifyWitnessProgram fuel w version program flags pol chk isP2SH = .ok := by
  have ha : isPayToAnchor version program = false := by
    unfold isPayToAnchor
    simp [show version ≠ 1 by omega]
  unfold verifyWitnessProgram
  simp only [show version ≠ 0 by omega, ite_false]
  rw [if_neg (by simp [show version ≠ 1 by omega])]
  rw [if_neg (by simp [ha])]
  rw [if_neg (by simpa using hd)]

/-- SCR-151: a v1 program that is NOT 32 bytes is upgradable (wrong-size
v1 and P2SH-wrapped v1 both land here) — accepted unless discouraged. -/
@[rule "SCR-151"]
theorem witnessV1_non32_ok (fuel : Nat) (w : Bitcoin.Data.WitnessStack)
    (program : ByteArray) (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (chk : ScriptChecker) (isP2SH : Bool)
    (hs : program.size ≠ 32)
    (hd : pol.discourageUpgradableWitnessProgram = false) :
    verifyWitnessProgram fuel w 1 program flags pol chk isP2SH = .ok := by
  unfold verifyWitnessProgram
  simp only [show (1:Nat) ≠ 0 by omega, ite_false]
  rw [if_neg (by simp [hs])]
  by_cases h3 : ((!isP2SH) = true ∧ isPayToAnchor 1 program = true)
  · rw [if_pos h3]
  · rw [if_neg h3, if_neg (by simpa using hd)]

/-- SCR-152: the legacy-disabled wire set (CVE-2010-5137) — 15 opcodes
fail in BASE/WITNESS_V0; 0x7d/0x82/0x87 stay ordinary opcodes. -/
@[rule "SCR-152"]
theorem disabledWire_set :
    disabledWire 0x7e = true ∧ disabledWire 0x7f = true ∧
    disabledWire 0x80 = true ∧ disabledWire 0x81 = true ∧
    disabledWire 0x83 = true ∧ disabledWire 0x84 = true ∧
    disabledWire 0x85 = true ∧ disabledWire 0x86 = true ∧
    disabledWire 0x8d = true ∧ disabledWire 0x8e = true ∧
    disabledWire 0x95 = true ∧ disabledWire 0x96 = true ∧
    disabledWire 0x97 = true ∧ disabledWire 0x98 = true ∧
    disabledWire 0x99 = true ∧
    disabledWire 0x7d = false ∧ disabledWire 0x82 = false ∧
    disabledWire 0x87 = false := by
  decide


/-! ## Axiom pins (guard_msgs) -/

/-- info: 'BitcoinProofs.AF.PDW60.witnessV1_anchor_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.witnessV1_anchor_ok
/-- info: 'BitcoinProofs.AF.PDW60.witnessUnknownVersion_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.witnessUnknownVersion_ok
/-- info: 'BitcoinProofs.AF.PDW60.witnessV1_non32_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.witnessV1_non32_ok
/-- info: 'BitcoinProofs.AF.PDW60.disabledWire_set' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.disabledWire_set

end BitcoinProofs.AF.PDW60
