import BitcoinProofs.AF.PDW79.PDW79

/-! PDW79b — SCR-074: the depth pre-check over the whole 2DROP..TUCK band.

`PDW79.stepBody_depth_check` covered only OP_2DROP (0x6d).  The stack
ops below all perform their `stack.size()` check before popping; this
module records the INVALID_STACK_OPERATION face for each opcode in the
0x6d..0x7d band (OP_DEPTH has no stack requirement and is omitted).
-/

namespace BitcoinProofs.AF.PDW79b
open Bitcoin.Interpreter Bitcoin.Numeric

/-- Shared proof shape for a concrete stack-arity gate. -/
theorem stepBody_depth_check_wire {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} (ha : op.ast = .op o) (hw : op.wire = 0x6d)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 2) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

@[rule "SCR-074"]
theorem stepBody_2drop_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x6d)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 2) :
    stepBody ctx op st = .error .stackUnderflow :=
  stepBody_depth_check_wire ha hw hsv hfe hb hs

@[rule "SCR-074"]
theorem stepBody_2dup_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x6e)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 2) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

@[rule "SCR-074"]
theorem stepBody_3dup_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x6f)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 3) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

@[rule "SCR-074"]
theorem stepBody_2over_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x70)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 4) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

@[rule "SCR-074"]
theorem stepBody_2rot_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x71)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 6) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

@[rule "SCR-074"]
theorem stepBody_2swap_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x72)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 4) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

@[rule "SCR-074"]
theorem stepBody_ifdup_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x73)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 1) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

@[rule "SCR-074"]
theorem stepBody_drop_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x75)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 1) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

@[rule "SCR-074"]
theorem stepBody_dup_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x76)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 1) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

@[rule "SCR-074"]
theorem stepBody_nip_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x77)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 2) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

@[rule "SCR-074"]
theorem stepBody_over_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x78)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 2) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

@[rule "SCR-074"]
theorem stepBody_pick_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x79)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 2) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

@[rule "SCR-074"]
theorem stepBody_roll_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x7a)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 2) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

@[rule "SCR-074"]
theorem stepBody_rot_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x7b)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 3) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

@[rule "SCR-074"]
theorem stepBody_swap_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x7c)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 2) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

@[rule "SCR-074"]
theorem stepBody_tuck_depth {ctx : Ctx} {op : WireOp} {st : State} {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x7d)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hs : st.stack.length < 2) :
    stepBody ctx op st = .error .stackUnderflow := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

end BitcoinProofs.AF.PDW79b
