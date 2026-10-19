import Bitcoin.Interpreter.Defs

/-! PDW67b — SCR-066 executed half: OP_VER / OP_RESERVED / RESERVED1/2.

The existing `stepBody_opVer_unexecuted` covers the skipped branch.  This
module adds the executed face: `OP_VER` (0x62), `OP_RESERVED` (0x50), and
the two reserved opcodes 0x89/0x8a reach the dispatch default and return
BAD_OPCODE at every sigversion, independently of the condition stack.
-/

namespace BitcoinProofs.AF.PDW67b
open Bitcoin.Interpreter

/-- SCR-066: an executed reserved opcode (0x50, 0x62, 0x89, 0x8a) fails
with BAD_OPCODE.  The budget hypothesis is the ordinary non-preemption
condition: all four wires are above OP_16, so the 201-op gate is checked
first in BASE/WITNESS_V0. -/
@[rule "SCR-066"]
theorem stepBody_reserved_executed_badOpcode
    (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o)
    (hw : op.wire = 0x50 ∨ op.wire = 0x62 ∨ op.wire = 0x89 ∨ op.wire = 0x8a)
    (hbudget : ¬ ((ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
        ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0) ∧
      0x60 < op.wire ∧ MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hfe : st.vf.all id = true) :
    stepBody ctx op st = .error .badOpcode := by
  rcases hw with hw | hw | hw | hw
  · rw [stepBody]
    simp [ha, hw, hfe, disabledWire,
      Bitcoin.Interpreter.stepBody.dispatchOp]
  · have hb : ¬ ((ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
        ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0) ∧
        MAX_OPS_PER_SCRIPT <
          (if (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
              ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0)
           then st.opCount + 1 else st.opCount)) := by
      rintro ⟨hc, hlt⟩
      exact hbudget ⟨hc, by rw [hw]; decide, by rwa [ite_eq_left hc] at hlt⟩
    rw [stepBody]
    simp [ha, hw, hb, hfe, disabledWire,
      Bitcoin.Interpreter.stepBody.dispatchOp]
  · have hb : ¬ ((ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
        ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0) ∧
        MAX_OPS_PER_SCRIPT <
          (if (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
              ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0)
           then st.opCount + 1 else st.opCount)) := by
      rintro ⟨hc, hlt⟩
      exact hbudget ⟨hc, by rw [hw]; decide, by rwa [ite_eq_left hc] at hlt⟩
    rw [stepBody]
    simp [ha, hw, hb, hfe, disabledWire,
      Bitcoin.Interpreter.stepBody.dispatchOp]
  · have hb : ¬ ((ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
        ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0) ∧
        MAX_OPS_PER_SCRIPT <
          (if (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
              ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0)
           then st.opCount + 1 else st.opCount)) := by
      rintro ⟨hc, hlt⟩
      exact hbudget ⟨hc, by rw [hw]; decide, by rwa [ite_eq_left hc] at hlt⟩
    rw [stepBody]
    simp [ha, hw, hb, hfe, disabledWire,
      Bitcoin.Interpreter.stepBody.dispatchOp]

/-- SCR-066 (unexecuted reserved opcode): outside the `[OP_IF..OP_ENDIF]`
window a reserved opcode is skipped and burns the opcode budget like any
other non-push opcode. -/
@[rule "SCR-066"]
theorem stepBody_reserved_unexecuted_skip
    (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o)
    (hw : op.wire = 0x62 ∨ op.wire = 0x89 ∨ op.wire = 0x8a)
    (hbudget : ¬ ((ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
        ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0) ∧
      0x60 < op.wire ∧ MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hfe : st.vf.all id = false) :
    stepBody ctx op st = .ok
      { st with
        opCount := if (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
            ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0)
          then st.opCount + 1 else st.opCount } := by
  rcases hw with hw | hw | hw
  · have hb : ¬ ((ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
        ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0) ∧
        MAX_OPS_PER_SCRIPT <
          (if (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
              ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0)
           then st.opCount + 1 else st.opCount)) := by
      rintro ⟨hc, hlt⟩
      exact hbudget ⟨hc, by rw [hw]; decide, by rwa [ite_eq_left hc] at hlt⟩
    rw [stepBody]
    simp [ha, hw, hb, hfe, disabledWire]
  · have hb : ¬ ((ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
        ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0) ∧
        MAX_OPS_PER_SCRIPT <
          (if (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
              ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0)
           then st.opCount + 1 else st.opCount)) := by
      rintro ⟨hc, hlt⟩
      exact hbudget ⟨hc, by rw [hw]; decide, by rwa [ite_eq_left hc] at hlt⟩
    rw [stepBody]
    simp [ha, hw, hb, hfe, disabledWire]
  · have hb : ¬ ((ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
        ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0) ∧
        MAX_OPS_PER_SCRIPT <
          (if (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.base ∨
              ctx.sv = Bitcoin.Crypto.Seam.SigVersion.witnessV0)
           then st.opCount + 1 else st.opCount)) := by
      rintro ⟨hc, hlt⟩
      exact hbudget ⟨hc, by rw [hw]; decide, by rwa [ite_eq_left hc] at hlt⟩
    rw [stepBody]
    simp [ha, hw, hb, hfe, disabledWire]

end BitcoinProofs.AF.PDW67b
