import Bitcoin.Activation.Flags
import Bitcoin.Interpreter.Defs

/-! # PDW63b.lean — TOP-336..340 policy-only flag catalogue

Row-face theorems for SCR-176..180 (route B, zero core writes): each flag
is absent from the consensus view, and MINIMALIF/CLEANSTACK are re-imported
as consensus for TAPSCRIPT (BIP342).

SCR-183 enforcement faces: the boolean `minimalIfRequired` /
`cleanStackRequired` predicates are not merely true for TAPSCRIPT; the real
`stepBody` IF/NOTIF arm and `executeWitnessScript` cleanstack arm enforce
the same requirements with no dependence on the v0 policy bits. -/

namespace BitcoinProofs.AF.PDW63b

open Bitcoin.Interpreter
open Bitcoin.Activation
open Bitcoin.Crypto.Seam (SigVersion ScriptExecutionData)

/-- SCR-176: STRICTENC is policy-only — the consensus view never sets it. -/
@[rule "SCR-176"]
theorem strictenc_policy_only (f : ScriptFlags) :
    (consensusFullFlags f).policy .strictEnc = false :=
  policy_absent_from_consensus f .strictEnc

/-- SCR-177: MINIMALDATA is policy-only — the consensus view never sets it. -/
@[rule "SCR-177"]
theorem minimaldata_policy_only (f : ScriptFlags) :
    (consensusFullFlags f).policy .minimalData = false :=
  policy_absent_from_consensus f .minimalData

/-- SCR-178: MINIMALIF is v0 policy, yet required for TAPSCRIPT spends. -/
@[rule "SCR-178"]
theorem minimalif_policy_and_tapscript (f : ScriptFlags) :
    (consensusFullFlags f).policy .minimalIfV0 = false ∧
      minimalIfRequired (consensusFullFlags f) SigVersion.tapscript = true :=
  ⟨policy_absent_from_consensus f .minimalIfV0,
    minimalif_consensus_in_tapscript (consensusFullFlags f)⟩

/-- SCR-179: NULLFAIL is policy-only — the consensus view never sets it. -/
@[rule "SCR-179"]
theorem nullfail_policy_only (f : ScriptFlags) :
    (consensusFullFlags f).policy .nullFail = false :=
  policy_absent_from_consensus f .nullFail

/-- SCR-180: CLEANSTACK is base/v0 policy, yet required for TAPSCRIPT. -/
@[rule "SCR-180"]
theorem cleanstack_policy_and_tapscript (f : ScriptFlags) :
    (consensusFullFlags f).policy .cleanStack = false ∧
      cleanStackRequired (consensusFullFlags f) SigVersion.tapscript = true :=
  ⟨policy_absent_from_consensus f .cleanStack,
    cleanstack_consensus_in_tapscript (consensusFullFlags f)⟩

/-! ## SCR-183 — the predicates are enforced by the real interpreter arms

The old row face stopped at the Boolean predicates.  These theorems state
the actual `stepBody` / `executeWitnessScript` behaviour.  No hypothesis
mentions `pol.minimalIf` or `pol.cleanstack`, so the enforcement is
independent of both v0 policy bits. -/

/-- SCR-183 (MINIMALIF arm): executed `OP_IF`/`OP_NOTIF` under TAPSCRIPT
rejects any non-minimal operand with `SCRIPT_ERR_TAPSCRIPT_MINIMALIF`,
whatever the consensus flags and policy word (interpreter.cpp:623-629;
BIP342 §8). -/
@[rule "SCR-183"]
theorem stepBody_if_notif_tapscript_nonminimal
    (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o) (hw : op.wire = 0x63 ∨ op.wire = 0x64)
    (hfe : st.vf.all id = true)
    (hsv : ctx.sv = SigVersion.tapscript)
    (hstack : 1 ≤ st.stack.length)
    (hbad : 1 < (topAt st.stack 1).size ∨
      ((topAt st.stack 1).size = 1 ∧
        (byteOr (topAt st.stack 1) 0).toNat ≠ 1)) :
    stepBody ctx op st = .error .tapscriptMinimalIf := by
  have hne : st.stack ≠ [] := by intro h; rw [h] at hstack; simp at hstack
  rcases hw with hw | hw <;>
  · rw [stepBody]
    simp [ha, hw, hfe, hsv, hne, hbad,
      Bitcoin.Interpreter.stepBody.dispatchOp, disabledWire]

