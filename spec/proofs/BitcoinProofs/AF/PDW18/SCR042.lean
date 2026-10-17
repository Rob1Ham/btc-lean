import Bitcoin.Interpreter.Rules

/-! # PDW18 — SCR-042 (route B: tag rides MY theorem, zero core writes)

Upgradable (non-empty, non-32-byte) tapscript pubkey still consumes the
BIP342 validation-weight budget: the decrement precedes the pubkey-size
dispatch and the upgradable arm returns the decremented budget
(interpreter.cpp:368-376 @cce32b168). Mirrors the pre-existing untagged
core twin `Bitcoin.Interpreter.evalChecksigTapscript_upgradable_key_decrements`
(Rules.lean:481); that twin and its tag sites stay untouched. -/

namespace BitcoinProofs.AF.PDW18

open Bitcoin.Interpreter
open Bitcoin.Crypto.Seam (ScriptExecutionData)

@[rule "SCR-042"]
theorem evalChecksigTapscript_upgradable_key_decrements
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk0 : pk.size ≠ 0) (hpk32 : pk.size ≠ 32)
    (hno : pol.discourageUpgradablePubkeyType = false)
    (hvw : 0 ≤ (vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED) :
    evalChecksigTapscript pol chk ed sig pk vw
      = .ok (true, some ((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED)) := by
  simp [evalChecksigTapscript, hsig, hpk0, hpk32, hno,
    show ¬((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED < 0) by omega]

end BitcoinProofs.AF.PDW18
