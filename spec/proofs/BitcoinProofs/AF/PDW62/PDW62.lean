import Bitcoin.Interpreter.Defs

/-! # PDW62 — TOP-331..335 P2SH/push-only row faces (claim pending) -/

namespace BitcoinProofs.AF.PDW62

open Bitcoin.Interpreter
open Bitcoin.Data (WitnessStack)
open Bitcoin.Numeric (castToBool)
open Bitcoin.Script.Parser (pushBytesWire)

/-- SCR-006: a non-push-only scriptSig fails P2SH before any evaluation. -/
@[rule "SCR-006"]
theorem p2shInner_nonpush_fail (fuel : Nat) (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (ss : ByteArray) (stackCopy : Stack) (witness : WitnessStack)
    (chk : ScriptChecker) (ops : List WireOp)
    (hparse : parseWire ss = some ops) (hpush : isPushOnlyWire ops = false) :
    p2shInner fuel flags pol ss stackCopy witness chk = .fail .sigPushOnly := by
  unfold p2shInner
  rw [hparse]
  simp [hpush]

/-- SCR-005: with a push-only scriptSig, the subscript re-evaluated is the
top of the saved scriptSig stack (`stackCopy`) on the saved rest. -/
@[rule "SCR-005"]
theorem p2shInner_reeval_stackCopy (fuel : Nat) (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (ss : ByteArray) (p : ByteArray) (rest : Stack)
    (witness : WitnessStack) (chk : ScriptChecker) (ops : List WireOp)
    (hparse : parseWire ss = some ops) (hpush : isPushOnlyWire ops = true) :
    p2shInner fuel flags pol ss (p :: rest) witness chk =
      (match evalScriptBytes fuel flags pol p rest chk .base default with
       | .error e => .fail e
       | .ok stack =>
         if stack = [] ∨ !castToBool (stack[0]?.getD default) then .fail .evalFalse
         else
           if flags.witness then
             match isWitnessProgram p with
             | some (v, prog) =>
               if ss != pushBytesWire p then .fail .witnessMalleatedP2SH
               else verifyWitnessProgram fuel witness v prog flags pol chk true
             | none => .ok
           else .ok) := by
  unfold p2shInner
  rw [hparse]
  simp [hpush]
  rfl

/-- SCR-052: every opcode ≤ 0x60 (OP_16, including OP_RESERVED) passes
`IsPushOnly`; 0x61 (OP_NOP) does not. -/
@[rule "SCR-052"]
theorem isPushOnlyWire_boundary (o : WireOp) (h : o.wire ≤ 0x60) :
    isPushOnlyWire [o] = true := by
  unfold isPushOnlyWire
  simp [h]

@[rule "SCR-052"]
theorem isPushOnlyWire_reject (o : WireOp) (h : 0x60 < o.wire) :
    isPushOnlyWire [o] = false := by
  unfold isPushOnlyWire
  simp [Nat.not_le.mpr h]

/-- SCR-012: a witness-program redeemScript whose scriptSig is not exactly
its single push is malleated (`witnessMalleatedP2SH`). -/
@[rule "SCR-012"]
theorem p2shInner_witness_malleated (fuel : Nat) (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (ss : ByteArray) (p : ByteArray) (rest : Stack)
    (witness : WitnessStack) (chk : ScriptChecker) (ops : List WireOp)
    (v : Nat) (prog : ByteArray) (stack : Stack)
    (hparse : parseWire ss = some ops) (hpush : isPushOnlyWire ops = true)
    (hev : evalScriptBytes fuel flags pol p rest chk .base default = .ok stack)
    (hne : stack ≠ []) (htrue : castToBool (stack[0]?.getD default) = true)
    (hw : flags.witness = true) (hwp : isWitnessProgram p = some (v, prog))
    (hss : (ss != pushBytesWire p) = true) :
    p2shInner fuel flags pol ss (p :: rest) witness chk = .fail .witnessMalleatedP2SH := by
  unfold p2shInner
  rw [hparse]
  simp [hpush, hev, hne, htrue, hw, hwp, hss]

/-- SCR-011: a bare (native) witness program with non-empty scriptSig fails
`witnessMalleated` before witness-program evaluation. -/
@[rule "SCR-011"]
theorem verifyScriptFull_native_witness_malleated (fuel : Nat)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (witness : WitnessStack) (chk : ScriptChecker)
    (stack1 stack : Stack) (v : Nat) (prog : ByteArray)
    (hsig : pol.sigPushOnly = false)
    (hev1 : evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1)
    (hev2 : evalScriptBytes fuel flags pol spk stack1 chk .base default = .ok stack)
    (hne : stack ≠ []) (htrue : castToBool (stack[0]?.getD default) = true)
    (hw : flags.witness = true) (hwp : isWitnessProgram spk = some (v, prog))
    (hss : ss.size ≠ 0) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail .witnessMalleated := by
  unfold verifyScriptFull
  rw [hsig]
  simp [hev1, hev2, hne, htrue, hw, hwp, hss]

/-- SCR-017: any failure of the scriptSig EvalScript aborts the whole
verify with that error (no later stage can mask it). -/
@[rule "SCR-017"]
theorem verifyScriptFull_eval_fail (fuel : Nat)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (witness : WitnessStack) (chk : ScriptChecker)
    (e : ExecError) (hsig : pol.sigPushOnly = false)
    (hev : evalScriptBytes fuel flags pol ss [] chk .base default = .error e) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail e := by
  unfold verifyScriptFull
  rw [hsig]
  simp [hev]

/-- INV-065: with SIGPUSHONLY set, a non-push-only scriptSig is rejected
by the pre-check before any evaluation. -/
@[rule "INV-065"]
theorem verifyScriptFull_sigpushonly_fail (fuel : Nat)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (witness : WitnessStack) (chk : ScriptChecker)
    (ops : List WireOp) (hsig : pol.sigPushOnly = true)
    (hparse : parseWire ss = some ops) (hpush : isPushOnlyWire ops = false) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail .sigPushOnly := by
  unfold verifyScriptFull
  rw [hsig]
  simp [hparse, hpush]

/-- SCR-007: after the push-only gate the saved stack snapshot is
restored verbatim — empty is the Core assert branch, a cons evaluates the
redeem script on the saved tail. -/
@[rule "SCR-007"]
theorem p2shInner_stack_snapshot (fuel : Nat) (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (ss : ByteArray) (stackCopy : Stack)
    (witness : WitnessStack) (chk : ScriptChecker) (ops : List WireOp)
    (hparse : parseWire ss = some ops) (hpush : isPushOnlyWire ops = true) :
    p2shInner fuel flags pol ss stackCopy witness chk =
      (match stackCopy with
       | [] => .fail .unknownError
       | p :: rest =>
         match evalScriptBytes fuel flags pol p rest chk .base default with
         | .error e => .fail e
         | .ok stack =>
           if stack = [] ∨ !castToBool stack[0]! then .fail .evalFalse
           else
             if flags.witness then
               match isWitnessProgram p with
               | some (v, prog) =>
                 if ss != pushBytesWire p then .fail .witnessMalleatedP2SH
                 else verifyWitnessProgram fuel witness v prog flags pol chk true
               | none => .ok
             else .ok) := by
  unfold p2shInner
  rw [hparse]
  simp only [hpush, Bool.not_true]
  cases stackCopy <;> rfl

end BitcoinProofs.AF.PDW62
