import Bitcoin.Interpreter.Defs

/-! # PDW85b — TOP swaps: SCR-060/096/097 row faces -/

namespace BitcoinProofs.AF.PDW85b
open Bitcoin.Interpreter Bitcoin.Numeric

/-- SCR-060: an unexecuted IF/NOTIF adds a `false` to the condition
stack and pops nothing (interpreter.cpp:660-664). -/
@[rule "SCR-060"]
theorem stepBody_unexecuted_if_stack {ctx : Ctx} {op : WireOp} {st st' : State}
    {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x63 ∨ op.wire = 0x64)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = false)
    (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (h : stepBody ctx op st = .ok st') :
    st'.stack = st.stack ∧ st'.alt = st.alt := by
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  rcases hw with hw | hw <;>
    (rw [stepBody] at h
     simp [ha, hw, hsv, hfe, hb, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp] at h
     cases h
     exact ⟨rfl, rfl⟩)

/-- SCR-096: an executed OP_CODESEPARATOR sets `codeSep` to the current
opcode's end offset (interpreter.cpp:1067). -/
@[rule "SCR-096"]
theorem stepBody_codeseparator {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0xab) (hsv : ctx.sv = .base)
    (hfe : st.vf.all id = true) (hconst : ctx.pol.constScriptCode = false)
    (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT) :
    stepBody ctx op st = .ok { st with
      opCount := st.opCount + 1, codeSep := op.next } := by
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hconst, hb, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp]

/-- SCR-097: an unexecuted OP_CODESEPARATOR does not move `codeSep`
(interpreter.cpp:1067 is inside the `fExec` gate). -/
@[rule "SCR-097"]
theorem stepBody_codeseparator_unexecuted {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0xab) (hsv : ctx.sv = .base)
    (hfe : st.vf.all id = false) (hconst : ctx.pol.constScriptCode = false)
    (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT) :
    stepBody ctx op st = .ok { st with opCount := st.opCount + 1 } := by
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hconst, hb, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp]

end BitcoinProofs.AF.PDW85b
