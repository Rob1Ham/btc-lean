import Bitcoin.Interpreter.Defs

/-! # PDW99 — SCR-139 row face: `sigversion ≠ BASE` skips FindAndDelete

Core `EvalChecksigPreTapscript` (interpreter.cpp:328-368) applies
`FindAndDelete` to the scriptCode only on the `SigVersion::BASE` arm
(BIP143): the witness-v0 and tapscript calls keep the executed script
verbatim. The executable model has the same two-armed `if sv = .base`
gate in `Bitcoin.Interpreter.Defs.evalChecksigPreTapscript`; these
theorems expose the non-BASE arm as a FindAndDelete-free expression and
show the deletion error can never surface there. -/

namespace BitcoinProofs.AF.PDW99

open Bitcoin.Interpreter Bitcoin.Crypto.Seam

/-- SCR-139: for every sigversion other than BASE the scriptCode handed
to the checker is exactly the executed script from the last
OP_CODESEPARATOR (`bytes.extract codeSep bytes.size`), with no
`FindAndDelete` rewrite and hence no `sigFindAndDelete` gate. -/
@[rule "SCR-139"]
theorem scr139_nonbase_skips_delete
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : ScriptExecutionData) (sv : SigVersion)
    (codeSep : Nat) (bytes sig pk : ByteArray) (hsv : sv ≠ .base) :
    evalChecksigPreTapscript flags pol chk ed sv codeSep bytes sig pk =
      (match checkSigEncoding flags pol sig,
             checkPubKeyEncoding flags pol sv pk with
       | some e, _ => .error e
       | _, some e => .error e
       | none, none =>
           if !chk.base.checkECDSASignature sig pk
                (bytes.extract codeSep bytes.size) sv ed ∧
              pol.nullFail ∧ sig.size ≠ 0
           then .error .sigNullFail
           else .ok (chk.base.checkECDSASignature sig pk
                (bytes.extract codeSep bytes.size) sv ed)) := by
  simp [evalChecksigPreTapscript, hsv]
  rfl

/-- The signature-encoding validator never emits `sigFindAndDelete`. -/
theorem checkSigEncoding_ne_sigFindAndDelete
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (sig : ByteArray) :
    checkSigEncoding flags pol sig ≠ some .sigFindAndDelete := by
  unfold checkSigEncoding
  repeat split <;> simp_all

/-- The pubkey-encoding validator never emits `sigFindAndDelete`. -/
theorem checkPubKeyEncoding_ne_sigFindAndDelete
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (sv : SigVersion) (pk : ByteArray) :
    checkPubKeyEncoding flags pol sv pk ≠ some .sigFindAndDelete := by
  unfold checkPubKeyEncoding
  repeat split <;> simp_all

/-- SCR-139 (error face): a non-BASE evaluation can never fail with
`SCRIPT_ERR_SIG_FINDANDDELETE`, because the deletion branch is not taken. -/
@[rule "SCR-139"]
theorem scr139_nonbase_not_sigFindAndDelete
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : ScriptExecutionData) (sv : SigVersion)
    (codeSep : Nat) (bytes sig pk : ByteArray) (hsv : sv ≠ .base) :
    evalChecksigPreTapscript flags pol chk ed sv codeSep bytes sig pk ≠
      .error .sigFindAndDelete := by
  rw [scr139_nonbase_skips_delete flags pol chk ed sv codeSep bytes sig pk hsv]
  cases h1 : checkSigEncoding flags pol sig with
  | none =>
      cases h2 : checkPubKeyEncoding flags pol sv pk with
      | none =>
          dsimp only
          split <;> simp
      | some e =>
          dsimp only
          intro he
          have h : e = .sigFindAndDelete := by injection he
          exact checkPubKeyEncoding_ne_sigFindAndDelete flags pol sv pk
            (by rw [h2, h])
  | some e =>
      dsimp only
      intro he
      have h : e = .sigFindAndDelete := by injection he
      exact checkSigEncoding_ne_sigFindAndDelete flags pol sig
        (by rw [h1, h])
end BitcoinProofs.AF.PDW99
