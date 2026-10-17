import Bitcoin.Interpreter.Defs

/-! PDW67b — SCR-065: OP_VERIF/OP_VERNOTIF is BAD_OPCODE even unexecuted. -/

namespace BitcoinProofs.AF.PDW67b
open Bitcoin.Interpreter

@[rule "SCR-065"]
theorem stepBody_opVerif_badOpcode {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x65)
    (hsv : ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) (hfe : st.vf.all id = false) :
    stepBody ctx op st = .error .badOpcode := by
  rw [stepBody]
  simp [ha, hw, hsv, hfe, disabledWire, Bitcoin.Interpreter.stepBody.dispatchOp]


/-! ## Axiom pins -/

/-- info: 'BitcoinProofs.AF.PDW67b.stepBody_opVerif_badOpcode' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW67b.stepBody_opVerif_badOpcode

end BitcoinProofs.AF.PDW67b