/-- SCR-183 (CLEANSTACK arm, non-TAPSCRIPT): after a successful witness
script evaluation, any final stack other than exactly one element fails
with `SCRIPT_ERR_CLEANSTACK`; the `cleanStack` policy bit is not consulted
(interpreter.cpp:1876-1878 / Defs.lean:1197). -/
@[rule "SCR-183"]
theorem executeWitnessScript_cleanstack_nontapscript
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (sv : SigVersion) (st : Stack)
    (hsv : sv ≠ SigVersion.tapscript)
    (hcap : items.any (fun d => MAX_SCRIPT_ELEMENT_SIZE < d.size) = false)
    (hev : evalScriptBytes fuel flags pol exec items.reverse chk sv default = .ok st)
    (hlen : st.length ≠ 1) :
    executeWitnessScript fuel items vwSer exec flags pol chk sv = .fail .cleanstack := by
  rw [executeWitnessScript]
  simp [hsv, executeWitnessScript.runExec, hcap, hev, hlen]

/-- SCR-183 (CLEANSTACK arm, TAPSCRIPT): a tapscript with no OP_SUCCESSx
whose evaluation succeeds with a non-singleton stack fails with
`SCRIPT_ERR_CLEANSTACK`, independently of the `cleanStack` policy bit
(interpreter.cpp:1876-1878 / Defs.lean:1197). -/
@[rule "SCR-183"]
theorem executeWitnessScript_cleanstack_tapscript
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (st : Stack)
    (hcap : items.any (fun d => MAX_SCRIPT_ELEMENT_SIZE < d.size) = false)
    (hscan : opSuccessScan exec = false)
    (hstack : items.length ≤ MAX_STACK_SIZE)
    (hev : evalScriptBytes fuel flags pol exec items.reverse chk SigVersion.tapscript
      { (default : ScriptExecutionData) with
          validationWeightLeftInit := true,
          validationWeightLeft := vwSer + VALIDATION_WEIGHT_OFFSET } = .ok st)
    (hlen : st.length ≠ 1) :
    executeWitnessScript fuel items vwSer exec flags pol chk SigVersion.tapscript
      = .fail .cleanstack := by
  rw [executeWitnessScript]
  simp [hscan, Nat.not_lt.mpr hstack, executeWitnessScript.runExec, hcap, hev, hlen]

