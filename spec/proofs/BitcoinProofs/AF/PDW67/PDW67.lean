import Bitcoin.Script.Tapscript.LeafVersion
import Bitcoin.Serialization.Interface
import Bitcoin.DataLaws.Interface
import Bitcoin.Invariants.RC08

/-! # PDW67.lean

BIP342 tapscript dispatch + wire-canonicality status-debt band. Route B:
zero core writes, row-face theorems tagged here; core proof bank re-used.

* INV-061 OP_SUCCESSx scan overrides stack/size limits (BIP342 step 2).
* INV-062 CHECKMULTISIG fails immediately under TAPSCRIPT.
* SCR-148 control[0]&0xfe = 0xc0 ⇒ TAPSCRIPT execution.
* TXV-012 CompactSize rejects non-minimal encodings (and canonical roundtrip).
* SWT-067 BIP144 per-input witness framing (`serWitness`).
-/

namespace BitcoinProofs.AF.PDW67

open Bitcoin.Interpreter Bitcoin.Activation Bitcoin.Data Bitcoin.Numeric
open Bitcoin.Script.Tapscript

/-- INV-061: an OP_SUCCESSx scan makes tapscript execution succeed
regardless of the initial stack (BIP342 step 2, interpreter.cpp:1846-1862). -/
@[rule "INV-061"]
theorem success_total_row (fuel : Nat) (items : List ByteArray) (vwSer : Int)
    (exec : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (h : opSuccessScan exec = true) :
    executeWitnessScript fuel items vwSer exec flags
      { pol with discourageOpSuccess := false } chk Bitcoin.Crypto.Seam.SigVersion.tapscript
      = VerifyOutcome.ok :=
  Bitcoin.Script.Tapscript.executeWitnessScript_success_total
    fuel items vwSer exec flags pol chk h

/-- INV-062: under tapscript CHECKMULTISIG fails immediately (no
success-opcode escape; interpreter.cpp:1115-1118). -/
@[rule "INV-062"]
theorem checkMultiSig_tapscript_fails_row (ctx : Ctx) (w : Nat) (st : State)
    (hsv : ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) :
    stepBody.checkMultiSig ctx w st = .error ExecError.tapscriptCheckMultiSig :=
  Bitcoin.Script.Tapscript.checkMultiSig_tapscript_fails ctx w st hsv

/-- SCR-148: leaf version 0xc0 dispatches into `executeWitnessScript` at
`Bitcoin.Crypto.Seam.SigVersion.tapscript`, with the full-witness serialized size as budget. -/
@[rule "SCR-148"]
theorem verifyTaprootLeafDispatch_c0_row (fuel : Nat) (items : WitnessStack)
    (script : ByteArray) (witness : WitnessStack) (flags : ScriptFlags)
    (pol : PolicyFlags) (chk : ScriptChecker) :
    verifyTaprootLeafDispatch fuel items (ctl 0xc0) script witness flags pol chk
      = executeWitnessScript fuel items (witnessSerSize witness) script
          flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript :=
  verifyTaprootLeafDispatch_tapscript fuel items (ctl 0xc0) script witness
    flags pol chk isTapscriptLeaf_c0

/-- TXV-012: a 0xfd-prefixed CompactSize whose value is < 0xfd is
non-minimal and rejected (serialize.h:333-361 @ cce32b168). -/
@[rule "TXV-012"]
theorem decCS_nonMinimal_fd_row (b0 b1 : UInt8) (rest : Bitcoin.Serialization.Bytes)
    (h : b0.toNat + 256 * b1.toNat < 0xfd) :
    Bitcoin.Serialization.decCS (0xfd :: b0 :: b1 :: rest)
      = .error .compactSizeNonMinimal :=
  Bitcoin.Serialization.decCS_nonMin_0xfd b0 b1 rest h

/-- TXV-012: canonical encodings decode back exactly (the minimal-length
accept side). -/
@[rule "TXV-012"]
theorem decCS_canonical_roundtrip_row (n : Nat) (h : n ≤ Bitcoin.Serialization.MAX_SIZE)
    (rest : Bitcoin.Serialization.Bytes) :
    Bitcoin.Serialization.decCS (Bitcoin.Serialization.encCSL n ++ rest)
      = .ok (n, rest) :=
  Bitcoin.Serialization.decCS_encCSL n h rest

/-- SWT-067: the witness serialization is exactly the per-input BIP144
fold over the vin index range (one stack per input). -/
@[rule "SWT-067"]
theorem serWitness_framing_row (tx : Tx) :
    Bitcoin.DataLaws.serWitness tx
      = (List.range tx.vin.length).foldl
          (fun acc i => acc ++ Bitcoin.DataLaws.serWitnessStack (tx.witness.getD i []))
          ByteArray.empty := rfl

/-- SWT-067: a single-input tx contributes exactly its one BIP144 stack. -/
@[rule "SWT-067"]
theorem serWitness_single_row (tx : Tx) (i : TxIn) (h : tx.vin = [i]) :
    Bitcoin.DataLaws.serWitness tx
      = Bitcoin.DataLaws.serWitnessStack (tx.witness.getD 0 []) := by
  simp [Bitcoin.DataLaws.serWitness, h]

/-- SWT-067: no inputs ⇒ empty witness serialization. -/
@[rule "SWT-067"]
theorem serWitness_empty_row (tx : Tx) (h : tx.vin = []) :
    Bitcoin.DataLaws.serWitness tx = ByteArray.empty := by
  simp [Bitcoin.DataLaws.serWitness, h]

/-- INV-064: script evaluation is SEQUENTIAL — scriptSig runs on the empty
stack, then scriptPubKey runs on the resulting stack (no concatenation).
This face takes the non-P2SH, non-witness, no-cleanstack lane. -/
@[rule "INV-064"]
theorem verifyScriptFull_sequential_row (fuel : Nat) (flags : ScriptFlags)
    (pol : PolicyFlags) (ss spk : ByteArray) (witness : WitnessStack)
    (chk : ScriptChecker) (stack1 stack : Stack)
    (hpush : pol.sigPushOnly = false)
    (hss : evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes fuel flags pol spk stack1 chk .base default = .ok stack)
    (hne : stack ≠ []) (htop : castToBool (stack[0]?.getD default) = true)
    (hp2sh : flags.p2sh = false) (hwit : flags.witness = false)
    (hclean : pol.cleanstack = false) :
    verifyScriptFull fuel flags pol ss spk witness chk = .ok := by
  unfold verifyScriptFull
  simp [hpush, hss, hspk, hne, htop, hp2sh, hwit, hclean]

/-- INV-086: the signet solution check is enforced exactly when the
signet gate is on (BIP325; validation.cpp:3939). -/
@[rule "INV-086"]
theorem signetBlockOk_gate_row (solutionOk : Bool) :
    (Bitcoin.Invariants.RC08.signetBlockOk true true solutionOk = true)
      ↔ solutionOk = true :=
  Bitcoin.Invariants.RC08.signetBlockOk_gate solutionOk

/-- INV-042: an element larger than MAX_SCRIPT_ELEMENT_SIZE is rejected at
the step guard, executed or not (interpreter.cpp:459-463). -/
@[rule "INV-042"]
theorem pushSize_row (ctx : Ctx) (op : WireOp) (d : ByteArray) (st : State)
    (hast : op.ast = .pushBytes d) (h : MAX_SCRIPT_ELEMENT_SIZE < d.size) :
    stepBody ctx op st = .error .pushSize := by
  unfold stepBody
  simp [hast, h]

/-- INV-048: the final success criterion — an empty result stack fails with
`evalFalse` (script.cpp EvalScript truthiness). -/
@[rule "INV-048"]
theorem verifyScriptFull_evalFalse_row (fuel : Nat) (flags : ScriptFlags)
    (pol : PolicyFlags) (ss spk : ByteArray) (witness : WitnessStack)
    (chk : ScriptChecker) (stack1 : Stack) (stack : Stack)
    (hpush : pol.sigPushOnly = false)
    (hss : evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes fuel flags pol spk stack1 chk .base default = .ok stack)
    (hempty : stack = []) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail .evalFalse := by
  unfold verifyScriptFull
  simp [hpush, hss, hspk, hempty]

/-! ### INV-048 — the truthiness half of the epilogue

`VerifyScript` accepts only after
`if (stack.empty() || !CastToBool(stack.back())) return set_error(evalFalse)`
(interpreter.cpp:2032, `CastToBool` :46-59). The model's stack is
head = top, so `stack[0]!` is Core's `stack.back()`. The two theorems
below state the criterion in both directions: success is possible only
when the post-scriptPubKey stack is nonempty with a truthy top, and in
the base (non-P2SH, non-witness, no-cleanstack) lane that condition is
also sufficient. -/

private theorem stack_get!_eq_getD (stack : Stack) (hne : stack ≠ []) :
    stack[0]! = (stack[0]?.getD default) := by
  cases stack with
  | nil => exact absurd rfl hne
  | cons a t => rfl

/-- INV-048 (empty-stack reject, arbitrary flag lane). -/
@[rule "INV-048"]
theorem verifyScriptFull_fail_nil_row (fuel : Nat) (flags : ScriptFlags)
    (pol : PolicyFlags) (ss spk : ByteArray) (witness : WitnessStack)
    (chk : ScriptChecker) (stack1 : Stack) (stack : Stack)
    (hpush : pol.sigPushOnly = false)
    (hss : evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes fuel flags pol spk stack1 chk .base default = .ok stack)
    (hempty : stack = []) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail .evalFalse :=
  verifyScriptFull_evalFalse_row fuel flags pol ss spk witness chk stack1 stack
    hpush hss hspk hempty

/-- INV-048 (false-top reject, arbitrary flag lane): a nonempty stack whose
top casts to `false` is rejected with `evalFalse` before any P2SH/witness
lane is entered. -/
@[rule "INV-048"]
theorem verifyScriptFull_fail_false_top_row (fuel : Nat) (flags : ScriptFlags)
    (pol : PolicyFlags) (ss spk : ByteArray) (witness : WitnessStack)
    (chk : ScriptChecker) (stack1 : Stack) (stack : Stack)
    (hpush : pol.sigPushOnly = false)
    (hss : evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes fuel flags pol spk stack1 chk .base default = .ok stack)
    (hne : stack ≠ [])
    (hfalse : castToBool (stack[0]?.getD default) = false) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail .evalFalse := by
  have hget := stack_get!_eq_getD stack hne
  unfold verifyScriptFull
  simp [hpush, hss, hspk, hget, hfalse]

/-- INV-048 (necessary direction, no flag restrictions): a successful
`verifyScriptFull` entails that the post-scriptPubKey stack is nonempty and
that its top element — the last item pushed — casts to `true`. -/
@[rule "INV-048"]
theorem verifyScriptFull_ok_truthy_row (fuel : Nat) (flags : ScriptFlags)
    (pol : PolicyFlags) (ss spk : ByteArray) (witness : WitnessStack)
    (chk : ScriptChecker) (stack1 : Stack) (stack : Stack)
    (hpush : pol.sigPushOnly = false)
    (hss : evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes fuel flags pol spk stack1 chk .base default = .ok stack)
    (h : verifyScriptFull fuel flags pol ss spk witness chk = .ok) :
    stack ≠ [] ∧ castToBool (stack[0]?.getD default) = true := by
  constructor
  · intro hempty
    have hfail := verifyScriptFull_fail_nil_row fuel flags pol ss spk witness chk
      stack1 stack hpush hss hspk hempty
    rw [hfail] at h
    cases h
  · cases stack with
    | nil =>
      have hfail := verifyScriptFull_fail_nil_row fuel flags pol ss spk witness chk
        stack1 [] hpush hss hspk rfl
      rw [hfail] at h
      cases h
    | cons a t =>
      change castToBool a = true
      cases hb : castToBool a with
      | true => rfl
      | false =>
        have hfail := verifyScriptFull_fail_false_top_row fuel flags pol ss spk
          witness chk stack1 (a :: t) hpush hss hspk (by simp) hb
        rw [hfail] at h
        cases h

/-- INV-048 (success criterion, base lane): in the non-P2SH,
non-witness, no-cleanstack lane, `verifyScriptFull` succeeds **iff** the
post-scriptPubKey stack is nonempty and its top element is truthy. -/
@[rule "INV-048"]
theorem verifyScriptFull_ok_iff_truthy_base_row (fuel : Nat) (flags : ScriptFlags)
    (pol : PolicyFlags) (ss spk : ByteArray) (witness : WitnessStack)
    (chk : ScriptChecker) (stack1 : Stack) (stack : Stack)
    (hpush : pol.sigPushOnly = false)
    (hss : evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes fuel flags pol spk stack1 chk .base default = .ok stack)
    (hp2sh : flags.p2sh = false) (hwit : flags.witness = false)
    (hclean : pol.cleanstack = false) :
    verifyScriptFull fuel flags pol ss spk witness chk = .ok ↔
      stack ≠ [] ∧ castToBool (stack[0]?.getD default) = true :=
  ⟨verifyScriptFull_ok_truthy_row fuel flags pol ss spk witness chk stack1 stack
     hpush hss hspk,
   fun ⟨hne, htop⟩ =>
     verifyScriptFull_sequential_row fuel flags pol ss spk witness chk stack1 stack
       hpush hss hspk hne htop hp2sh hwit hclean⟩

end BitcoinProofs.AF.PDW67

/-- info: 'BitcoinProofs.AF.PDW67.success_total_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.success_total_row

/-- info: 'BitcoinProofs.AF.PDW67.checkMultiSig_tapscript_fails_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.checkMultiSig_tapscript_fails_row

/-- info: 'BitcoinProofs.AF.PDW67.verifyTaprootLeafDispatch_c0_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.verifyTaprootLeafDispatch_c0_row

/-- info: 'BitcoinProofs.AF.PDW67.decCS_nonMinimal_fd_row' depends on axioms: [propext] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.decCS_nonMinimal_fd_row

/-- info: 'BitcoinProofs.AF.PDW67.decCS_canonical_roundtrip_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.decCS_canonical_roundtrip_row

/-- info: 'BitcoinProofs.AF.PDW67.serWitness_framing_row' depends on axioms: [propext] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.serWitness_framing_row

/-- info: 'BitcoinProofs.AF.PDW67.serWitness_single_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.serWitness_single_row

/-- info: 'BitcoinProofs.AF.PDW67.serWitness_empty_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.serWitness_empty_row

/-- info: 'BitcoinProofs.AF.PDW67.verifyScriptFull_sequential_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.verifyScriptFull_sequential_row

/-- info: 'BitcoinProofs.AF.PDW67.signetBlockOk_gate_row' depends on axioms: [propext] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.signetBlockOk_gate_row

/-- info: 'BitcoinProofs.AF.PDW67.pushSize_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.pushSize_row

/-- info: 'BitcoinProofs.AF.PDW67.verifyScriptFull_evalFalse_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.verifyScriptFull_evalFalse_row

/-- info: 'BitcoinProofs.AF.PDW67.verifyScriptFull_fail_nil_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.verifyScriptFull_fail_nil_row

/-- info: 'BitcoinProofs.AF.PDW67.verifyScriptFull_fail_false_top_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.verifyScriptFull_fail_false_top_row

/-- info: 'BitcoinProofs.AF.PDW67.verifyScriptFull_ok_truthy_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.verifyScriptFull_ok_truthy_row

/-- info: 'BitcoinProofs.AF.PDW67.verifyScriptFull_ok_iff_truthy_base_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW67.verifyScriptFull_ok_iff_truthy_base_row
