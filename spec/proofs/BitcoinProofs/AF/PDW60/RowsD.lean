import Bitcoin.Interpreter.Defs

/-! # PDW60 RowsD — replacement rows SCR-170, SCR-127 (RC29).

Route B row faces on `Bitcoin.Interpreter.stepBody` / `dispatchOp`:
the legacy-disabled opcode gate fires before execution (SCR-170,
CVE-2010-5137) and an OP_CSV operand with the disable flag is a NOP
(SCR-127, interpreter.cpp:1795-1796). Zero core writes.
-/

namespace BitcoinProofs.AF.PDW60

open Bitcoin.Interpreter

/-- Every legacy-disabled wire byte is > 0x60 (so it increments the
op-count in BASE/WITNESS_V0). -/
theorem disabledWire_gt_60 (w : Nat) (h : disabledWire w = true) : 0x60 < w := by
  simp only [Bitcoin.Interpreter.disabledWire, decide_eq_true_eq,
    List.mem_cons, List.not_mem_nil, or_false] at h
  rcases h with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl <;> decide

/-- SCR-170: a disabled opcode fails with `disabledOpcode` before
execution and even in unexecuted branches (CVE-2010-5137). -/
@[rule "SCR-170"]
theorem stepBody_disabled (ctx : Ctx) (st : State) (op : WireOp) (b : Fin 256)
    (hast : op.ast = .op b) (hdis : disabledWire op.wire = true)
    (hoc : st.opCount < MAX_OPS_PER_SCRIPT) :
    stepBody ctx op st = .error .disabledOpcode := by
  have hw : 0x60 < op.wire := disabledWire_gt_60 op.wire hdis
  unfold stepBody
  simp only
  rw [if_neg (by simp [hast])]
  rw [if_neg (by
    by_cases hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0
    · simp [hw, hsv]; omega
    · simp [hw, hsv])]
  rw [if_pos hdis]

/-- SCR-170 (budget boundary): once the 201-op budget is already
exhausted, the OP_COUNT gate (interpreter.cpp:459-463) fires *before*
the disabled-opcode gate, so the result is `.opCount` rather than
`.disabledOpcode`. This is the exact exception the row must state. -/
@[rule "SCR-170"]
theorem stepBody_disabled_budget_exhausted (ctx : Ctx) (st : State)
    (op : WireOp) (b : Fin 256)
    (hast : op.ast = .op b) (hdis : disabledWire op.wire = true)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0)
    (hbudget : MAX_OPS_PER_SCRIPT < st.opCount + 1) :
    stepBody ctx op st = .error .opCount := by
  have hw : 0x60 < op.wire := disabledWire_gt_60 op.wire hdis
  unfold stepBody
  simp only
  rw [if_neg (by simp [hast])]
  rw [if_pos (by simp [hw, hsv, hbudget])]

