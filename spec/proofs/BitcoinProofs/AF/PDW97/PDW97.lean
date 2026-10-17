import Bitcoin.Interpreter.Defs

/-! # PDW97 — SCR-154: DISCOURAGE_OP_SUCCESS is policy-only

Route B row faces on `executeWitnessScript` (Defs.lean:1175-1180). An
OP_SUCCESSx in a tapscript overrides every later check; the policy word
`discourageOpSuccess` decides fail-vs-succeed. Zero core writes.
-/

namespace BitcoinProofs.AF.PDW97

open Bitcoin.Interpreter

/-- **SCR-154 (policy on)**: in a tapscript execution, an OP_SUCCESSx
fails with `DISCOURAGE_OP_SUCCESS` when the policy bit is set — before
the stack-size/item-size/execution checks. -/
@[rule "SCR-154"]
theorem executeWitnessScript_opSuccess_discouraged
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker)
    (hscan : opSuccessScan exec = true)
    (hpol : pol.discourageOpSuccess = true) :
    executeWitnessScript fuel items vwSer exec flags pol chk .tapscript
      = .fail .discourageOpSuccess := by
  rw [executeWitnessScript]
  simp [hscan, hpol]

/-- **SCR-154 (policy off)**: with the policy bit clear the same
OP_SUCCESSx makes the tapscript spend succeed, even when an item exceeds
the 520-byte element limit — the OP_SUCCESS override is unconditional. -/
@[rule "SCR-154"]
theorem executeWitnessScript_opSuccess_accepted
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker)
    (hscan : opSuccessScan exec = true)
    (hpol : pol.discourageOpSuccess = false) :
    executeWitnessScript fuel items vwSer exec flags pol chk .tapscript = .ok := by
  rw [executeWitnessScript]
  simp [hscan, hpol]

/-- **SCR-154 (consensus projection)**: the default/consensus policy word
leaves DISCOURAGE_OP_SUCCESS off, so an OP_SUCCESSx tapscript succeeds. -/
@[rule "SCR-154"]
theorem executeWitnessScript_opSuccess_consensus
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (chk : ScriptChecker)
    (hscan : opSuccessScan exec = true) :
    executeWitnessScript fuel items vwSer exec flags (default : PolicyFlags) chk .tapscript
      = .ok := by
  exact executeWitnessScript_opSuccess_accepted fuel items vwSer exec flags
    (default : PolicyFlags) chk hscan rfl

end BitcoinProofs.AF.PDW97

#print axioms BitcoinProofs.AF.PDW97.executeWitnessScript_opSuccess_discouraged
#print axioms BitcoinProofs.AF.PDW97.executeWitnessScript_opSuccess_accepted
#print axioms BitcoinProofs.AF.PDW97.executeWitnessScript_opSuccess_consensus
