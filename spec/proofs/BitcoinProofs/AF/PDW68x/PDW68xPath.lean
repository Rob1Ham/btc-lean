import BitcoinProofs.AF.PDW68x.PDW68x
import BitcoinProofs.AF.PDW93.PDW93b

/-! # PDW68xPath — INV-022 / INV-023 whole opcode paths

The `PDW68x` checker lemmas cover the transaction-side verdicts but do
not include the opcode arm.  This module states the complete CLTV/CSV
`stepBody` paths (decode, five-byte operand width, negative reject,
flag-off NOP, stack underflow, checker verdict), then extracts the
individual row faces.  Route B: no core definition is changed.
-/

namespace BitcoinProofs.AF.PDW68xPath

open Bitcoin.Interpreter Bitcoin.Numeric
open Bitcoin.Crypto.Seam (SigVersion)

/-- The opcode-budget increment performed by `stepBody` at its counting
sigversions.  This is definitionally the `opCount'` local in `stepBody`. -/
def stepOpCount (ctx : Ctx) (st : State) : Nat :=
  if ctx.sv = SigVersion.base ∨ ctx.sv = SigVersion.witnessV0 then
    st.opCount + 1
  else st.opCount

/-- The ordinary (non-preempting) budget side condition for a wire opcode
above `OP_16`.  This is the shape used by the existing PDW93/PDW79 row
faces. -/
def BudgetOk (ctx : Ctx) (st : State) : Prop :=
  ¬ ((ctx.sv = SigVersion.base ∨ ctx.sv = SigVersion.witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1)

/-- With one opcode of budget to spare the guard in `stepBody` does not
preempt the dispatch. -/
theorem budget_not_preempt {ctx : Ctx} {st : State} (h : BudgetOk ctx st) :
    ¬ ((ctx.sv = SigVersion.base ∨ ctx.sv = SigVersion.witnessV0) ∧
      MAX_OPS_PER_SCRIPT <
        (if ctx.sv = SigVersion.base ∨ ctx.sv = SigVersion.witnessV0 then
          st.opCount + 1 else st.opCount)) := by
  rintro ⟨hc, hlt⟩
  exact h ⟨hc, by rwa [ite_eq_left hc] at hlt⟩

/-- INV-022 (whole CLTV opcode path): on an executed ordinary step, the
CLTV transition is exactly the flag gate, stack-depth check, five-byte
numeric decode, negative check, and `CheckLockTime` verdict, with the
opcode-budget update applied on success. -/
@[rule "INV-022"]
theorem stepBody_cltv_path (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o) (hw : op.wire = 0xb1)
    (hb : BudgetOk ctx st) (hfe : st.vf.all id = true) :
    stepBody ctx op st =
      (if ctx.flags.cltv = false then
        .ok { st with opCount := stepOpCount ctx st }
      else if st.stack.length < 1 then .error .stackUnderflow
      else match decodeNum ctx.pol (topAt st.stack 1) 5 with
        | .error e => .error e
        | .ok n =>
          if n < 0 then .error .negativeLocktime
          else if !checkLockTimeDef ctx.chk.env n then .error .unsatisfiedLocktime
          else .ok { st with opCount := stepOpCount ctx st }) := by
  have hb' := budget_not_preempt hb
  rw [stepBody]
  simp [ha, hw, hb', hfe, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, stepOpCount]
  rfl

/-- INV-023 (whole CSV opcode path): on an executed ordinary step, the
CSV transition is exactly the flag gate, stack-depth check, five-byte
numeric decode, negative check, disable-bit NOP, and `CheckSequence`
verdict, with the opcode-budget update applied on success. -/
@[rule "INV-023"]
theorem stepBody_csv_path (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o) (hw : op.wire = 0xb2)
    (hb : BudgetOk ctx st) (hfe : st.vf.all id = true) :
    stepBody ctx op st =
      (if ctx.flags.csv = false then
        .ok { st with opCount := stepOpCount ctx st }
      else if st.stack.length < 1 then .error .stackUnderflow
      else match decodeNum ctx.pol (topAt st.stack 1) 5 with
        | .error e => .error e
        | .ok n =>
          if n < 0 then .error .negativeLocktime
          else if (n.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0 then
            .ok { st with opCount := stepOpCount ctx st }
          else if !checkSequenceDef ctx.chk.env n then .error .unsatisfiedLocktime
          else .ok { st with opCount := stepOpCount ctx st }) := by
  have hb' := budget_not_preempt hb
  rw [stepBody]
  simp [ha, hw, hb', hfe, disabledWire,
    Bitcoin.Interpreter.stepBody.dispatchOp, stepOpCount]
  rfl

/-! ## Extracted CLTV faces -/

/-- INV-022 (flag off): an executed CLTV with the BIP65 flag clear is a
NOP; only the opcode budget moves. -/
@[rule "INV-022"]
theorem stepBody_cltv_flag_off (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o) (hw : op.wire = 0xb1) (hb : BudgetOk ctx st)
    (hfe : st.vf.all id = true) (hcltv : ctx.flags.cltv = false) :
    stepBody ctx op st = .ok { st with opCount := stepOpCount ctx st } := by
  rw [stepBody_cltv_path ctx op st o ha hw hb hfe]
  simp [hcltv]

/-- INV-022 (stack underflow): an executed, flag-on CLTV with an empty
main stack fails with INVALID_STACK_OPERATION. -/
@[rule "INV-022"]
theorem stepBody_cltv_underflow (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o) (hw : op.wire = 0xb1) (hb : BudgetOk ctx st)
    (hfe : st.vf.all id = true) (hcltv : ctx.flags.cltv = true)
    (hs : st.stack.length < 1) :
    stepBody ctx op st = .error .stackUnderflow := by
  rw [stepBody_cltv_path ctx op st o ha hw hb hfe]
  simp [hcltv, hs]

/-- INV-022 (negative reject): after a successful five-byte decode, a
negative CLTV operand fails with NEGATIVE_LOCKTIME before the checker. -/
@[rule "INV-022"]
theorem stepBody_cltv_negative (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o) (hw : op.wire = 0xb1) (hb : BudgetOk ctx st)
    (hfe : st.vf.all id = true) (hcltv : ctx.flags.cltv = true)
    (hs : ¬ st.stack.length < 1) {n : ScriptNum}
    (hd : decodeNum ctx.pol (topAt st.stack 1) 5 = .ok n) (hn : n < 0) :
    stepBody ctx op st = .error .negativeLocktime := by
  rw [stepBody_cltv_path ctx op st o ha hw hb hfe]
  simp [hcltv, hs, hd, hn]

/-- INV-022 (checker reject): a nonnegative five-byte operand whose
`CheckLockTime` verdict is false fails with UNSATISFIED_LOCKTIME. -/
@[rule "INV-022"]
theorem stepBody_cltv_checker_false (ctx : Ctx) (op : WireOp) (st : State)
    (o : Fin 256) (ha : op.ast = .op o) (hw : op.wire = 0xb1)
    (hb : BudgetOk ctx st) (hfe : st.vf.all id = true)
    (hcltv : ctx.flags.cltv = true) (hs : ¬ st.stack.length < 1)
    {n : ScriptNum} (hd : decodeNum ctx.pol (topAt st.stack 1) 5 = .ok n)
    (hn : ¬ n < 0) (hcheck : checkLockTimeDef ctx.chk.env n = false) :
    stepBody ctx op st = .error .unsatisfiedLocktime := by
  rw [stepBody_cltv_path ctx op st o ha hw hb hfe]
  simp [hcltv, hs, hd, hn, hcheck]

/-- INV-022 (checker accept): a nonnegative five-byte operand whose
`CheckLockTime` verdict is true succeeds with the budget increment. -/
@[rule "INV-022"]
theorem stepBody_cltv_checker_true (ctx : Ctx) (op : WireOp) (st : State)
    (o : Fin 256) (ha : op.ast = .op o) (hw : op.wire = 0xb1)
    (hb : BudgetOk ctx st) (hfe : st.vf.all id = true)
    (hcltv : ctx.flags.cltv = true) (hs : ¬ st.stack.length < 1)
    {n : ScriptNum} (hd : decodeNum ctx.pol (topAt st.stack 1) 5 = .ok n)
    (hn : ¬ n < 0) (hcheck : checkLockTimeDef ctx.chk.env n = true) :
    stepBody ctx op st = .ok { st with opCount := stepOpCount ctx st } := by
  rw [stepBody_cltv_path ctx op st o ha hw hb hfe]
  simp [hcltv, hs, hd, hn, hcheck]

/-- INV-022 (operand width): the five-byte decode on the CLTV path bounds
the operand.  This is the opcode-local form of the INV-058 width rule. -/
@[rule "INV-022"]
theorem stepBody_cltv_operand_width (ctx : Ctx) (op : WireOp) (st : State)
    (o : Fin 256) (ha : op.ast = .op o) (hw : op.wire = 0xb1)
    (hb : BudgetOk ctx st) (hfe : st.vf.all id = true)
    (hcltv : ctx.flags.cltv = true) (hs : ¬ st.stack.length < 1)
    {n : ScriptNum} (hd : decodeNum ctx.pol (topAt st.stack 1) 5 = .ok n) :
    (topAt st.stack 1).size ≤ 5 :=
  BitcoinProofs.AF.PDW93.decodeNum_width_five hd

/-! ## Extracted CSV faces -/

/-- INV-023 (flag off): an executed CSV with the BIP112 flag clear is a
NOP; only the opcode budget moves. -/
@[rule "INV-023"]
theorem stepBody_csv_flag_off (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o) (hw : op.wire = 0xb2) (hb : BudgetOk ctx st)
    (hfe : st.vf.all id = true) (hcsv : ctx.flags.csv = false) :
    stepBody ctx op st = .ok { st with opCount := stepOpCount ctx st } := by
  rw [stepBody_csv_path ctx op st o ha hw hb hfe]
  simp [hcsv]

/-- INV-023 (stack underflow): an executed, flag-on CSV with an empty
main stack fails with INVALID_STACK_OPERATION. -/
@[rule "INV-023"]
theorem stepBody_csv_underflow (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o) (hw : op.wire = 0xb2) (hb : BudgetOk ctx st)
    (hfe : st.vf.all id = true) (hcsv : ctx.flags.csv = true)
    (hs : st.stack.length < 1) :
    stepBody ctx op st = .error .stackUnderflow := by
  rw [stepBody_csv_path ctx op st o ha hw hb hfe]
  simp [hcsv, hs]

/-- INV-023 (negative reject): a negative CSV operand fails with
NEGATIVE_LOCKTIME before the disable-bit and checker gates. -/
@[rule "INV-023"]
theorem stepBody_csv_negative (ctx : Ctx) (op : WireOp) (st : State) (o : Fin 256)
    (ha : op.ast = .op o) (hw : op.wire = 0xb2) (hb : BudgetOk ctx st)
    (hfe : st.vf.all id = true) (hcsv : ctx.flags.csv = true)
    (hs : ¬ st.stack.length < 1) {n : ScriptNum}
    (hd : decodeNum ctx.pol (topAt st.stack 1) 5 = .ok n) (hn : n < 0) :
    stepBody ctx op st = .error .negativeLocktime := by
  rw [stepBody_csv_path ctx op st o ha hw hb hfe]
  simp [hcsv, hs, hd, hn]

/-- INV-023 (disable-bit NOP): a nonnegative operand carrying the BIP68
disable bit succeeds as a NOP, without consulting `CheckSequence`. -/
@[rule "INV-023"]
theorem stepBody_csv_disable_nop (ctx : Ctx) (op : WireOp) (st : State)
    (o : Fin 256) (ha : op.ast = .op o) (hw : op.wire = 0xb2)
    (hb : BudgetOk ctx st) (hfe : st.vf.all id = true)
    (hcsv : ctx.flags.csv = true) (hs : ¬ st.stack.length < 1)
    {n : ScriptNum} (hd : decodeNum ctx.pol (topAt st.stack 1) 5 = .ok n)
    (hn : ¬ n < 0)
    (hdis : (n.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0) :
    stepBody ctx op st = .ok { st with opCount := stepOpCount ctx st } := by
  rw [stepBody_csv_path ctx op st o ha hw hb hfe]
  simp [hcsv, hs, hd, hn, hdis]

/-- INV-023 (checker reject): after the negative and disable-bit gates,
a false `CheckSequence` verdict fails with UNSATISFIED_LOCKTIME. -/
@[rule "INV-023"]
theorem stepBody_csv_checker_false (ctx : Ctx) (op : WireOp) (st : State)
    (o : Fin 256) (ha : op.ast = .op o) (hw : op.wire = 0xb2)
    (hb : BudgetOk ctx st) (hfe : st.vf.all id = true)
    (hcsv : ctx.flags.csv = true) (hs : ¬ st.stack.length < 1)
    {n : ScriptNum} (hd : decodeNum ctx.pol (topAt st.stack 1) 5 = .ok n)
    (hn : ¬ n < 0)
    (hdis : ¬ (n.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0)
    (hcheck : checkSequenceDef ctx.chk.env n = false) :
    stepBody ctx op st = .error .unsatisfiedLocktime := by
  rw [stepBody_csv_path ctx op st o ha hw hb hfe]
  simp [hcsv, hs, hd, hn, hdis, hcheck]

/-- INV-023 (checker accept): a nonnegative, non-disabled five-byte
operand whose `CheckSequence` verdict is true succeeds. -/
@[rule "INV-023"]
theorem stepBody_csv_checker_true (ctx : Ctx) (op : WireOp) (st : State)
    (o : Fin 256) (ha : op.ast = .op o) (hw : op.wire = 0xb2)
    (hb : BudgetOk ctx st) (hfe : st.vf.all id = true)
    (hcsv : ctx.flags.csv = true) (hs : ¬ st.stack.length < 1)
    {n : ScriptNum} (hd : decodeNum ctx.pol (topAt st.stack 1) 5 = .ok n)
    (hn : ¬ n < 0)
    (hdis : ¬ (n.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0)
    (hcheck : checkSequenceDef ctx.chk.env n = true) :
    stepBody ctx op st = .ok { st with opCount := stepOpCount ctx st } := by
  rw [stepBody_csv_path ctx op st o ha hw hb hfe]
  simp [hcsv, hs, hd, hn, hdis, hcheck]

/-- INV-023 (operand width): the five-byte decode on the CSV path bounds
the operand. -/
@[rule "INV-023"]
theorem stepBody_csv_operand_width (ctx : Ctx) (op : WireOp) (st : State)
    (o : Fin 256) (ha : op.ast = .op o) (hw : op.wire = 0xb2)
    (hb : BudgetOk ctx st) (hfe : st.vf.all id = true)
    (hcsv : ctx.flags.csv = true) (hs : ¬ st.stack.length < 1)
    {n : ScriptNum} (hd : decodeNum ctx.pol (topAt st.stack 1) 5 = .ok n) :
    (topAt st.stack 1).size ≤ 5 :=
  BitcoinProofs.AF.PDW93.decodeNum_width_five hd

end BitcoinProofs.AF.PDW68xPath