/-- SCR-170 (exact dichotomy): a disabled wire opcode fails with
`.opCount` exactly when the BASE/WITNESS_V0 budget is already exhausted,
and with `.disabledOpcode` otherwise — before execution and regardless of
`fExec` (CVE-2010-5137). -/
@[rule "SCR-170"]
theorem stepBody_disabled_or_opCount (ctx : Ctx) (st : State)
    (op : WireOp) (b : Fin 256)
    (hast : op.ast = .op b) (hdis : disabledWire op.wire = true) :
    stepBody ctx op st =
      if (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
          MAX_OPS_PER_SCRIPT < st.opCount + 1
      then .error .opCount else .error .disabledOpcode := by
  have hw : 0x60 < op.wire := disabledWire_gt_60 op.wire hdis
  unfold stepBody
  simp only
  rw [if_neg (by simp [hast])]
  by_cases hc : (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < op.wire
  · by_cases hb : MAX_OPS_PER_SCRIPT < st.opCount + 1
    · simp [hc, hb, hdis]
    · simp [hc, hb, hdis]
  · have hnot : ¬ (ctx.sv = .base ∨ ctx.sv = .witnessV0) := by
      intro hsv; exact hc ⟨hsv, hw⟩
    simp [hnot, hdis]

/-- SCR-127: an OP_CSV operand whose bit 31 is set makes the opcode a
NOP-success (no tx-level sequence comparison runs). Stated in TAPSCRIPT
(no op-count increment) with the executor on. -/
@[rule "SCR-127"]
theorem csv_disable_flag_nop (ctx : Ctx) (st : State)
    (n : Bitcoin.Numeric.ScriptNum) (next : Nat)
    (hstack : 1 ≤ st.stack.length) (hne : st.stack ≠ [])
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 5 = .ok n)
    (hn : ¬ n < 0)
    (hbit : (n.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0)
    (hcsv : ctx.flags.csv = true) (hfExec : st.vf.all id = true)
    (hsv : ctx.sv = .tapscript) :
    stepBody ctx ⟨.op ⟨0xb2, by decide⟩, 0xb2, next⟩ st = .ok st := by
  have hb2 : disabledWire 0xb2 = false := by decide
  unfold stepBody stepBody.dispatchOp
  simp [hne, hdec, hn, hbit, hcsv, hfExec, hb2, hsv]

/-- SCR-127 (BASE/WITNESS_V0 arm): the same bit-31 NOP, but in the
signature versions that count the opcode, so the resulting state is the
input with `opCount` incremented (interpreter.cpp:459-463 then
interpreter.cpp:594-596). The budget must not already be exhausted. -/
@[rule "SCR-127"]
theorem csv_disable_flag_nop_base_v0 (ctx : Ctx) (st : State)
    (n : Bitcoin.Numeric.ScriptNum) (next : Nat)
    (hstack : 1 ≤ st.stack.length) (hne : st.stack ≠ [])
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 5 = .ok n)
    (hn : ¬ n < 0)
    (hbit : (n.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0)
    (hcsv : ctx.flags.csv = true) (hfExec : st.vf.all id = true)
    (hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0)
    (hbudget : ¬ MAX_OPS_PER_SCRIPT < st.opCount + 1) :
    stepBody ctx ⟨.op ⟨0xb2, by decide⟩, 0xb2, next⟩ st =
      .ok { st with opCount := st.opCount + 1 } := by
  have hb2 : disabledWire 0xb2 = false := by decide
  unfold stepBody stepBody.dispatchOp
  simp [hne, hdec, hn, hbit, hcsv, hfExec, hb2, hsv, hbudget]

/-- SCR-127 (unexecuted arm): an unexecuted OP_CSV never reads its
operand, so bit 31 is irrelevant; the step is a NOP that only applies
the signature-version op-count increment. -/
@[rule "SCR-127"]
theorem csv_disable_flag_unexecuted (ctx : Ctx) (st : State) (next : Nat)
    (hfExec : st.vf.all id = false)
    (hbudget : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1)) :
    stepBody ctx ⟨.op ⟨0xb2, by decide⟩, 0xb2, next⟩ st =
      .ok { st with opCount :=
        if (ctx.sv = .base ∨ ctx.sv = .witnessV0) then st.opCount + 1
        else st.opCount } := by
  have hb2 : disabledWire 0xb2 = false := by decide
  unfold stepBody
  by_cases hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0
  · have hb : ¬ MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
      intro hlt; exact hbudget ⟨hsv, hlt⟩
    simp [hsv, hb, hfExec, hb2]
  · simp [hsv, hfExec, hb2]

/-- SCR-127 (CSV-flag-off arm): with CSV not active the opcode is NOP3
before any operand read; no bit-31 hypothesis is needed
(interpreter.cpp:573-575). -/
@[rule "SCR-127"]
theorem csv_flag_off_nop3 (ctx : Ctx) (st : State) (next : Nat)
    (hcsv : ctx.flags.csv = false) (hfExec : st.vf.all id = true)
    (hbudget : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1)) :
    stepBody ctx ⟨.op ⟨0xb2, by decide⟩, 0xb2, next⟩ st =
      .ok { st with opCount :=
        if (ctx.sv = .base ∨ ctx.sv = .witnessV0) then st.opCount + 1
        else st.opCount } := by
  have hb2 : disabledWire 0xb2 = false := by decide
  unfold stepBody
  by_cases hsv : ctx.sv = .base ∨ ctx.sv = .witnessV0
  · have hb : ¬ MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
      intro hlt; exact hbudget ⟨hsv, hlt⟩
    simp [hsv, hb, hcsv, hfExec, hb2, stepBody.dispatchOp]
  · simp [hsv, hcsv, hfExec, hb2, stepBody.dispatchOp]


/-! ## Axiom pins (guard_msgs) -/

/-- info: 'BitcoinProofs.AF.PDW60.disabledWire_gt_60' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.disabledWire_gt_60
/-- info: 'BitcoinProofs.AF.PDW60.stepBody_disabled' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.stepBody_disabled
/-- info: 'BitcoinProofs.AF.PDW60.csv_disable_flag_nop' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.csv_disable_flag_nop
/-- info: 'BitcoinProofs.AF.PDW60.stepBody_disabled_budget_exhausted' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.stepBody_disabled_budget_exhausted
/-- info: 'BitcoinProofs.AF.PDW60.stepBody_disabled_or_opCount' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.stepBody_disabled_or_opCount
/-- info: 'BitcoinProofs.AF.PDW60.csv_disable_flag_nop_base_v0' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.csv_disable_flag_nop_base_v0
/-- info: 'BitcoinProofs.AF.PDW60.csv_disable_flag_unexecuted' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.csv_disable_flag_unexecuted
/-- info: 'BitcoinProofs.AF.PDW60.csv_flag_off_nop3' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.csv_flag_off_nop3

end BitcoinProofs.AF.PDW60
