import BitcoinProofs.Theorems.Ops.O02

/-! # PDW72 — TOP-381..385: EvalScript control-flow semantics

Route B row faces (zero core writes). The general dispatch-level proofs
live in `Theorems/Ops/O02`; this file restates them under the row ids
{SCR-056, SCR-058, SCR-061, SCR-068, SCR-069}. -/

namespace BitcoinProofs.AF.PDW72

open Bitcoin.Interpreter Bitcoin.Numeric
open BitcoinProofs.Theorems.Ops.O02

/-! ## SCR-056 — IF/NOTIF truth: CastToBool(top), NOTIF inverts, pop -/

@[rule "SCR-056"]
theorem scr056_if_effect (ctx : Ctx) (op : WireOp) (st : State)
    (hne : st.stack ≠ []) (hts : ctx.sv ≠ .tapscript)
    (hmv : ctx.sv ≠ .witnessV0 ∨ ctx.pol.minimalIf = false) :
    stepBody.dispatchOp ctx op 0x63 true st =
      .ok { st with vf := castToBool (topAt st.stack 1) :: st.vf,
                    stack := st.stack.tail } :=
  opIf_effect ctx op st hne hts hmv

@[rule "SCR-056"]
theorem scr056_notif_effect (ctx : Ctx) (op : WireOp) (st : State)
    (hne : st.stack ≠ []) (hts : ctx.sv ≠ .tapscript)
    (hmv : ctx.sv ≠ .witnessV0 ∨ ctx.pol.minimalIf = false) :
    stepBody.dispatchOp ctx op 0x64 true st =
      .ok { st with vf := (!(castToBool (topAt st.stack 1))) :: st.vf,
                    stack := st.stack.tail } :=
  opNotif_effect ctx op st hne hts hmv

/-! ### SCR-056 — the remaining EvalScript arms

The two theorems above cover the executed, non-tapscript, MINIMALIF-off
arm. The Core block at interpreter.cpp:613-645 has three further arms:
`!fExec` pushes `false` without touching the data stack (:617, :643), an
empty executed stack is INVALID_STACK_OPERATION (:620-621), tapscript
rejects a non-minimal operand with TAPSCRIPT_MINIMALIF (:624-630), and
witness-v0 with MINIMALIF rejects one with MINIMALIF (:632-637). The
theorems below pin each arm under the same row id, so the row no longer
depends on an unstated scope. -/

@[rule "SCR-056"]
theorem scr056_if_unexecuted (ctx : Ctx) (op : WireOp) (st : State) :
    stepBody.dispatchOp ctx op 0x63 false st =
      .ok { st with vf := false :: st.vf } :=
  opIfNotif_unexecuted ctx op st 0x63 (Or.inl rfl)

@[rule "SCR-056"]
theorem scr056_notif_unexecuted (ctx : Ctx) (op : WireOp) (st : State) :
    stepBody.dispatchOp ctx op 0x64 false st =
      .ok { st with vf := false :: st.vf } :=
  opIfNotif_unexecuted ctx op st 0x64 (Or.inr rfl)

@[rule "SCR-056"]
theorem scr056_if_underflow (ctx : Ctx) (op : WireOp) (st : State)
    (hnil : st.stack = []) :
    stepBody.dispatchOp ctx op 0x63 true st = .error .stackUnderflow :=
  opIfNotif_underflow ctx op st 0x63 (Or.inl rfl) hnil

@[rule "SCR-056"]
theorem scr056_notif_underflow (ctx : Ctx) (op : WireOp) (st : State)
    (hnil : st.stack = []) :
    stepBody.dispatchOp ctx op 0x64 true st = .error .stackUnderflow :=
  opIfNotif_underflow ctx op st 0x64 (Or.inr rfl) hnil

@[rule "SCR-056"]
theorem scr056_if_tapscript_minimalIf_error (ctx : Ctx) (op : WireOp) (st : State)
    (hts : ctx.sv = .tapscript) (hne : st.stack ≠ [])
    (hbad : 1 < (topAt st.stack 1).size ∨
            ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1)) :
    stepBody.dispatchOp ctx op 0x63 true st = .error .tapscriptMinimalIf :=
  opIfNotif_minimalIf_tapscript ctx op st 0x63 (Or.inl rfl) hts hne hbad

