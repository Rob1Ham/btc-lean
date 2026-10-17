import Bitcoin.Interpreter.Defs

/-! # PDW93 — hard-tail row faces: OP_SUCCESSx table + witness stack limit

Route B (proofs-side), zero core writes. Rows TPR-060 (`isOpSuccessWire`)
and TPR-066 (`executeWitnessScript` initial stack limit). -/

namespace BitcoinProofs.AF.PDW93
open Bitcoin.Interpreter

/-! ## TPR-060 — the OP_SUCCESSx wire set (script.cpp:365-371) -/

/-- TPR-060: exact membership characterization of `IsOpSuccess`
(the seven literal blocks of BIP342). -/
@[rule "TPR-060"]
theorem isOpSuccessWire_iff (w : Nat) :
    isOpSuccessWire w = true ↔
      w = 80 ∨ w = 98 ∨
      (126 ≤ w ∧ w ≤ 129) ∨
      (131 ≤ w ∧ w ≤ 134) ∨
      (137 ≤ w ∧ w ≤ 138) ∨
      (141 ≤ w ∧ w ≤ 142) ∨
      (149 ≤ w ∧ w ≤ 153) ∨
      (187 ≤ w ∧ w ≤ 254) := by
  simp [isOpSuccessWire]

/-- TPR-060: boundary witnesses — both ends of the 187..254 block and the
two single-byte members, with the neighbours just outside the set. -/
@[rule "TPR-060"]
theorem isOpSuccessWire_matrix :
    isOpSuccessWire 0x50 = true ∧ isOpSuccessWire 0x62 = true ∧
    isOpSuccessWire 0xbb = true ∧ isOpSuccessWire 0xfe = true ∧
    isOpSuccessWire 0x4f = false ∧ isOpSuccessWire 0xba = false ∧
    isOpSuccessWire 0xff = false := by
  decide

/-! ## TPR-066 — initial witness-stack limit, after the success scan -/

/-- TPR-066: for a tapscript whose OP_SUCCESSx scan is negative, an
oversized initial stack fails `STACK_SIZE` before any execution. -/
@[rule "TPR-066"]
theorem executeWitnessScript_stack_limit
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (hscan : opSuccessScan exec = false)
    (hbig : MAX_STACK_SIZE < items.length) :
    executeWitnessScript fuel items vwSer exec flags pol chk .tapscript
      = .fail .stackSize := by
  unfold executeWitnessScript
  simp [hscan, hbig]

/-- TPR-066 (ordering): a positive OP_SUCCESSx scan wins over an oversized
initial stack, so the limit is consulted only after the scan. -/
@[rule "TPR-066"]
theorem executeWitnessScript_opSuccess_precedes_stack_limit
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (hscan : opSuccessScan exec = true)
    (hpol : pol.discourageOpSuccess = false) :
    executeWitnessScript fuel items vwSer exec flags pol chk .tapscript = .ok := by
  unfold executeWitnessScript
  simp [hscan, hpol]

end BitcoinProofs.AF.PDW93

/-! ## Axiom pins (charter subset `[propext, Classical.choice, Quot.sound]`) -/

/-- info: 'BitcoinProofs.AF.PDW93.isOpSuccessWire_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.isOpSuccessWire_iff
/-- info: 'BitcoinProofs.AF.PDW93.isOpSuccessWire_matrix' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.isOpSuccessWire_matrix
/-- info: 'BitcoinProofs.AF.PDW93.executeWitnessScript_stack_limit' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.executeWitnessScript_stack_limit
/-- info: 'BitcoinProofs.AF.PDW93.executeWitnessScript_opSuccess_precedes_stack_limit' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW93.executeWitnessScript_opSuccess_precedes_stack_limit
