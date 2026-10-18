import Bitcoin.Interpreter.Defs

/-! # PDW84b — TOP-443/444 row faces: `cmsLoop` order + encoding checks

Route B, zero core writes. Row faces of `cmsLoop`
(interpreter.cpp:1187-1210): sigs walk keys in order with an early
false when the remaining sigs strictly outnumber the remaining keys
(SCR-116), and CheckSignatureEncoding / CheckPubKeyEncoding run per
(sig,key) pair before the checker (SCR-117). -/

namespace BitcoinProofs.AF.PDW84

open Bitcoin.Interpreter

/-- **SCR-116 (terminal)**: zero remaining sigs ⇒ success without any
key/encoding/checker access. -/
@[rule "SCR-116"]
theorem cmsLoop_zero_sigs_row (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (sv : Bitcoin.Crypto.Seam.SigVersion)
    (chk : ScriptChecker) (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (sc : ByteArray) (st : Stack) (fuel nKeys isig ikey : Nat) :
    cmsLoop flags pol sv chk ed sc st fuel nKeys 0 isig ikey = .ok true := by
  cases fuel with
  | zero => rw [cmsLoop.eq_1]; simp
  | succ k => rw [cmsLoop.eq_2]; simp

/-- **SCR-116 (order step)**: on a passing (sig,key) pair whose verdict
is `true`, the loop advances the signature index and the key index
together and decrements both counts — the in-order pairing invariant. -/
@[rule "SCR-116"]
theorem cmsLoop_order_step_row (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (sv : Bitcoin.Crypto.Seam.SigVersion)
    (chk : ScriptChecker) (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (sc : ByteArray) (st : Stack) (k nKeys nSigs isig ikey : Nat)
    (hns : nSigs ≠ 0)
    (hsig : checkSigEncoding flags pol (st[isig-1]!) = none)
    (hpk : checkPubKeyEncoding flags pol sv (st[ikey-1]!) = none)
    (hok : chk.base.checkECDSASignature (st[isig-1]!) (st[ikey-1]!) sc sv ed = true)
    (hcond : ¬ (nSigs - 1 > nKeys - 1)) :
    cmsLoop flags pol sv chk ed sc st (k+1) nKeys nSigs isig ikey
      = cmsLoop flags pol sv chk ed sc st k (nKeys - 1) (nSigs - 1)
          (isig + 1) (ikey + 1) := by
  rw [cmsLoop.eq_2]
  simp only [hns, ite_false, hsig, hpk, hok, ite_true]
  rw [ite_eq_right hcond]

/-- **SCR-116 (early false)**: when the sigs strictly outnumber the keys
by at least one spare key (nSigs ≥ nKeys+2), the count test fires on the
first step whatever the checker says. (The boundary nSigs = nKeys+1 is
unreachable from `checkMultiSig`, which rejects `nSigs > nKeys` with
`sigCount`.) -/
@[rule "SCR-116"]
theorem cmsLoop_early_false_row (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (sv : Bitcoin.Crypto.Seam.SigVersion)
    (chk : ScriptChecker) (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (sc : ByteArray) (st : Stack) (k nKeys nSigs isig ikey : Nat)
    (hns : nSigs ≠ 0) (hgt : nKeys + 1 < nSigs)
    (hsig : checkSigEncoding flags pol (st[isig-1]!) = none)
    (hpk : checkPubKeyEncoding flags pol sv (st[ikey-1]!) = none) :
    cmsLoop flags pol sv chk ed sc st (k+1) nKeys nSigs isig ikey = .ok false := by
  rw [cmsLoop.eq_2]
  simp only [hns, ite_false, hsig, hpk]
  by_cases hok : chk.base.checkECDSASignature (st[isig-1]!) (st[ikey-1]!) sc sv ed = true
  · simp only [hok, ite_true]
    have h2 : nSigs - 1 > nKeys - 1 := by omega
    simp [h2]
  · simp only [hok]
    have h2 : nSigs > nKeys - 1 := by omega
    simp [h2]

/-- **SCR-117 (signature encoding)**: a non-empty invalid DER/high-S/
hashtype signature aborts the loop with that error before the checker. -/
@[rule "SCR-117"]
theorem cmsLoop_sigEncoding_error_row (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (sv : Bitcoin.Crypto.Seam.SigVersion)
    (chk : ScriptChecker) (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (sc : ByteArray) (st : Stack) (k nKeys nSigs isig ikey : Nat)
    (err : ExecError) (hns : nSigs ≠ 0)
    (hsig : checkSigEncoding flags pol (st[isig-1]!) = some err) :
    cmsLoop flags pol sv chk ed sc st (k+1) nKeys nSigs isig ikey = .error err := by
  rw [cmsLoop.eq_2]
  simp only [hns, ite_false]
  rw [hsig]

/-- **SCR-117 (pubkey encoding)**: with a clean signature, an invalid
pubkey encoding aborts the pair with that error before the checker. -/
@[rule "SCR-117"]
theorem cmsLoop_pubkeyEncoding_error_row (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (sv : Bitcoin.Crypto.Seam.SigVersion)
    (chk : ScriptChecker) (ed : Bitcoin.Crypto.Seam.ScriptExecutionData)
    (sc : ByteArray) (st : Stack) (k nKeys nSigs isig ikey : Nat)
    (err : ExecError) (hns : nSigs ≠ 0)
    (hsig : checkSigEncoding flags pol (st[isig-1]!) = none)
    (hpk : checkPubKeyEncoding flags pol sv (st[ikey-1]!) = some err) :
    cmsLoop flags pol sv chk ed sc st (k+1) nKeys nSigs isig ikey = .error err := by
  rw [cmsLoop.eq_2]
  simp only [hns, ite_false]
  rw [hsig]
  simp only [hpk]

end BitcoinProofs.AF.PDW84


/-- info: 'BitcoinProofs.AF.PDW84.cmsLoop_zero_sigs_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.cmsLoop_zero_sigs_row

/-- info: 'BitcoinProofs.AF.PDW84.cmsLoop_order_step_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.cmsLoop_order_step_row

/-- info: 'BitcoinProofs.AF.PDW84.cmsLoop_early_false_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.cmsLoop_early_false_row

/-- info: 'BitcoinProofs.AF.PDW84.cmsLoop_sigEncoding_error_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.cmsLoop_sigEncoding_error_row

/-- info: 'BitcoinProofs.AF.PDW84.cmsLoop_pubkeyEncoding_error_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.cmsLoop_pubkeyEncoding_error_row
