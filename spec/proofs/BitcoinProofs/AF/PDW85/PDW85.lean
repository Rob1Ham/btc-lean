import Bitcoin.Interpreter.Defs

/-! # PDW85 — TOP-446..450, hard-tail stepBody band (route B) -/

namespace BitcoinProofs.AF.PDW85
open Bitcoin.Interpreter Bitcoin.Numeric

/-- SCR-076: OP_SIZE pushes the minimal CScriptNum encoding of the top
element's length (interpreter.cpp:787-793). -/
@[rule "SCR-076"]
theorem stepBody_size_minimal_scriptnum {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x82) (hsv : ctx.sv = .base)
    (hfe : st.vf.all id = true) (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hstack : 0 < st.stack.length) :
    stepBody ctx op st = .ok { st with
      opCount := st.opCount + 1,
      stack := encodeScriptNum ((topAt st.stack 1).size : ScriptNum) false :: st.stack } := by
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  have hs : ¬ (st.stack.length < 1) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp]

/-- SCR-089: OP_WITHIN is the half-open interval `min ≤ x < max`
(interpreter.cpp:1012-1026). -/
@[rule "SCR-089"]
theorem stepBody_within_interval {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} {x mn mx : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0xa5) (hsv : ctx.sv = .base)
    (hfe : st.vf.all id = true) (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hstack : 2 < st.stack.length)
    (hx : decodeNum ctx.pol (topAt st.stack 3) 4 = .ok x)
    (hmn : decodeNum ctx.pol (topAt st.stack 2) 4 = .ok mn)
    (hmx : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok mx) :
    stepBody ctx op st = .ok { st with
      opCount := st.opCount + 1,
      stack := pushBoolV (mn ≤ x ∧ x < mx) :: st.stack.drop 3 } := by
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  have hs : ¬ (st.stack.length < 3) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, hx, hmn, hmx]

/-- SCR-091: OP_EQUAL compares the two top elements as raw bytes
(interpreter.cpp:897-923). -/
@[rule "SCR-091"]
theorem stepBody_equal_raw_bytes {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x87) (hsv : ctx.sv = .base)
    (hfe : st.vf.all id = true) (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hstack : 1 < st.stack.length) :
    stepBody ctx op st = .ok { st with
      opCount := st.opCount + 1,
      stack := pushBoolV (topAt st.stack 2 == topAt st.stack 1) :: st.stack.drop 2 } := by
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  have hs : ¬ (st.stack.length < 2) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp]

/-- SCR-113: OP_CHECKSIG advances the 201-op budget by exactly one
(opCount threading at interpreter.cpp:1069-1092). -/
@[rule "SCR-113"]
theorem stepBody_checksig_budget {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} {fSuccess : Bool} {vw' : Option Int}
    (ha : op.ast = .op o) (hw : op.wire = 0xac) (hsv : ctx.sv = .base)
    (hfe : st.vf.all id = true) (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hstack : 1 < st.stack.length)
    (hd : evalChecksigDispatch ctx.flags ctx.pol ctx.chk ctx.ed ctx.sv st.codeSep
            ctx.bytes (topAt st.stack 2) (topAt st.stack 1) st.vwLeft
            = .ok (fSuccess, vw')) :
    stepBody ctx op st = .ok { st with
      opCount := st.opCount + 1, vwLeft := vw',
      stack := pushBoolV fSuccess :: st.stack.drop 2 } := by
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  have hs : ¬ (st.stack.length < 2) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, hs, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp]
  rw [hsv] at hd
  rw [hd]

/-- SCR-023: opCount is flow-insensitive — an IF in an unexecuted branch
still increments the 201-op counter (interpreter.cpp:460-464). -/
@[rule "SCR-023"]
theorem stepBody_unexecuted_if_counts {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256}
    (ha : op.ast = .op o) (hw : op.wire = 0x63) (hsv : ctx.sv = .base)
    (hfe : st.vf.all id = false) (hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT) :
    stepBody ctx op st = .ok { st with
      opCount := st.opCount + 1,
      vf := false :: st.vf } := by
  have hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp]

end BitcoinProofs.AF.PDW85