/-- SCR-183 (CLEANSTACK arm, every sigversion): the unconditional witness
cleanstack check — stated over the real `executeWitnessScript` with the
same `fuel`/`flags`/`pol`/`vwSer` parameters as the model. -/
@[rule "SCR-183"]
theorem executeWitnessScript_cleanstack
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (sv : SigVersion) (st : Stack)
    (hcap : items.any (fun d => MAX_SCRIPT_ELEMENT_SIZE < d.size) = false)
    (hscan : sv = SigVersion.tapscript → opSuccessScan exec = false)
    (hstack : sv = SigVersion.tapscript → items.length ≤ MAX_STACK_SIZE)
    (hev : evalScriptBytes fuel flags pol exec items.reverse chk sv
      (if sv = SigVersion.tapscript then
        { (default : ScriptExecutionData) with
            validationWeightLeftInit := true,
            validationWeightLeft := vwSer + VALIDATION_WEIGHT_OFFSET }
       else default) = .ok st)
    (hlen : st.length ≠ 1) :
    executeWitnessScript fuel items vwSer exec flags pol chk sv = .fail .cleanstack := by
  by_cases hsv : sv = SigVersion.tapscript
  · subst hsv
    have hev' := hev
    simp only [ite_true] at hev'
    rw [executeWitnessScript]
    simp [hscan rfl, Nat.not_lt.mpr (hstack rfl),
      executeWitnessScript.runExec, hcap, hev', hlen]
  · have hev' := hev
    simp only [ite_eq_right hsv] at hev'
    rw [executeWitnessScript]
    simp [hsv, executeWitnessScript.runExec, hcap, hev', hlen]

/-- SCR-183: `minimalIfRequired … .tapscript` is true for every flag record
and is consumed by the real TAPSCRIPT IF/NOTIF arm. -/
@[rule "SCR-183"]
theorem minimalIfRequired_tapscript_consumed
    (f : FullFlags) (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o) (hw : op.wire = 0x63 ∨ op.wire = 0x64)
    (hfe : st.vf.all id = true)
    (hsv : ctx.sv = SigVersion.tapscript)
    (hstack : 1 ≤ st.stack.length)
    (hbad : 1 < (topAt st.stack 1).size ∨
      ((topAt st.stack 1).size = 1 ∧
        (byteOr (topAt st.stack 1) 0).toNat ≠ 1)) :
    minimalIfRequired f SigVersion.tapscript = true ∧
      stepBody ctx op st = .error .tapscriptMinimalIf :=
  ⟨minimalif_consensus_in_tapscript f,
   stepBody_if_notif_tapscript_nonminimal ctx op st o ha hw hfe hsv hstack hbad⟩

/-- SCR-183: `cleanStackRequired … .tapscript` is true for every flag record
and is consumed by the real `executeWitnessScript` cleanstack arm. -/
@[rule "SCR-183"]
theorem cleanStackRequired_tapscript_consumed
    (f : FullFlags) (fuel : Nat) (items : List ByteArray) (vwSer : Int)
    (exec : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (st : Stack)
    (hcap : items.any (fun d => MAX_SCRIPT_ELEMENT_SIZE < d.size) = false)
    (hscan : opSuccessScan exec = false)
    (hstack : items.length ≤ MAX_STACK_SIZE)
    (hev : evalScriptBytes fuel flags pol exec items.reverse chk SigVersion.tapscript
      { (default : ScriptExecutionData) with
          validationWeightLeftInit := true,
          validationWeightLeft := vwSer + VALIDATION_WEIGHT_OFFSET } = .ok st)
    (hlen : st.length ≠ 1) :
    cleanStackRequired f SigVersion.tapscript = true ∧
      executeWitnessScript fuel items vwSer exec flags pol chk SigVersion.tapscript
        = .fail .cleanstack :=
  ⟨cleanstack_consensus_in_tapscript f,
   executeWitnessScript_cleanstack_tapscript fuel items vwSer exec flags pol chk
     st hcap hscan hstack hev hlen⟩

end BitcoinProofs.AF.PDW63b

/-- info: 'BitcoinProofs.AF.PDW63b.strictenc_policy_only' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63b.strictenc_policy_only

/-- info: 'BitcoinProofs.AF.PDW63b.minimaldata_policy_only' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63b.minimaldata_policy_only

/-- info: 'BitcoinProofs.AF.PDW63b.minimalif_policy_and_tapscript' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63b.minimalif_policy_and_tapscript

/-- info: 'BitcoinProofs.AF.PDW63b.nullfail_policy_only' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63b.nullfail_policy_only

/-- info: 'BitcoinProofs.AF.PDW63b.cleanstack_policy_and_tapscript' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63b.cleanstack_policy_and_tapscript

/-- info: 'BitcoinProofs.AF.PDW63b.stepBody_if_notif_tapscript_nonminimal' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63b.stepBody_if_notif_tapscript_nonminimal

/-- info: 'BitcoinProofs.AF.PDW63b.executeWitnessScript_cleanstack_nontapscript' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63b.executeWitnessScript_cleanstack_nontapscript

/-- info: 'BitcoinProofs.AF.PDW63b.executeWitnessScript_cleanstack_tapscript' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63b.executeWitnessScript_cleanstack_tapscript

/-- info: 'BitcoinProofs.AF.PDW63b.executeWitnessScript_cleanstack' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63b.executeWitnessScript_cleanstack

/-- info: 'BitcoinProofs.AF.PDW63b.minimalIfRequired_tapscript_consumed' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63b.minimalIfRequired_tapscript_consumed

/-- info: 'BitcoinProofs.AF.PDW63b.cleanStackRequired_tapscript_consumed' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW63b.cleanStackRequired_tapscript_consumed
