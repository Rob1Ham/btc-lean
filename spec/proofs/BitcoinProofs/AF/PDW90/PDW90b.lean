import Bitcoin.Interpreter.Defs

/-! # PDW90b — SCR-158 tapscript pubkey-size rules

Row face over `evalChecksigTapscript`: 0-byte pubkey fails, 32-byte
pubkey routes to BIP340 Schnorr (accept/fail on the checker verdict),
and the empty signature with a 32-byte key yields `false` unchanged. -/

namespace BitcoinProofs.AF.PDW90b
open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Crypto.Seam

/-- **SCR-158 (0)**: a non-empty signature against a 0-byte pubkey fails
with TAPSCRIPT_EMPTY_PUBKEY after the weight check. -/
@[rule "SCR-158"]
theorem evalChecksigTapscript_empty_pubkey_fails
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk : pk.size = 0)
    (hvw : 0 ≤ (vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED) :
    evalChecksigTapscript pol chk ed sig pk vw = .error .tapscriptEmptyPubkey := by
  simp [evalChecksigTapscript, hsig, hpk,
    show ¬((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED < 0) by omega]

/-- **SCR-158 (0, empty sig)**: the zero pubkey fails in the empty-signature
arm as well — the empty-pubkey check precedes the `!sig.empty()` return, so
`0 ⇒ fail` covers both signature shapes. -/
@[rule "SCR-158"]
theorem evalChecksigTapscript_empty_pubkey_fails_empty_sig
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (pk : ByteArray) (vw : Option Int) (hpk : pk.size = 0) :
    evalChecksigTapscript pol chk ed ByteArray.empty pk vw =
      .error .tapscriptEmptyPubkey := by
  simp [evalChecksigTapscript, hpk]

/-- **SCR-158 (32)**: a 32-byte pubkey takes the Schnorr lane; a false
checker verdict aborts with SCHNORR_SIG (never falls through to the
upgradable arm). -/
@[rule "SCR-158"]
theorem evalChecksigTapscript_32_is_schnorr
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk : pk.size = 32)
    (hbad : checkSchnorrWithContext chk sig pk .tapscript ed = .error .schnorrSig)
    (hvw : 0 ≤ (vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED) :
    evalChecksigTapscript pol chk ed sig pk vw = .error .schnorrSig := by
  simp [evalChecksigTapscript, hsig, hpk, hbad,
    show ¬((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED < 0) by omega]

/-- **SCR-158 (32, schnorr accept)**: a 32-byte pubkey with a passing
BIP340 check returns `true` and the decremented validation-weight budget —
the success side of the Schnorr lane. -/
@[rule "SCR-158"]
theorem evalChecksigTapscript_32_schnorr_ok
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk : pk.size = 32)
    (hok : checkSchnorrWithContext chk sig pk .tapscript ed = .ok ())
    (hvw : 0 ≤ (vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED) :
    evalChecksigTapscript pol chk ed sig pk vw =
      .ok (true, some ((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED)) := by
  simp [evalChecksigTapscript, hsig, hpk, hok,
    show ¬((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED < 0) by omega]

/-- **SCR-158 (32, empty sig)**: the empty signature is resolved BEFORE
Schnorr verification: with a 32-byte key it returns `false` and leaves
the budget untouched (BIP342 `!sig.empty()` branch). -/
@[rule "SCR-158"]
theorem evalChecksigTapscript_empty_sig_32
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (pk : ByteArray) (vw : Option Int) (hpk : pk.size = 32) :
    evalChecksigTapscript pol chk ed ByteArray.empty pk vw = .ok (false, vw) := by
  simp [evalChecksigTapscript, hpk]

/-- **SCR-158 (other sizes ⇒ upgradable)**: a pubkey size outside `{0,32}`
is the future-key-version lane. Under the default (non-discouraging)
policy it is counted as a successful sigop: `true`, with the weight budget
decremented exactly once. -/
@[rule "SCR-158"]
theorem evalChecksigTapscript_upgradable
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk0 : pk.size ≠ 0) (hpk32 : pk.size ≠ 32)
    (hpol : pol.discourageUpgradablePubkeyType = false)
    (hvw : 0 ≤ (vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED) :
    evalChecksigTapscript pol chk ed sig pk vw =
      .ok (true, some ((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED)) := by
  simp [evalChecksigTapscript, hsig, hpk0, hpk32, hpol,
    show ¬((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED < 0) by omega]

/-- **SCR-158 (other sizes, empty sig)**: the same upgradable lane with an
empty signature returns `false` and leaves the budget untouched. -/
@[rule "SCR-158"]
theorem evalChecksigTapscript_upgradable_empty_sig
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (pk : ByteArray) (vw : Option Int)
    (hpk0 : pk.size ≠ 0) (hpk32 : pk.size ≠ 32)
    (hpol : pol.discourageUpgradablePubkeyType = false) :
    evalChecksigTapscript pol chk ed ByteArray.empty pk vw = .ok (false, vw) := by
  simp [evalChecksigTapscript, hpk0, hpk32, hpol]

/-- **SCR-158 (other sizes, discouraged)**: with
`DISCOURAGE_UPGRADABLE_PUBKEYTYPE` set the unknown-key lane errors
(TPR-027's policy arm) instead of succeeding. -/
@[rule "SCR-158"]
theorem evalChecksigTapscript_upgradable_discouraged
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk0 : pk.size ≠ 0) (hpk32 : pk.size ≠ 32)
    (hpol : pol.discourageUpgradablePubkeyType = true)
    (hvw : 0 ≤ (vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED) :
    evalChecksigTapscript pol chk ed sig pk vw =
      .error .discourageUpgradablePubkeyType := by
  simp [evalChecksigTapscript, hsig, hpk0, hpk32, hpol,
    show ¬((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED < 0) by omega]

end BitcoinProofs.AF.PDW90b

/-- info: 'BitcoinProofs.AF.PDW90b.evalChecksigTapscript_empty_pubkey_fails' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW90b.evalChecksigTapscript_empty_pubkey_fails
/-- info: 'BitcoinProofs.AF.PDW90b.evalChecksigTapscript_32_is_schnorr' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW90b.evalChecksigTapscript_32_is_schnorr
/-- info: 'BitcoinProofs.AF.PDW90b.evalChecksigTapscript_empty_sig_32' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW90b.evalChecksigTapscript_empty_sig_32
