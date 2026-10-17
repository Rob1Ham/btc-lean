import Bitcoin.Interpreter.Defs

/-! # PDW90 — verifyScriptFull row faces (SCR-001/004/008/013)

Route B: row-face theorems on the frozen `verifyScriptFull` entry.
Residuals are explicit: the SIGPUSHONLY pre-gate is off, and the
P2SH/witness-program branches are pinned by hypotheses or by the
empty-scriptPubKey shape. -/

namespace BitcoinProofs.AF.PDW90
open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Activation Bitcoin.Data Bitcoin.Crypto.Seam

/-- Empty-script evaluation is the identity on the stack (parse = `[]`,
empty condition stack, so the eval loop returns). -/
theorem evalScriptBytes_empty (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (st : Stack) (chk : ScriptChecker) (sv : SigVersion) (ed : ScriptExecutionData) :
    evalScriptBytes (fuel+1) flags pol ByteArray.empty st chk sv ed = .ok st := by
  simp [evalScriptBytes, parseWire, parseWireFrom, evalFrom, finalStack]

/-- **SCR-004**: a scriptSig leaving one truthy element validates against
an empty scriptPubKey (empty spk is neither P2SH nor a witness program). -/
@[rule "SCR-004"]
theorem verifyScriptFull_empty_spk {fuel : Nat} {flags : ScriptFlags}
    {pol : PolicyFlags} {ss : ByteArray} {witness : WitnessStack}
    {chk : ScriptChecker} {stack : Stack}
    (hsig : pol.sigPushOnly = false)
    (hss : evalScriptBytes (fuel+1) flags pol ss [] chk .base default = .ok stack)
    (hne : stack ≠ []) (htruth : castToBool stack[0]! = true)
    (hwit : flags.witness = false) (hclean : pol.cleanstack = false) :
    verifyScriptFull (fuel+1) flags pol ss ByteArray.empty witness chk = .ok := by
  have htruth' : castToBool (stack[0]?.getD default) = true := by simpa using htruth
  simp [verifyScriptFull, evalScriptBytes_empty, hsig, hss, hne, htruth', hwit, hclean,
    show isWitnessProgram ByteArray.empty = none by decide,
    show isPayToScriptHash ByteArray.empty = false by decide]

/-- **SCR-001**: sequential evaluation — scriptSig then scriptPubKey on the
same stack (no concatenation). Bare, non-P2SH, SIGPUSHONLY-off face. -/
@[rule "SCR-001"]
theorem verifyScriptFull_sequential {fuel : Nat} {flags : ScriptFlags}
    {pol : PolicyFlags} {ss spk : ByteArray} {witness : WitnessStack}
    {chk : ScriptChecker} {stack1 stack : Stack}
    (hsig : pol.sigPushOnly = false)
    (hss : evalScriptBytes (fuel+1) flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes (fuel+1) flags pol spk stack1 chk .base default = .ok stack)
    (hne : stack ≠ []) (htruth : castToBool stack[0]! = true)
    (hprog : isWitnessProgram spk = none) (hp2sh : isPayToScriptHash spk = false)
    (hwit : flags.witness = false) (hclean : pol.cleanstack = false) :
    verifyScriptFull (fuel+1) flags pol ss spk witness chk = .ok := by
  have htruth' : castToBool (stack[0]?.getD default) = true := by simpa using htruth
  simp [verifyScriptFull, hsig, hss, hspk, hne, htruth', hprog, hp2sh, hwit, hclean]

/-- **SCR-008**: under CLEANSTACK a final stack of other than exactly one
element fails (bare, non-P2SH face). -/
@[rule "SCR-008"]
theorem verifyScriptFull_cleanstack_fails {fuel : Nat} {flags : ScriptFlags}
    {pol : PolicyFlags} {ss spk : ByteArray} {witness : WitnessStack}
    {chk : ScriptChecker} {stack1 stack : Stack}
    (hsig : pol.sigPushOnly = false)
    (hss : evalScriptBytes (fuel+1) flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes (fuel+1) flags pol spk stack1 chk .base default = .ok stack)
    (hne : stack ≠ []) (htruth : castToBool stack[0]! = true)
    (hprog : isWitnessProgram spk = none) (hp2sh : isPayToScriptHash spk = false)
    (hwit : flags.witness = false)
    (hclean : pol.cleanstack = true) (hlen : stack.length ≠ 1) :
    verifyScriptFull (fuel+1) flags pol ss spk witness chk = .fail .cleanstack := by
  have htruth' : castToBool (stack[0]?.getD default) = true := by simpa using htruth
  simp [verifyScriptFull, hsig, hss, hspk, hne, htruth', hprog, hp2sh, hwit, hclean, hlen]

/-- **SCR-013**: a non-null witness with no witness program fails
(WITNESS_UNEXPECTED) after the bare eval succeeds (non-P2SH face). -/
@[rule "SCR-013"]
theorem verifyScriptFull_witness_unexpected {fuel : Nat} {flags : ScriptFlags}
    {pol : PolicyFlags} {ss spk : ByteArray} {witness : WitnessStack}
    {chk : ScriptChecker} {stack1 stack : Stack}
    (hsig : pol.sigPushOnly = false)
    (hss : evalScriptBytes (fuel+1) flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes (fuel+1) flags pol spk stack1 chk .base default = .ok stack)
    (hne : stack ≠ []) (htruth : castToBool stack[0]! = true)
    (hwit : flags.witness = true) (hwne : witness ≠ [])
    (hprog : isWitnessProgram spk = none) (hp2sh : isPayToScriptHash spk = false)
    (hclean : pol.cleanstack = false) :
    verifyScriptFull (fuel+1) flags pol ss spk witness chk = .fail .witnessUnexpected := by
  have htruth' : castToBool (stack[0]?.getD default) = true := by simpa using htruth
  simp [verifyScriptFull, hsig, hss, hspk, hne, htruth', hwit, hwne, hprog, hp2sh, hclean]

end BitcoinProofs.AF.PDW90

/-- info: 'BitcoinProofs.AF.PDW90.evalScriptBytes_empty' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW90.evalScriptBytes_empty
/-- info: 'BitcoinProofs.AF.PDW90.verifyScriptFull_empty_spk' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW90.verifyScriptFull_empty_spk
/-- info: 'BitcoinProofs.AF.PDW90.verifyScriptFull_sequential' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW90.verifyScriptFull_sequential
/-- info: 'BitcoinProofs.AF.PDW90.verifyScriptFull_cleanstack_fails' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW90.verifyScriptFull_cleanstack_fails
/-- info: 'BitcoinProofs.AF.PDW90.verifyScriptFull_witness_unexpected' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW90.verifyScriptFull_witness_unexpected
