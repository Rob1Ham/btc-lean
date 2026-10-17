import Bitcoin.Interpreter.Defs

/-! # PDW65 probe — witness-admission residue -/

namespace BitcoinProofs.AF.PDW65

open Bitcoin.Interpreter Bitcoin.Data Bitcoin.Activation
open Bitcoin.Script.Parser Bitcoin.Numeric

/-- SWT-003: bare witness program + non-empty scriptSig ⇒ WITNESS_MALLEATED. -/
@[rule "SWT-003"]
theorem witnessMalleated_bare
    (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (witness : WitnessStack) (chk : ScriptChecker)
    (stack1 stack : Stack) (v : Nat) (prog : ByteArray)
    (hpush : pol.sigPushOnly = false)
    (hss : evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes fuel flags pol spk stack1 chk .base default = .ok stack)
    (hne : stack ≠ []) (htop : castToBool (stack[0]?.getD default) = true)
    (hwit : flags.witness = true)
    (hp : isWitnessProgram spk = some (v, prog))
    (hssne : ss.size ≠ 0) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail .witnessMalleated := by
  unfold verifyScriptFull
  simp [hpush, hss, hspk, hne, htop, hwit, hp, hssne]

/-- SWT-004: P2SH-wrapped witness program requires the exact redeem push. -/
@[rule "SWT-004"]
theorem p2shInner_witnessMalleatedP2SH
    (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (ss : ByteArray) (redeem : ByteArray) (rest st : Stack)
    (witness : WitnessStack) (chk : ScriptChecker)
    (ops : List WireOp) (v : Nat) (prog : ByteArray)
    (hparse : parseWire ss = some ops)
    (hpushonly : isPushOnlyWire ops = true)
    (heval : evalScriptBytes fuel flags pol redeem rest chk .base default = .ok st)
    (hne : st ≠ []) (htop : castToBool (st[0]?.getD default) = true)
    (hwit : flags.witness = true)
    (hp : isWitnessProgram redeem = some (v, prog))
    (hm : (ss != pushBytesWire redeem) = true) :
    p2shInner fuel flags pol ss (redeem :: rest) witness chk
      = .fail .witnessMalleatedP2SH := by
  unfold p2shInner
  simp [hparse, hpushonly, heval, hne, htop, hwit, hp, hm]

/-- SWT-015: unexpected witness data on a non-witness spend fails. -/
@[rule "SWT-015"]
theorem witnessUnexpected_nonWitness
    (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (witness : WitnessStack) (chk : ScriptChecker)
    (stack1 stack : Stack)
    (hpush : pol.sigPushOnly = false)
    (hss : evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes fuel flags pol spk stack1 chk .base default = .ok stack)
    (hne : stack ≠ []) (htop : castToBool (stack[0]?.getD default) = true)
    (hwit : flags.witness = true) (hp : isWitnessProgram spk = none)
    (hp2sh : flags.p2sh = false) (hcl : pol.cleanstack = false)
    (hwne : witness ≠ []) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail .witnessUnexpected := by
  unfold verifyScriptFull
  simp [hpush, hss, hspk, hne, htop, hwit, hp, hp2sh, hcl, hwne]

/-- SWT-012 / SCR-138 engine: a successful v0 witness execution ends in
exactly one truthy stack element (the implicit cleanstack + eval-true pair). -/
theorem executeWitnessScript_witnessV0_ok
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (hsmall : items.any (fun d => Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE < d.size) = false)
    (h : executeWitnessScript fuel items vwSer exec flags pol chk .witnessV0 = .ok) :
    ∃ st, evalScriptBytes fuel flags pol exec items.reverse chk .witnessV0 default = .ok st ∧
      st.length = 1 ∧ castToBool (st[0]!) = true := by
  have hsv : (Bitcoin.Crypto.Seam.SigVersion.witnessV0
      = Bitcoin.Crypto.Seam.SigVersion.tapscript) = False := by decide
  simp only [executeWitnessScript, executeWitnessScript.runExec, hsv, ite_false,
    hsmall, Bool.false_eq_true] at h
  cases hev : evalScriptBytes fuel flags pol exec items.reverse chk .witnessV0 default with
  | error e => simp [hev] at h
  | ok st =>
    rw [hev] at h
    have hlen : st.length = 1 := by
      by_cases hne : st.length = 1
      · exact hne
      · simp [hne] at h
    have htrue : castToBool (st[0]!) = true := by
      simpa [hlen] using h
    exact ⟨st, rfl, hlen, htrue⟩

/-- SWT-012: witness execution accepts only a single truthy final element. -/
@[rule "SWT-012"]
theorem executeWitnessScript_witnessV0_cleanstack
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (hsmall : items.any (fun d => Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE < d.size) = false)
    (h : executeWitnessScript fuel items vwSer exec flags pol chk .witnessV0 = .ok) :
    ∃ st, evalScriptBytes fuel flags pol exec items.reverse chk .witnessV0 default = .ok st ∧
      st.length = 1 ∧ castToBool (st[0]!) = true :=
  executeWitnessScript_witnessV0_ok fuel items vwSer exec flags pol chk hsmall h

/-- SCR-138: v0-20 witness dispatch accepts only one true stack element. -/
@[rule "SCR-138"]
theorem verifyWitnessProgram_v0_20_ok_cleanstack
    (fuel : Nat) (witness : WitnessStack) (program : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker) (isP2SH : Bool)
    (h20 : program.size = 20) (harity : witness.length = 2)
    (hsmall : witness.any (fun d => Bitcoin.Interpreter.MAX_SCRIPT_ELEMENT_SIZE < d.size) = false)
    (h : verifyWitnessProgram fuel witness 0 program flags pol chk isP2SH = .ok) :
    ∃ st, evalScriptBytes fuel flags pol
        (List.toByteArray [0x76, 0xa9, 0x14] ++ program ++ List.toByteArray [0x88, 0xac])
        witness.reverse chk .witnessV0 default = .ok st ∧ st.length = 1 ∧
      castToBool (st[0]!) = true := by
  have h32 : program.size ≠ 32 := by omega
  unfold verifyWitnessProgram at h
  simp only [h20, harity, ite_true] at h
  exact executeWitnessScript_witnessV0_ok fuel witness _ _ flags pol chk hsmall h

end BitcoinProofs.AF.PDW65