@[rule "SCR-056"]
theorem scr056_notif_tapscript_minimalIf_error (ctx : Ctx) (op : WireOp) (st : State)
    (hts : ctx.sv = .tapscript) (hne : st.stack ≠ [])
    (hbad : 1 < (topAt st.stack 1).size ∨
            ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1)) :
    stepBody.dispatchOp ctx op 0x64 true st = .error .tapscriptMinimalIf :=
  opIfNotif_minimalIf_tapscript ctx op st 0x64 (Or.inr rfl) hts hne hbad

@[rule "SCR-056"]
theorem scr056_if_tapscript_ok (ctx : Ctx) (op : WireOp) (st : State)
    (hts : ctx.sv = .tapscript) (hne : st.stack ≠ [])
    (hok : ¬ (1 < (topAt st.stack 1).size ∨
            ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1))) :
    stepBody.dispatchOp ctx op 0x63 true st =
      .ok { st with vf := castToBool (topAt st.stack 1) :: st.vf,
                    stack := st.stack.tail } := by
  have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
  simp [stepBody.dispatchOp, hts, hlen, hok]

@[rule "SCR-056"]
theorem scr056_notif_tapscript_ok (ctx : Ctx) (op : WireOp) (st : State)
    (hts : ctx.sv = .tapscript) (hne : st.stack ≠ [])
    (hok : ¬ (1 < (topAt st.stack 1).size ∨
            ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1))) :
    stepBody.dispatchOp ctx op 0x64 true st =
      .ok { st with vf := (!(castToBool (topAt st.stack 1))) :: st.vf,
                    stack := st.stack.tail } := by
  have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
  simp [stepBody.dispatchOp, hts, hlen, hok]

@[rule "SCR-056"]
theorem scr056_if_witnessV0_minimalIf_error (ctx : Ctx) (op : WireOp) (st : State)
    (hwv : ctx.sv = .witnessV0) (hpol : ctx.pol.minimalIf = true)
    (hne : st.stack ≠ [])
    (hbad : 1 < (topAt st.stack 1).size ∨
            ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1)) :
    stepBody.dispatchOp ctx op 0x63 true st = .error .minimalIf :=
  opIfNotif_minimalIf_witnessV0 ctx op st 0x63 (Or.inl rfl) hwv hpol hne hbad

@[rule "SCR-056"]
theorem scr056_notif_witnessV0_minimalIf_error (ctx : Ctx) (op : WireOp) (st : State)
    (hwv : ctx.sv = .witnessV0) (hpol : ctx.pol.minimalIf = true)
    (hne : st.stack ≠ [])
    (hbad : 1 < (topAt st.stack 1).size ∨
            ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1)) :
    stepBody.dispatchOp ctx op 0x64 true st = .error .minimalIf :=
  opIfNotif_minimalIf_witnessV0 ctx op st 0x64 (Or.inr rfl) hwv hpol hne hbad

@[rule "SCR-056"]
theorem scr056_if_witnessV0_minimalIf_ok (ctx : Ctx) (op : WireOp) (st : State)
    (hwv : ctx.sv = .witnessV0) (hpol : ctx.pol.minimalIf = true)
    (hne : st.stack ≠ [])
    (hok : ¬ (1 < (topAt st.stack 1).size ∨
            ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1))) :
    stepBody.dispatchOp ctx op 0x63 true st =
      .ok { st with vf := castToBool (topAt st.stack 1) :: st.vf,
                    stack := st.stack.tail } := by
  have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
  simp [stepBody.dispatchOp, hwv, hpol, hlen, hok]

