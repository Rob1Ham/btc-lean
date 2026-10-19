import BitcoinProofs.AF.PDW88.PDW88

/-! PDW88b — SCR-067: OP_NOTIF also charges one opcode.

The existing `stepBody_if_counts_opcode` fixes OP_IF.  This module adds
the OP_NOTIF (0x64) arms: the successful counting step in BASE and
WITNESS_V0 (with the minimal empty operand that passes v0 MINIMALIF), the
nonempty BASE operand case, the unexecuted skip, and the budget reject.
-/

namespace BitcoinProofs.AF.PDW88b
open Bitcoin.Interpreter Bitcoin.Numeric
open Bitcoin.Crypto.Seam (SigVersion)

theorem castToBool_empty : castToBool ByteArray.empty = false := by decide

/-- SCR-067: an executed OP_NOTIF with an empty operand spends one opcode
unit in both counting sigversions (BASE and WITNESS_V0); the empty
operand is, in particular, minimal for the v0 MINIMALIF gate.  The
condition pushed is `!(castToBool empty) = true`. -/
@[rule "SCR-067"]
theorem stepBody_notif_counts_opcode {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} (ha : op.ast = .op o) (hw : op.wire = 0x64)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = true)
    (hb : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hs : 0 < st.stack.length)
    (hempty : topAt st.stack 1 = ByteArray.empty) :
    stepBody ctx op st =
      .ok { st with opCount := st.opCount + 1, vf := (true :: st.vf), stack := st.stack.tail } := by
  have hb' : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  have hs' : ¬ (st.stack.length < 1) := by omega
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb', hs', disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp, hempty, castToBool_empty])

/-- SCR-067: the same OP_NOTIF counting step with a nonempty operand in
BASE, where no MINIMALIF restriction applies.  The pushed condition is
the negation of `CastToBool` of the operand. -/
@[rule "SCR-067"]
theorem stepBody_notif_counts_opcode_base_nonempty {ctx : Ctx} {op : WireOp}
    {st : State} {o : Fin 256} (ha : op.ast = .op o) (hw : op.wire = 0x64)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hb : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hs : 0 < st.stack.length) :
    stepBody ctx op st =
      .ok { st with opCount := st.opCount + 1, vf := (!(castToBool (topAt st.stack 1))) :: st.vf, stack := st.stack.tail } := by
  have hb' : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  have hs' : ¬ (st.stack.length < 1) := by omega
  rw [stepBody]
  simp [ha, hw, hsv, hfe, hb', hs', disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp]

/-- SCR-067 (unexecuted): OP_NOTIF outside an executing branch is skipped
but still charges one opcode unit in BASE/WITNESS_V0. -/
@[rule "SCR-067"]
theorem stepBody_notif_unexecuted_counts {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} (ha : op.ast = .op o) (hw : op.wire = 0x64)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0) (hfe : st.vf.all id = false)
    (hb : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT) :
    stepBody ctx op st =
      .ok { st with opCount := st.opCount + 1, vf := false :: st.vf } := by
  have hb' : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1) := by omega
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hfe, hb', disabledWire,
       Bitcoin.Interpreter.stepBody.dispatchOp])

/-- SCR-067 (budget reject): an OP_NOTIF that would exceed the 201-op
budget fails with OP_COUNT before dispatching, in both counting
sigversions. -/
@[rule "SCR-067"]
theorem stepBody_notif_opCount_reject {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} (ha : op.ast = .op o) (hw : op.wire = 0x64)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0)
    (hcnt : MAX_OPS_PER_SCRIPT < st.opCount + 1) :
    stepBody ctx op st = .error .opCount := by
  rcases hsv with hsv | hsv <;>
    (rw [stepBody]
     simp [ha, hw, hsv, hcnt])

end BitcoinProofs.AF.PDW88b
