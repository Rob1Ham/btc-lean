import Bitcoin.Capstone.Block

/-! PDW67b — route B row face (C2) -/

namespace BitcoinProofs.AF.PDW67b

open Bitcoin.Interpreter Bitcoin.Capstone.Block Bitcoin.Capstone.RealChecker Bitcoin.Activation Bitcoin.Data

/-! ## SCR-021 — every v0 witness stack item ≤ 520 bytes -/

@[rule "SCR-021"]
theorem executeWitnessScript_item_size {fuel : Nat} {items : List ByteArray}
    {vwSer : Int} {exec : ByteArray} {flags : Bitcoin.Activation.ScriptFlags} {pol : PolicyFlags}
    {chk : ScriptChecker} {sv : Bitcoin.Crypto.Seam.SigVersion} (hsv : sv ≠ Bitcoin.Crypto.Seam.SigVersion.tapscript)
    (h : items.any (fun d => MAX_SCRIPT_ELEMENT_SIZE < d.size) = true) :
    executeWitnessScript fuel items vwSer exec flags pol chk sv = .fail .pushSize := by
  rw [Bitcoin.Interpreter.executeWitnessScript.eq_1]
  simp [hsv, Bitcoin.Interpreter.executeWitnessScript.runExec, h]

/-- **SCR-021 (all sigversions, explicit OP_SUCCESSx carve-out)**: every
witness stack item ≤ 520 bytes, including under TAPSCRIPT — provided the
tapscript contains no OP_SUCCESSx (the BIP342 rule that overrides the
limits, `opSuccessScan exec = false`) and the initial stack respects the
1000-element cap (which is checked before per-item sizes). The released
pin excluded tapscript wholesale; this states the exact exception. -/
@[rule "SCR-021"]
theorem executeWitnessScript_item_size_all {fuel : Nat} {items : List ByteArray}
    {vwSer : Int} {exec : ByteArray} {flags : Bitcoin.Activation.ScriptFlags} {pol : PolicyFlags}
    {chk : ScriptChecker} {sv : Bitcoin.Crypto.Seam.SigVersion}
    (h : items.any (fun d => MAX_SCRIPT_ELEMENT_SIZE < d.size) = true)
    (hstack : items.length ≤ MAX_STACK_SIZE)
    (hscan : sv = Bitcoin.Crypto.Seam.SigVersion.tapscript → opSuccessScan exec = false) :
    executeWitnessScript fuel items vwSer exec flags pol chk sv = .fail .pushSize := by
  by_cases hsv : sv = Bitcoin.Crypto.Seam.SigVersion.tapscript
  · rw [Bitcoin.Interpreter.executeWitnessScript.eq_1]
    simp [hsv, Bitcoin.Interpreter.executeWitnessScript.runExec,
      hscan hsv, Nat.not_lt.mpr hstack, h]
  · exact executeWitnessScript_item_size hsv h



/-! ## Axiom pins (charter subset [propext, Classical.choice, Quot.sound]) -/

/-- info: 'BitcoinProofs.AF.PDW67b.executeWitnessScript_item_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW67b.executeWitnessScript_item_size

end BitcoinProofs.AF.PDW67b