@[rule "SCR-056"]
theorem scr056_notif_witnessV0_minimalIf_ok (ctx : Ctx) (op : WireOp) (st : State)
    (hwv : ctx.sv = .witnessV0) (hpol : ctx.pol.minimalIf = true)
    (hne : st.stack ≠ [])
    (hok : ¬ (1 < (topAt st.stack 1).size ∨
            ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1))) :
    stepBody.dispatchOp ctx op 0x64 true st =
      .ok { st with vf := (!(castToBool (topAt st.stack 1))) :: st.vf,
                    stack := st.stack.tail } := by
  have hlen : ¬ (st.stack.length < 1) := by have := len_pos hne; omega
  simp [stepBody.dispatchOp, hwv, hpol, hlen, hok]

/-! ## SCR-058 — tapscript MINIMALIF (consensus, BIP342) -/

@[rule "SCR-058"]
theorem scr058_minimalIf_tapscript (ctx : Ctx) (op : WireOp) (st : State)
    (w : Nat) (hw : w = 0x63 ∨ w = 0x64) (hts : ctx.sv = .tapscript)
    (hne : st.stack ≠ [])
    (hbad : 1 < (topAt st.stack 1).size ∨
            ((topAt st.stack 1).size = 1 ∧ (byteOr (topAt st.stack 1) 0).toNat ≠ 1)) :
    stepBody.dispatchOp ctx op w true st = .error .tapscriptMinimalIf :=
  opIfNotif_minimalIf_tapscript ctx op st w hw hts hne hbad

/-! ## SCR-061 — ELSE toggles the condition top; empty vf is unbalanced -/

@[rule "SCR-061"]
theorem scr061_else_empty (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State) :
    stepBody.dispatchOp ctx op 0x67 fExec { st with vf := [] } =
      .error .unbalancedConditional :=
  opElse_empty ctx op fExec st

@[rule "SCR-061"]
theorem scr061_else_toggle (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State)
    (v : Bool) (rest : List Bool) :
    stepBody.dispatchOp ctx op 0x67 fExec { st with vf := v :: rest } =
      .ok { st with vf := (!v) :: rest } :=
  opElse_toggle ctx op fExec st v rest

/-! ## SCR-068 — OP_VERIFY: pop iff true, else VERIFY error -/

@[rule "SCR-068"]
theorem scr068_verify_success (ctx : Ctx) (op : WireOp) (st : State)
    (hne : st.stack ≠ []) (htruthy : castToBool (topAt st.stack 1) = true) :
    stepBody.dispatchOp ctx op 0x69 true st =
      .ok { st with stack := st.stack.tail } :=
  opVerify_success ctx op st hne htruthy

@[rule "SCR-068"]
theorem scr068_verify_false (ctx : Ctx) (op : WireOp) (st : State)
    (hne : st.stack ≠ []) (hfalsy : castToBool (topAt st.stack 1) = false) :
    stepBody.dispatchOp ctx op 0x69 true st = .error .verifyFailed :=
  opVerify_false ctx op st hne hfalsy

@[rule "SCR-068"]
theorem scr068_verify_underflow (ctx : Ctx) (op : WireOp) (st : State)
    (hnil : st.stack = []) :
    stepBody.dispatchOp ctx op 0x69 true st = .error .stackUnderflow :=
  opVerify_underflow ctx op st hnil

/-! ## SCR-069 — executed OP_RETURN always fails -/

@[rule "SCR-069"]
theorem scr069_return_always (ctx : Ctx) (op : WireOp) (fExec : Bool) (st : State) :
    stepBody.dispatchOp ctx op 0x6a fExec st = .error .opReturn :=
  opReturn_always ctx op fExec st

end BitcoinProofs.AF.PDW72

#print axioms BitcoinProofs.AF.PDW72.scr056_if_effect
#print axioms BitcoinProofs.AF.PDW72.scr056_notif_effect
#print axioms BitcoinProofs.AF.PDW72.scr058_minimalIf_tapscript
#print axioms BitcoinProofs.AF.PDW72.scr061_else_empty
#print axioms BitcoinProofs.AF.PDW72.scr061_else_toggle
#print axioms BitcoinProofs.AF.PDW72.scr068_verify_success
#print axioms BitcoinProofs.AF.PDW72.scr068_verify_false
#print axioms BitcoinProofs.AF.PDW72.scr069_return_always
