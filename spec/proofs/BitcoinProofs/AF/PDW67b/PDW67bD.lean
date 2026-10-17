import Bitcoin.Interpreter.Defs

/-! PDW67b — SCR-073: FROMALTSTACK on an empty altstack is invalid. -/

namespace BitcoinProofs.AF.PDW67b
open Bitcoin.Interpreter

@[rule "SCR-073"]
theorem stepBody_fromAltstack_empty {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x6c)
    (hsv : ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) (hfe : st.vf.all id = true)
    (h : st.alt = []) : stepBody ctx op st = .error .invalidAltstackOperation := by
  rw [stepBody]
  simp [ha, hw, hsv, hfe, disabledWire, Bitcoin.Interpreter.stepBody.dispatchOp, h]

/-! ## SCR-073: move semantics and the base/v0 cases

The audited theorem was tapscript-only. The altstack is a pure machine
stack in `EvalScript` (interpreter.cpp:687-703); the move semantics and
the empty-altstack error do not depend on the sigversion. `hoc` is the
ordinary op-budget side condition the opcode-count gate can otherwise
preempt (interpreter.cpp:459-463). -/

/-- SCR-073 helper: with one opcode of budget to spare, the op-budget gate
does not preempt the altstack transition.  This is stated in the shape the
gate takes after the wire-byte comparison `0x60 < w` has been decided. -/
private theorem gate_no_preempt (ctx : Ctx) (st : State)
    (hoc : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT) :
    ¬ ((ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
          ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0) ∧
        MAX_OPS_PER_SCRIPT <
          (if (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
                 ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0)
           then st.opCount + 1 else st.opCount)) := by
  rintro ⟨hc, hlt⟩
  rw [if_pos hc] at hlt
  unfold MAX_OPS_PER_SCRIPT at *
  omega

/-- SCR-073: `OP_FROMALTSTACK` on an empty altstack is
INVALID_ALTSTACK_OPERATION at every sigversion (base, v0, tapscript). -/
@[rule "SCR-073"]
theorem stepBody_fromAltstack_empty_any {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x6c)
    (hfe : st.vf.all id = true)
    (hoc : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (h : st.alt = []) :
    stepBody ctx op st = .error .invalidAltstackOperation := by
  have hnot := gate_no_preempt ctx st hoc
  rw [stepBody]
  simp [ha, hw, hfe, hnot, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, h]

/-- SCR-073: `OP_FROMALTSTACK` with a nonempty altstack moves its top
item onto the main stack (stack = v :: old_stack, alt = rest). -/
@[rule "SCR-073"]
theorem stepBody_fromAltstack_move {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} {v : ByteArray} {rest : Stack}
    (ha : op.ast = .op o) (hw : op.wire = 0x6c)
    (hfe : st.vf.all id = true)
    (hoc : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hs : st.alt = v :: rest) :
    stepBody ctx op st = .ok { st with
      stack := v :: st.stack, alt := rest,
      opCount := if (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
          ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0)
        then st.opCount + 1 else st.opCount } := by
  have hnot := gate_no_preempt ctx st hoc
  rw [stepBody]
  simp [ha, hw, hfe, hnot, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hs]

/-- SCR-073: `OP_TOALTSTACK` moves the main stack's top item onto the
altstack (alt = v :: old_alt, stack = rest). -/
@[rule "SCR-073"]
theorem stepBody_toAltstack_move {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} {v : ByteArray} {rest : Stack}
    (ha : op.ast = .op o) (hw : op.wire = 0x6b)
    (hfe : st.vf.all id = true)
    (hoc : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hs : st.stack = v :: rest) :
    stepBody ctx op st = .ok { st with
      alt := v :: st.alt, stack := rest,
      opCount := if (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
          ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0)
        then st.opCount + 1 else st.opCount } := by
  have hnot := gate_no_preempt ctx st hoc
  rw [stepBody]
  simp [ha, hw, hfe, hnot, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hs, topAt]

/-- SCR-073: `OP_TOALTSTACK` on an empty main stack is a stack underflow. -/
@[rule "SCR-073"]
theorem stepBody_toAltstack_empty {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x6b)
    (hfe : st.vf.all id = true)
    (hoc : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hs : st.stack = []) :
    stepBody ctx op st = .error .stackUnderflow := by
  have hnot := gate_no_preempt ctx st hoc
  rw [stepBody]
  simp [ha, hw, hfe, hnot, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hs]


/-! ## Axiom pins -/

/-- info: 'BitcoinProofs.AF.PDW67b.stepBody_fromAltstack_empty' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW67b.stepBody_fromAltstack_empty

end BitcoinProofs.AF.PDW67b
