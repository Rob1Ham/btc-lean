import Bitcoin.Interpreter.Defs

/-! PDW67b — SCR-066: unexecuted OP_VER passes (no BAD_OPCODE off-branch). -/

namespace BitcoinProofs.AF.PDW67b
open Bitcoin.Interpreter

@[rule "SCR-066"]
theorem stepBody_opVer_unexecuted {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x62)
    (hsv : ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) (hfe : st.vf.all id = false) :
    stepBody ctx op st = .ok st := by
  rw [stepBody]
  simp [ha, hw, hsv, hfe, disabledWire]


/-! ## Axiom pins -/

/-- info: 'BitcoinProofs.AF.PDW67b.stepBody_opVer_unexecuted' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW67b.stepBody_opVer_unexecuted

end BitcoinProofs.AF.PDW67b
