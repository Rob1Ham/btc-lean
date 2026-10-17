import Bitcoin.Interpreter.Defs

/-! # PDW39b — TOP-286..290: D-STEP control/fuel/resource band (route B)

Row-face theorems for the interpreter eval loop in
`Bitcoin/Interpreter/Defs.lean` (`interpreter.cpp:566-569`, `:419-421`,
`EvalScript`'s opcode loop). Core defs read-only; zero core writes.

* **INV-044** `stepChecked` — terminal stack+alt guard ≤ 1000.
* **SCR-003** `evalFrom` — empty stream succeeds with the state untouched.
* **SCR-063** `evalFrom` — non-empty `vf` at stream end ⇒ unbalancedConditional.
* **INV-047** `evalFrom` — every successful run ends with `vf = []`.
* **SCR-019** `evalScriptBytes` — the 10k SCRIPT_SIZE guard is off for TAPSCRIPT.
-/

namespace BitcoinProofs.AF.PDW39b

open Bitcoin.Interpreter
open Bitcoin.Activation (ScriptFlags)
open Bitcoin.Crypto.Seam (ScriptExecutionData)

/-- INV-044 (`interpreter.cpp:566-569`): a successful step leaves
`stack.length + alt.length` within MAX_STACK_SIZE (1000). -/
@[rule "INV-044"]
theorem stepChecked_stack_alt_bound {ctx : Ctx} {op : WireOp} {st st' : State}
    (h : stepChecked ctx op st = .ok st') :
    st'.stack.length + st'.alt.length ≤ MAX_STACK_SIZE :=
  Bitcoin.Interpreter.stepChecked_ok_bound h

/-- SCR-003: an empty opcode stream with an empty condition stack returns
the state unchanged (`EvalScript`'s loop falls through). -/
@[rule "SCR-003"]
theorem evalFrom_nil_ok (ctx : Ctx) (f : Nat) (st : State) (hv : st.vf = []) :
    evalFrom ctx (Nat.succ f) [] st = .ok st := by
  simp [evalFrom, hv]

/-- SCR-063: a non-empty condition stack at end of stream is the
`unbalancedConditional` failure (`interpreter.cpp:500-503`). -/
@[rule "SCR-063"]
theorem evalFrom_nil_unbalanced (ctx : Ctx) (f : Nat) (st : State)
    (hv : st.vf ≠ []) :
    evalFrom ctx (Nat.succ f) [] st = .error .unbalancedConditional := by
  simp [evalFrom, hv]

/-- INV-047: balanced conditionals — the only success return of the loop
is the empty-stream arm, which requires `vf = []`; hence every successful
run ends with an empty condition stack. -/
@[rule "INV-047"]
theorem evalFrom_ok_vf_nil (ctx : Ctx) :
    ∀ (f : Nat) (ops : List WireOp) (st st' : State),
      evalFrom ctx f ops st = .ok st' → st'.vf = [] := by
  intro f
  induction f with
  | zero => intro ops st st' h; simp [evalFrom] at h
  | succ f ih =>
    intro ops st st' h
    cases ops with
    | nil =>
      simp only [evalFrom] at h
      split at h
      · rename_i hv
        simp only [Except.ok.injEq] at h
        subst h
        exact hv
      · simp at h
    | cons op rest =>
      simp only [evalFrom] at h
      cases hsc : stepChecked ctx op st with
      | error e => rw [hsc] at h; simp at h
      | ok s => rw [hsc] at h; exact ih rest s st' h

/-- SCR-019 (`interpreter.cpp:419-421`): the 10,000-byte SCRIPT_SIZE
pre-check is keyed on `base ∨ witnessV0`; for TAPSCRIPT the call skips it
and reduces to the parse/eval branch at any script size. -/
@[rule "SCR-019"]
theorem evalScriptBytes_tapscript_no_size_guard
    (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (b : ByteArray) (st0 : Stack) (chk : ScriptChecker)
    (ed : ScriptExecutionData) :
    evalScriptBytes fuel flags pol b st0 chk .tapscript ed =
      match parseWire b with
      | none => .error .badOpcode
      | some ops =>
        finalStack (evalFrom ⟨flags, pol, chk, .tapscript, b, ed⟩ fuel ops
          { stack := st0, alt := [], vf := [], opCount := 0, codeSep := 0,
            vwLeft := some ed.validationWeightLeft }) := by
  simp only [evalScriptBytes]
  split
  · simp_all
  · rfl

end BitcoinProofs.AF.PDW39b
