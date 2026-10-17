import Bitcoin.Interpreter.Defs
import Mathlib.Tactic

/-! # PDW82b — TOP-431..435: OP_SUCCESS override + BIP341 annex detection

Row faces for SCR-153 (`executeWitnessScript` OP_SUCCESSx pre-scan) and
SCR-143 (`verifyWitnessProgram` taproot annex predicate).
-/

namespace BitcoinProofs.AF.PDW82b

open Bitcoin.Interpreter Bitcoin.Data

/-! ## SCR-153 — OP_SUCCESSx overrides all later checks -/

/-- SCR-153: on the tapscript path a successful OP_SUCCESSx scan yields
success before the item-size and stack limits are consulted (the
discourage-op-success policy turns it into that policy failure). -/
@[rule "SCR-153"]
theorem executeWitnessScript_opSuccess_ok
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (hscan : opSuccessScan exec = true)
    (hpol : pol.discourageOpSuccess = false) :
    executeWitnessScript fuel items vwSer exec flags pol chk .tapscript = .ok := by
  unfold executeWitnessScript
  rw [if_pos rfl, if_pos hscan, if_neg (by simp [hpol])]

/-- SCR-153 (policy lane): with the discourage flag the same pre-scan
fails with `discourageOpSuccess`, still ahead of every size check. -/
@[rule "SCR-153"]
theorem executeWitnessScript_opSuccess_discouraged
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (hscan : opSuccessScan exec = true)
    (hpol : pol.discourageOpSuccess = true) :
    executeWitnessScript fuel items vwSer exec flags pol chk .tapscript
      = .fail .discourageOpSuccess := by
  unfold executeWitnessScript
  rw [if_pos rfl, if_pos hscan, if_pos hpol]

end BitcoinProofs.AF.PDW82b
