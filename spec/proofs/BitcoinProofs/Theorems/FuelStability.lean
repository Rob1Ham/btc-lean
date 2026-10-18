import Bitcoin.Interpreter.Defs

/-!
# BitcoinProofs.Theorems.FuelStability — fuel independence of `evalFrom`

## What this module actually proves

`Bitcoin.Interpreter.Defs` is a fuel-bounded machine: `evalFrom` consumes one
unit of fuel per executed opcode, and `evalScriptBytes`/`verifyScriptFull`/
`executeWitnessScript` thread a `fuel : Nat` through every entry point. Core's
`EvalScript` has no such parameter.

This module proves the syntactic core of fuel independence:

* `evalFrom_eventually_constant`: if `fuel` is strictly larger than the number
  of remaining wire ops, then every larger fuel value produces exactly the same
  `Except` verdict and final state. The proof uses only the step shape (each
  iteration consumes one op and `stepChecked` never inspects fuel); it does not
  look inside any opcode semantics.

The theorem is deliberately conditional on `ops.length < fuel`. That bound is
the honest one: at `fuel = 0` the machine returns the `unknownError` catch-all,
and at `fuel <= ops.length` the run can stop early.

## What is NOT here (open obligations)

Earlier revisions of this header advertised a larger development
(`FUEL-STAB`, `FUEL-OPS`, `FUEL-LIT`, `FUEL-CAN`, the `PushShaped`/`litOfOp`
literal bound, and canonicity of `pipelineFuel = ss.size + spk.size + wbytes +
28`). None of those declarations existed, and the one `stepBody` theorem that
did exist was malformed. The claims and the unfinished definitions are removed
rather than left dangling.

In particular this module does **not** prove that the consensus pipeline's
canonical fuel is above the stability bound. That requires a bound on the
number of parsed ops in terms of script and witness bytes (including the P2SH
inner-evaluation lane); it remains an open proof obligation recorded in
`docs/RESIDUALS.md`. A default-root build must not be read as proving that
`pipelineFuel` is canonical.
-/

namespace Bitcoin.Proofs.Theorems.FuelStability

open Bitcoin.Interpreter

/-- **Fuel stability of `evalFrom`.** If `ops.length < f₁`, then `evalFrom`
at any `f₂ ≥ f₁` agrees with `evalFrom` at `f₁` on the same context, ops and
state. Induction is on `ops`; each step unfolds one `stepChecked` transition
(which is fuel-blind) and applies the induction hypothesis to the tail. -/
theorem evalFrom_eventually_constant (ctx : Ctx) :
    ∀ (ops : List WireOp) (st : State) (f₁ : Nat),
      ops.length < f₁ →
      ∀ f₂ : Nat, f₁ ≤ f₂ → evalFrom ctx f₂ ops st = evalFrom ctx f₁ ops st := by
  intro ops
  induction ops with
  | nil =>
    intro st f1 hf f2 hf2
    cases f1 with
    | zero => simp at hf
    | succ f1' =>
      cases f2 with
      | zero => omega
      | succ f2' => rfl
  | cons op rest ih =>
    intro st f1 hf f2 hf2
    cases f1 with
    | zero => simp at hf
    | succ f1' =>
      cases f2 with
      | zero => omega
      | succ f2' =>
        have hrest : rest.length < f1' := by
          simp only [List.length_cons] at hf; omega
        have hle : f1' ≤ f2' := by omega
        cases hstep : stepChecked ctx op st with
        | ok st' =>
          simp only [evalFrom, hstep]
          exact ih st' f1' hrest f2' hle
        | error e => simp only [evalFrom, hstep]

/-- info: 'Bitcoin.Proofs.Theorems.FuelStability.evalFrom_eventually_constant' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms evalFrom_eventually_constant

end Bitcoin.Proofs.Theorems.FuelStability
