import Bitcoin.Interpreter.Defs

/-! # PDW73 — TOP-386..390 row faces (interpreter admission/dispatch)

Route B, zero core writes. Five `@[rule]`-tagged theorems, one per row.
-/

namespace BitcoinProofs.AF.PDW73

open Bitcoin.Interpreter
open Bitcoin.Crypto.Seam (ScriptExecutionData SigVersion)
open Bitcoin.Numeric (ScriptNum castToBool)
open Bitcoin.Data (WitnessStack)
open Bitcoin.Activation (ScriptFlags)

/-- Yield trail (F-PDW73-002): OP_NOP1/4..10 under
`DISCOURAGE_UPGRADABLE_NOPS`; SCR-071 is reserved by PDW69, so this
theorem stays untagged. -/
theorem stepBody_nop_discourage (ctx : Ctx) (st : State)
    (hf : st.vf.all id = true)
    (hsv : ctx.sv = .tapscript)
    (hpol : ctx.pol.discourageUpgradableNops = true) :
    stepBody ctx { ast := .op 0xb0, wire := 0xb0, next := 1 } st =
      .error .discourageUpgradableNops := by
  simp [stepBody, stepBody.dispatchOp, disabledWire, hf, hsv, hpol]

/-- SCR-072: without their activation flags CLTV (0xb1) and CSV (0xb2)
are plain no-ops; only the op-count budget moves. -/
@[rule "SCR-072"]
theorem stepBody_cltv_csv_noflag_nop (ctx : Ctx) (st : State) (w : Fin 256)
    (hf : st.vf.all id = true) (hsv : ctx.sv = .base)
    (hw : w.val = 0xb1 ∨ w.val = 0xb2)
    (hcltv : ctx.flags.cltv = false) (hcsv : ctx.flags.csv = false)
    (hcnt : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1)) :
    stepBody ctx { ast := .op w, wire := w.val, next := 1 } st =
      .ok { st with opCount := st.opCount + 1 } := by
  rcases hw with hw | hw <;>
    simp [stepBody, stepBody.dispatchOp, disabledWire, hf, hsv, hcltv, hcsv, hcnt, hw]

/-- SCR-121: OP_CHECKMULTISIG under tapscript is rejected with
`TAPSCRIPT_CHECKMULTISIG` before any stack inspection. -/
@[rule "SCR-121"]
theorem stepBody_tapscript_checkmultisig_ban (ctx : Ctx) (st : State)
    (hsv : ctx.sv = .tapscript) (hf : st.vf.all id = true) :
    stepBody ctx { ast := .op 0xae, wire := 0xae, next := 1 } st =
      .error .tapscriptCheckMultiSig := by
  simp [stepBody, stepBody.dispatchOp, stepBody.checkMultiSig, disabledWire, hsv, hf]

/-- INV-060: OP_CHECKSIGADD sums the decoded operand with the boolean
success flag and threads the validation-weight budget. -/
@[rule "INV-060"]
theorem checksigAddStep_ok
    (pol : Bitcoin.Interpreter.PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig num pk : ByteArray) (vw : Option Int) (n : Bitcoin.Numeric.ScriptNum)
    (success : Bool) (vw' : Option Int)
    (hd : decodeNum pol num 4 = .ok n)
    (he : evalChecksigTapscript pol chk ed sig pk vw = .ok (success, vw')) :
    checksigAddStep pol chk ed sig num pk vw =
      .ok (n + (if success then 1 else 0), vw') := by
  simp [checksigAddStep, hd, he]

/-- SCR-002: a successful `verifyScriptFull` has a successful base
scriptPubKey evaluation whose final stack is nonempty and truthy. -/
@[rule "SCR-002"]
theorem verifyScriptFull_ok_base_stack
    (fuel : Nat) (flags : Bitcoin.Activation.ScriptFlags) (pol : Bitcoin.Interpreter.PolicyFlags)
    (ss spk : ByteArray) (witness : WitnessStack) (chk : ScriptChecker)
    (hpush : pol.sigPushOnly = false)
    (h : verifyScriptFull fuel flags pol ss spk witness chk = .ok) :
    ∃ stack1 stack,
      evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1 ∧
      evalScriptBytes fuel flags pol spk stack1 chk .base default = .ok stack ∧
      stack ≠ [] ∧ castToBool stack[0]! = true := by
  unfold verifyScriptFull at h
  simp [hpush] at h
  split at h
  · simp at h
  · next stack1 hss =>
    split at h
    · simp at h
    · next stack hspk =>
      split at h
      · simp at h
      · next hgood =>
        refine ⟨stack1, stack, hss, hspk, ?_, ?_⟩
        · intro he; exact hgood (Or.inl he)
        · have hc : castToBool (stack[0]?.getD default) = true := by
            cases hb : castToBool (stack[0]?.getD default) <;>
              simp [hb] at hgood ⊢
          simpa using hc

/-- SCR-020: a non-push opcode increments nOpCount; past 201 the step is
rejected with OP_COUNT (BASE/WITNESS_V0 budget). -/
@[rule "SCR-020"]
theorem stepBody_opCount_reject (ctx : Ctx) (op : WireOp) (st : State)
    (hsize : (match op.ast with
      | .pushBytes d => d.size ≤ MAX_SCRIPT_ELEMENT_SIZE
      | _ => true) = true)
    (hsv : ctx.sv = .base) (hw : 0x60 < op.wire)
    (hcnt : MAX_OPS_PER_SCRIPT < st.opCount + 1) :
    stepBody ctx op st = .error .opCount := by
  simp [stepBody, hsv, hw, hcnt]
  exact hsize

/-- SCR-020: the consensus element cap `MAX_SCRIPT_ELEMENT_SIZE` is
literally 520 bytes (script.h:29). -/
theorem MAX_SCRIPT_ELEMENT_SIZE_eq : MAX_SCRIPT_ELEMENT_SIZE = 520 := rfl

/-- SCR-020 (the row's actual check): a push whose payload exceeds
`MAX_SCRIPT_ELEMENT_SIZE` is rejected with `SCRIPT_ERR_PUSH_SIZE`
immediately after `GetOp`, *before* the `fExec` test — hence even in an
unexecuted branch. No stack/flag/fExec hypothesis is needed. -/
@[rule "SCR-020"]
theorem stepBody_pushSize_reject (ctx : Ctx) (st : State) (d : ByteArray)
    (h : MAX_SCRIPT_ELEMENT_SIZE < d.size) :
    stepBody ctx { ast := .pushBytes d, wire := 0, next := 0 } st =
      .error .pushSize := by
  have hle : ¬ d.size ≤ MAX_SCRIPT_ELEMENT_SIZE := by omega
  simp [stepBody, hle]

end BitcoinProofs.AF.PDW73
