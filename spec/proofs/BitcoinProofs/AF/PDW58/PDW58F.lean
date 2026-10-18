import Bitcoin.Interpreter.Defs

/-! # PDW58F.lean — replacement rows: SCR-122 / SCR-126 negative operands
(PDW58, RC29). Route B: zero core writes. Row faces for the two
NEGATIVE_LOCKTIME branches of `stepBody.dispatchOp`
(interpreter.cpp:556 CLTV @cce32b168; CSV branch :1840s). -/

namespace BitcoinProofs.AF.PDW58

open Bitcoin.Interpreter Bitcoin.Numeric

/-- SCR-122: a negative CLTV operand raises NEGATIVE_LOCKTIME (checked
after decode, before the type agreement and the numeric comparison). -/
@[rule "SCR-122"]
theorem cltv_negative_errors (ctx : Ctx) (op : WireOp) (st : State)
    (hc : ctx.flags.cltv = true) (hne : ¬ st.stack.length < 1)
    (n : ScriptNum) (hd : decodeNum ctx.pol (topAt st.stack 1) 5 = .ok n)
    (hn : n < 0) :
    stepBody.dispatchOp ctx op 0xb1 true st = .error .negativeLocktime := by
  unfold Bitcoin.Interpreter.stepBody.dispatchOp
  simp only [hne, hc, hd, hn]
  simp

/-- SCR-122 (strictness): the negative branch pre-empts every later gate,
so no environment value can turn a negative CLTV operand into success. -/
@[rule "SCR-122"]
theorem cltv_negative_not_ok (ctx : Ctx) (op : WireOp) (st : State)
    (hc : ctx.flags.cltv = true) (hne : ¬ st.stack.length < 1)
    (n : ScriptNum) (hd : decodeNum ctx.pol (topAt st.stack 1) 5 = .ok n)
    (hn : n < 0) :
    stepBody.dispatchOp ctx op 0xb1 true st ≠ .ok st := by
  rw [cltv_negative_errors ctx op st hc hne n hd hn]
  simp

/-- SCR-126: a negative CSV operand raises NEGATIVE_LOCKTIME, even when
the operand also carries the disable flag (the sign check comes first). -/
@[rule "SCR-126"]
theorem csv_negative_errors (ctx : Ctx) (op : WireOp) (st : State)
    (hc : ctx.flags.csv = true) (hne : ¬ st.stack.length < 1)
    (n : ScriptNum) (hd : decodeNum ctx.pol (topAt st.stack 1) 5 = .ok n)
    (hn : n < 0) :
    stepBody.dispatchOp ctx op 0xb2 true st = .error .negativeLocktime := by
  unfold Bitcoin.Interpreter.stepBody.dispatchOp
  simp only [hne, hc, hd, hn]
  simp

/-- SCR-126 (strictness): negative CSV operands are never a NOP and never
reach the CheckSequence comparison. -/
@[rule "SCR-126"]
theorem csv_negative_not_ok (ctx : Ctx) (op : WireOp) (st : State)
    (hc : ctx.flags.csv = true) (hne : ¬ st.stack.length < 1)
    (n : ScriptNum) (hd : decodeNum ctx.pol (topAt st.stack 1) 5 = .ok n)
    (hn : n < 0) :
    stepBody.dispatchOp ctx op 0xb2 true st ≠ .ok st := by
  rw [csv_negative_errors ctx op st hc hne n hd hn]
  simp

end BitcoinProofs.AF.PDW58
