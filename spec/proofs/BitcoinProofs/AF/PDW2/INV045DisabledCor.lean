import Bitcoin.Interpreter.Defs

/-!
# INV045DisabledCor — T12/INV-045 promotion proof (P16)

Row INV-045 (disabled opcodes fail unconditionally,
CVE-2010-5137; core anchor interpreter.cpp:472-483 @cce32b168).

Statement P16 = `stepBody_disabled_ne_ok`, restated 1:1 verbatim.

Semantics: if `op`'s wire byte is in the `disabledWire` set, then NO
`stepBody` transition can ever land in `.ok` — every path out of the
gate chain is an `.error` (gates (1) `pushSize`, (2) `opCount`, and
(3) `disabledOpcode` itself), exactly Core's CVE-2010-5137 fix (a
disabled opcode fails the script even when never executed).
Proof = gate-herding: unfold `stepBody` (`simp only [stepBody] at h`),
fold `hd` in (`rw [hd]`), full `simp` (collapses the dead
`if disabledWire … = true`-ite to `.error .disabledOpcode`), then
`repeat' split at h; all_goals nomatch h` — every residual ite
branch lands in an `.error`-constructor-LHS `= .ok`-RHS, impossible
(`nomatch` on the `Except.inl … = Except.inr …`-shape `Eq`;
core-`split` forensics behind this proof shape = F-PDW2-002).
The `≠`-form (a `.error`-side `.ok`-impossibility) is exactly the
"every error path of stepBody counts" reading PD03 assigned P16.
No mathlib, no decide, no induction.

Axiom-pinned in-file (D2 L3); zero sorryAx expected.
-/

namespace BitcoinProofs.AF.PDW2

/-- INV-045 (CVE-2010-5137): a disabled wire opcode can never step a
state to `.ok` (every error path of `stepBody` counts). -/
@[rule "INV-045"]
theorem stepBody_disabled_ne_ok {ctx : Bitcoin.Interpreter.Ctx}
    {st st' : Bitcoin.Interpreter.State} {op : Bitcoin.Interpreter.WireOp}
    (hd : Bitcoin.Interpreter.disabledWire op.wire = true) :
    Bitcoin.Interpreter.stepBody ctx op st ≠ Except.ok st' := by
  intro h
  simp only [Bitcoin.Interpreter.stepBody] at h
  rw [hd] at h
  simp at h
  repeat' split at h
  all_goals nomatch h

end BitcoinProofs.AF.PDW2
