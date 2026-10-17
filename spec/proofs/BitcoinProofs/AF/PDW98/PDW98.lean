import Bitcoin.Interpreter.Defs

/-! # PDW98 — final promotion push: push canonicality / fExec gate / scriptCode

Row faces on `Bitcoin.Interpreter.Defs` only (route B, zero core writes):
SCR-048 (MINIMALDATA push canonicality), SCR-049 (fExec-gated push
checks), SWT-048 (scriptCode = witnessScript from last executed
OP_CODESEPARATOR). -/

namespace BitcoinProofs.AF.PDW98

open Bitcoin.Interpreter Bitcoin.Crypto.Seam

/-- SCR-048: under MINIMALDATA an executed non-canonical push is rejected
with `minimalData` (interpreter.cpp:CheckMinimalPush / EvalScript:488). -/
@[rule "SCR-048"]
theorem stepBody_pushBytes_nonminimal
    (ctx : Ctx) (op : WireOp) (st : State) (d : ByteArray)
    (ha : op.ast = .pushBytes d)
    (hsize : d.size ≤ MAX_SCRIPT_ELEMENT_SIZE)
    (hbudget : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hdis : disabledWire op.wire = false)
    (hcodesep : ¬ (op.wire = 0xab ∧ ctx.sv = .base ∧ ctx.pol.constScriptCode = true))
    (hfe : st.vf.all id = true)
    (hmin : ctx.pol.minimalData = true)
    (hchk : checkMinimalPush d op.wire = false) :
    stepBody ctx op st = .error .minimalData := by
  rw [stepBody]
  by_cases hc : (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire
  · have hb : ¬ MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
      intro hlt; exact hbudget ⟨hc.1, hc.2, hlt⟩
    simp [ha, hsize, hc, hb, hdis, hcodesep, hfe, hmin, hchk]
  · simp [ha, hsize, hc, hdis, hcodesep, hfe, hmin, hchk]

/-- SCR-048 (accept face): an executed canonical push appends its data. -/
@[rule "SCR-048"]
theorem stepBody_pushBytes_minimal_ok
    (ctx : Ctx) (op : WireOp) (st : State) (d : ByteArray)
    (ha : op.ast = .pushBytes d)
    (hsize : d.size ≤ MAX_SCRIPT_ELEMENT_SIZE)
    (hbudget : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hdis : disabledWire op.wire = false)
    (hcodesep : ¬ (op.wire = 0xab ∧ ctx.sv = .base ∧ ctx.pol.constScriptCode = true))
    (hfe : st.vf.all id = true)
    (hmin : ctx.pol.minimalData = true)
    (hchk : checkMinimalPush d op.wire = true) :
    stepBody ctx op st =
      .ok { st with
        opCount := (if (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire
          then st.opCount + 1 else st.opCount),
        stack := d :: st.stack } := by
  rw [stepBody]
  by_cases hc : (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire
  · have hb : ¬ MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
      intro hlt; exact hbudget ⟨hc.1, hc.2, hlt⟩
    simp [ha, hsize, hc, hb, hdis, hcodesep, hfe, hmin, hchk]
  · simp [ha, hsize, hc, hdis, hcodesep, hfe, hmin, hchk]

/-- SCR-049: an unexecuted push is skipped — non-minimal pushes in dead
branches do not raise `minimalData`, and the stack is untouched. -/
@[rule "SCR-049"]
theorem stepBody_pushBytes_unexec_ok
    (ctx : Ctx) (op : WireOp) (st : State) (d : ByteArray)
    (ha : op.ast = .pushBytes d)
    (hsize : d.size ≤ MAX_SCRIPT_ELEMENT_SIZE)
    (hbudget : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hdis : disabledWire op.wire = false)
    (hcodesep : ¬ (op.wire = 0xab ∧ ctx.sv = .base ∧ ctx.pol.constScriptCode = true))
    (hfe : st.vf.all id = false) :
    stepBody ctx op st =
      .ok { st with opCount :=
        (if (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire then
          st.opCount + 1 else st.opCount) } := by
  rw [stepBody]
  by_cases hc : (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire
  · have hb : ¬ MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
      intro hlt; exact hbudget ⟨hc.1, hc.2, hlt⟩
    simp [ha, hsize, hc, hb, hdis, hcodesep, hfe]
  · simp [ha, hsize, hc, hdis, hcodesep, hfe]

/-- SWT-048: in a non-BASE SigVersion (witness v0) the scriptCode handed
to the checker is exactly `bytes.extract codeSep bytes.size` — the
executed witnessScript from the last executed OP_CODESEPARATOR onward,
with no FindAndDelete rewrite. -/
@[rule "SWT-048"]
theorem evalChecksigPreTapscript_scriptCode_extract
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : ScriptExecutionData) (sv : SigVersion)
    (codeSep : Nat) (bytes sig pk : ByteArray)
    (hsv : sv ≠ .base)
    (hsig : checkSigEncoding flags pol sig = none)
    (hpk : checkPubKeyEncoding flags pol sv pk = none) :
    evalChecksigPreTapscript flags pol chk ed sv codeSep bytes sig pk =
      (let f := chk.base.checkECDSASignature sig pk
          (bytes.extract codeSep bytes.size) sv ed
       if !f ∧ pol.nullFail ∧ sig.size ≠ 0 then .error .sigNullFail else .ok f) := by
  simp [evalChecksigPreTapscript, hsv, hsig, hpk]


/-- SWT-062 (tapscript face): in tapscript OP_IF/OP_NOTIF require a
minimal boolean unconditionally — the `tapscriptMinimalIf` check is NOT
gated by the policy word (BIP342 consensus; interpreter.cpp:631). -/
@[rule "SWT-062"]
theorem stepBody_if_tapscript_minimalIf
    (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o) (hw : op.wire = 0x63)
    (hbudget : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hfe : st.vf.all id = true)
    (hsv : ctx.sv = .tapscript)
    (hstack : 1 ≤ st.stack.length)
    (hvch : 1 < (topAt st.stack 1).size ∨
      ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1)) :
    stepBody ctx op st = .error .tapscriptMinimalIf := by
  have hne : st.stack ≠ [] := by intro h; rw [h] at hstack; simp at hstack
  have hnc : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire) := by
    rintro ⟨h | h, -⟩ <;> rw [hsv] at h <;> cases h
  rw [stepBody]
  by_cases hc : (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire
  · exact absurd hc hnc
  · simp [ha, hw, hc, hfe, hsv, hne, hvch,
      Bitcoin.Interpreter.stepBody.dispatchOp, disabledWire]

/-- SWT-062 (v0 contrast): for witness v0 the same non-minimal IF operand
passes when `pol.minimalIf = false` — MINIMALIF is a policy word, not a
consensus `ScriptFlags` bit (interpreter.cpp:632-637). -/
@[rule "SWT-062"]
theorem stepBody_if_v0_nonminimal_policy_off
    (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o) (hw : op.wire = 0x63)
    (hbudget : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hfe : st.vf.all id = true)
    (hsv : ctx.sv = .witnessV0)
    (hminif : ctx.pol.minimalIf = false)
    (hstack : 1 ≤ st.stack.length) :
    stepBody ctx op st =
      .ok { st with
        vf := Bitcoin.Numeric.castToBool (topAt st.stack 1) :: st.vf,
        stack := st.stack.tail,
        opCount := (if (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire
          then st.opCount + 1 else st.opCount) } := by
  have hne : st.stack ≠ [] := by intro h; rw [h] at hstack; simp at hstack
  rw [stepBody]
  by_cases hc : (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire
  · have hb : ¬ MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
      intro hlt; exact hbudget ⟨hc.1, hc.2, hlt⟩
    simp only [ha, hw, hc, hb, hfe, hsv, hminif, hne,
      Bitcoin.Interpreter.stepBody.dispatchOp, disabledWire]
    simp [hb, hne]
  · exact absurd ⟨Or.inr hsv, by rw [hw]; decide⟩ hc

/-- SCR-051: the numeric decoder rejects a non-minimal CScriptNum encoding
whenever the minimal-data gate is on. -/
@[rule "SCR-051"]
theorem decodeNum_nonminimal
    (pol : PolicyFlags) (b : ByteArray) (maxSize : Nat)
    (hmin : pol.minimalData = true)
    (hdec : Bitcoin.Numeric.decodeScriptNum b true maxSize = none) :
    decodeNum pol b maxSize = .error .scriptNum := by
  unfold decodeNum
  rw [hmin, hdec]

/-- SCR-051 (CLTV face): OP_CHECKLOCKTIMEVERIFY's numeric operand is read
through exactly `decodeNum … 5`, so under MINIMALDATA a non-canonical
operand fails with `scriptNum`. -/
@[rule "SCR-051"]
theorem stepBody_cltv_nonminimal
    (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o) (hw : op.wire = 0xb1)
    (hbudget : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hfe : st.vf.all id = true)
    (hcltv : ctx.flags.cltv = true)
    (hstack : 1 ≤ st.stack.length)
    (hmin : ctx.pol.minimalData = true)
    (hdec : Bitcoin.Numeric.decodeScriptNum (topAt st.stack 1) true 5 = none) :
    stepBody ctx op st = .error .scriptNum := by
  have hne : st.stack ≠ [] := by intro h; rw [h] at hstack; simp at hstack
  rw [stepBody]
  by_cases hc : (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire
  · have hb : ¬ MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
      intro hlt; exact hbudget ⟨hc.1, hc.2, hlt⟩
    simp [ha, hw, hc, hb, hfe, hcltv, hne, decodeNum_nonminimal ctx.pol _ 5 hmin hdec,
      Bitcoin.Interpreter.stepBody.dispatchOp, disabledWire]
  · simp [ha, hw, hc, hfe, hcltv, hne, decodeNum_nonminimal ctx.pol _ 5 hmin hdec,
      Bitcoin.Interpreter.stepBody.dispatchOp, disabledWire]
    intro hA
    rw [if_pos hA]
    exact Nat.le_of_not_lt fun hlt => hbudget ⟨hA, by rw [hw]; decide, hlt⟩

/-- SCR-051 (CSV face): OP_CHECKSEQUENCEVERIFY's numeric operand is read
through exactly `decodeNum … 5`, so under MINIMALDATA a non-canonical
operand fails with `scriptNum` (interpreter.cpp:584). -/
@[rule "SCR-051"]
theorem stepBody_csv_nonminimal
    (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o) (hw : op.wire = 0xb2)
    (hbudget : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hfe : st.vf.all id = true)
    (hcsv : ctx.flags.csv = true)
    (hstack : 1 ≤ st.stack.length)
    (hmin : ctx.pol.minimalData = true)
    (hdec : Bitcoin.Numeric.decodeScriptNum (topAt st.stack 1) true 5 = none) :
    stepBody ctx op st = .error .scriptNum := by
  have hne : st.stack ≠ [] := by intro h; rw [h] at hstack; simp at hstack
  rw [stepBody]
  by_cases hc : (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire
  · have hb : ¬ MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
      intro hlt; exact hbudget ⟨hc.1, hc.2, hlt⟩
    simp [ha, hw, hc, hb, hfe, hcsv, hne, decodeNum_nonminimal ctx.pol _ 5 hmin hdec,
      Bitcoin.Interpreter.stepBody.dispatchOp, disabledWire]
  · simp [ha, hw, hc, hfe, hcsv, hne, decodeNum_nonminimal ctx.pol _ 5 hmin hdec,
      Bitcoin.Interpreter.stepBody.dispatchOp, disabledWire]
    intro hA
    rw [if_pos hA]
    exact Nat.le_of_not_lt fun hlt => hbudget ⟨hA, by rw [hw]; decide, hlt⟩

/-- SCR-051 (CMS key-count face): `GetSigOpCount`'s OP_CHECKMULTISIG key
count (`CScriptNum(stacktop(-1), fRequireMinimal)`) is non-minimal ⇒
`scriptNum` (interpreter.cpp:1126). -/
@[rule "SCR-051"]
theorem checkMultiSig_keycount_nonminimal
    (ctx : Ctx) (st : State) (w : Nat)
    (hsv : (ctx.sv = SigVersion.tapscript) = false)
    (hstack : 1 ≤ st.stack.length)
    (hmin : ctx.pol.minimalData = true)
    (hdec : Bitcoin.Numeric.decodeScriptNum (topAt st.stack 1) true 4 = none) :
    stepBody.checkMultiSig ctx w st = .error .scriptNum := by
  have hlt : ¬ st.stack.length < 1 := by omega
  unfold stepBody.checkMultiSig
  simp [hsv, hlt, decodeNum_nonminimal ctx.pol _ 4 hmin hdec]

/-- SCR-051 (CMS sig-count face): after the key count decodes in range,
the signature count at depth `nKeys + 2` is decoded with the same
minimal-data rule — a non-minimal encoding fails with `scriptNum`
(interpreter.cpp:1140). -/
@[rule "SCR-051"]
theorem checkMultiSig_sigcount_nonminimal
    (ctx : Ctx) (st : State) (w : Nat) (nkv : Bitcoin.Numeric.ScriptNum)
    (hsv : (ctx.sv = SigVersion.tapscript) = false)
    (hne0 : st.stack ≠ [])
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hmin : ctx.pol.minimalData = true)
    (hdec : Bitcoin.Numeric.decodeScriptNum
      (st.stack[nkv.toNat + 1]?.getD default) true 4 = none) :
    stepBody.checkMultiSig ctx w st = .error .scriptNum := by
  unfold stepBody.checkMultiSig
  simp [hsv, hne0, hd1, hrange, hop, hlen2,
    decodeNum_nonminimal ctx.pol _ 4 hmin hdec]

/-- SCR-051 (CHECKSIGADD-num face): BIP342's OP_CHECKSIGADD decodes its
`num` operand with the 4-byte `CScriptNum` constructor; a non-minimal
encoding fails with `scriptNum` before the signature check
(interpreter.cpp:1103). -/
@[rule "SCR-051"]
theorem stepBody_checksigadd_nonminimal
    (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o) (hw : op.wire = 0xba)
    (hbudget : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hfe : st.vf.all id = true)
    (hsv : ctx.sv = .tapscript)
    (hstack : 3 ≤ st.stack.length)
    (hmin : ctx.pol.minimalData = true)
    (hdec : Bitcoin.Numeric.decodeScriptNum (topAt st.stack 2) true 4 = none) :
    stepBody ctx op st = .error .scriptNum := by
  have hlt3 : ¬ st.stack.length < 3 := by omega
  rw [stepBody]
  by_cases hc : (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire
  · have hb : ¬ MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
      intro hlt; exact hbudget ⟨hc.1, hc.2, hlt⟩
    simp [ha, hw, hc, hb, hfe, hsv, hlt3,
      decodeNum_nonminimal ctx.pol _ 4 hmin hdec,
      Bitcoin.Interpreter.stepBody.dispatchOp, disabledWire, checksigAddStep]
  · simp [ha, hw, hc, hfe, hsv, hlt3,
      decodeNum_nonminimal ctx.pol _ 4 hmin hdec,
      Bitcoin.Interpreter.stepBody.dispatchOp, disabledWire, checksigAddStep]

end BitcoinProofs.AF.PDW98

/-! ## Axiom pins (subset [propext, Classical.choice, Quot.sound]) -/
#print axioms BitcoinProofs.AF.PDW98.stepBody_pushBytes_nonminimal
#print axioms BitcoinProofs.AF.PDW98.stepBody_pushBytes_minimal_ok
#print axioms BitcoinProofs.AF.PDW98.stepBody_pushBytes_unexec_ok
#print axioms BitcoinProofs.AF.PDW98.evalChecksigPreTapscript_scriptCode_extract
#print axioms BitcoinProofs.AF.PDW98.stepBody_if_tapscript_minimalIf
#print axioms BitcoinProofs.AF.PDW98.stepBody_if_v0_nonminimal_policy_off
#print axioms BitcoinProofs.AF.PDW98.decodeNum_nonminimal
#print axioms BitcoinProofs.AF.PDW98.stepBody_cltv_nonminimal
#print axioms BitcoinProofs.AF.PDW98.stepBody_csv_nonminimal
#print axioms BitcoinProofs.AF.PDW98.checkMultiSig_keycount_nonminimal
#print axioms BitcoinProofs.AF.PDW98.checkMultiSig_sigcount_nonminimal
#print axioms BitcoinProofs.AF.PDW98.stepBody_checksigadd_nonminimal
