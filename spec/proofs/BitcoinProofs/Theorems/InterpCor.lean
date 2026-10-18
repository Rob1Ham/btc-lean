import Bitcoin.Script.Interp

/-!
# BitcoinProofs.Theorems.InterpCor

correctness theorems over the C1 bootstrap script interpreter
(`Bitcoin.Script.Interp` — structural-fuel `step`/`run`).

DEPENDENCY NOTE: the production interpreter (interpreter tier with
full `Bitcoin.Consensus` plumbing) has **not landed**; these theorems
target the C1 bootstrap model and are marked for re-examination when
lands (its `evalScript` should satisfy the same fuel-canonicality laws;
the statements transfer verbatim if it keeps structural fuel).

Portfolio rows carried here (T2 trio + support):

* `run_fuel_canonical` — fuel above `length + 1` is irrelevant: the result
  of `run` depends only on the program and start stack once the budget
  covers the program (fuel is a stand-in for Core's op-count limit; the
  theorem says the limit never binds a program that fits).
* `run_ok_fuel_bound` / `run_fuel_mono` — success is monotone in fuel.
* `runsClean_fuel_irrelevant` / `runsTrue_fuel_irrelevant` — the script
  verdicts are fuel-independent above the canonical budget.
* `run_len1_not_scriptSize` — with the canonical budget the *fuel* error
  (`scriptSize`) is unreachable; the only failures are genuine opcode
  errors (stackUnderflow / verifyFailed / equalVerifyFailed).

All proofs are structural induction + rewriting; no `decide` through
recursive definitions.
-/

namespace BitcoinProofs.Theorems.InterpCor

open Bitcoin.Script Bitcoin.Data

/-! ## Basic unfolding laws -/

/-- Zero fuel always fails with the budget error. -/
theorem run_zero_scriptSize (prog : List ScriptInstr) (st : Stack) :
    run 0 prog st = .error .scriptSize := rfl

/-- The empty program succeeds with one unit of fuel. -/
theorem run_nil_ok (fuel : Nat) (st : Stack) : run (fuel + 1) [] st = .ok st := rfl

/-- One step of `run` is `step` composed with the rest of the run
(the `Except.bind` form of the `do`-block in the definition). -/
theorem run_cons_bind (fuel : Nat) (op : ScriptInstr) (rest : List ScriptInstr)
    (st : Stack) :
    run (fuel + 1) (op :: rest) st
      = (step op st).bind (fun s' => run fuel rest s') := rfl

/-- Distinct-`Except`-constructor helpers (noConfusion, once). -/
private theorem err_err_ne (a b : InterpError) (hne : a ≠ b) :
    (Except.error a : Except InterpError Stack) ≠ Except.error b := by
  intro h
  injection h with h'
  exact hne h'

private theorem ok_err_ne (s : Stack) (b : InterpError) :
    (Except.ok s : Except InterpError Stack) ≠ Except.error b := by
  intro h
  injection h

/-- `step` never raises the *fuel* error `scriptSize` — that error is
produced only by `run`'s budget check. -/
theorem step_ne_scriptSize (op : ScriptInstr) (st : Stack) :
    step op st ≠ .error .scriptSize := by
  cases op with
  | push => intro h; simp [step] at h
  | op1negate => intro h; simp [step] at h
  | const n => intro h; simp [step] at h
  | nop => intro h; simp [step] at h
  | verify =>
    cases st with
    | nil => intro h; simp [step] at h
    | cons top rest =>
      intro h
      simp only [step] at h
      split at h
      · exact err_err_ne _ _ (by decide) h
      · exact ok_err_ne rest .scriptSize h
  | equal =>
    cases st with
    | nil => intro h; simp [step] at h
    | cons top rest =>
      cases rest with
      | nil => intro h; simp [step] at h
      | cons t2 ts => intro h; simp [step] at h
  | equalVerify =>
    cases st with
    | nil => intro h; simp [step] at h
    | cons top rest =>
      cases rest with
      | nil => intro h; simp [step] at h
      | cons t2 ts =>
        intro h
        simp only [step] at h
        split at h
        · exact ok_err_ne ts .scriptSize h
        · exact err_err_ne _ _ (by decide) h
  | add =>
    cases st with
    | nil => intro h; simp [step] at h
    | cons top rest =>
      cases rest with
      | nil => intro h; simp [step] at h
      | cons t2 ts => intro h; simp [step] at h
  | checkSig =>
    cases st with
    | nil => intro h; simp [step] at h
    | cons top rest =>
      cases rest with
      | nil => intro h; simp [step] at h
      | cons t2 ts => intro h; simp [step] at h

/-! ## Fuel canonicality -/

/-- **T2** — fuel canonicality: once the budget covers the program
(`prog.length + 1`) plus any slack `k`, the result equals the
canonical-budget result. Induction on the program, generalizing the
stack. -/
theorem run_fuel_canonical (prog : List ScriptInstr) :
    ∀ (st : Stack) (k : Nat),
      run (prog.length + 1 + k) prog st = run (prog.length + 1) prog st := by
  induction prog with
  | nil =>
    intro st k
    rw [show ([] : List ScriptInstr).length + 1 + k = ([] : List ScriptInstr).length + k + 1 from by omega]
    rfl
  | cons op rest ih =>
    intro st k
    rw [show (op :: rest).length + 1 + k = (op :: rest).length + k + 1 from by omega]
    simp only [run, List.length_cons]
    cases hs : step op st
    · rename_i e
      rfl
    · rename_i s'
      show run (rest.length + 1 + k) rest s' = run (rest.length + 1) rest s'
      exact ih s' k

/-- A successful run's fuel covered the program: `prog.length + 1 ≤ f`
(the pc-loop needs one unit per opcode plus the terminating check). -/
theorem run_ok_fuel_bound (prog : List ScriptInstr) :
    ∀ (f : Nat) (st : Stack) (s' : Stack),
      run f prog st = .ok s' → prog.length + 1 ≤ f := by
  induction prog with
  | nil =>
    intro f st s' h
    match f with
    | 0 => simp [run] at h
    | f+1 =>
      have h0 : ([] : List ScriptInstr).length = 0 := by rfl
      omega
  | cons op rest ih =>
    intro f st s' h
    match f with
    | 0 => simp [run] at h
    | f+1 =>
      rw [run_cons_bind] at h
      cases hs : step op st
      · rename_i e
        rw [hs] at h
        simp only [Except.bind] at h
        injection h
      · rename_i s''
        rw [hs] at h
        simp only [Except.bind] at h
        have h2 := ih f s'' s' h
        have hl : (op :: rest).length = rest.length + 1 := by rfl
        omega

/-- **T2** — success monotonicity: if `run f prog st` succeeds, so does
`run (f + k) prog st`, with the same result stack. -/
theorem run_fuel_mono (prog : List ScriptInstr) (f k : Nat) (st s' : Stack)
    (h : run f prog st = .ok s') :
    run (f + k) prog st = .ok s' := by
  have hb := run_ok_fuel_bound prog f st s' h
  have h1 := run_fuel_canonical prog st (f - (prog.length + 1))
  have h2 := run_fuel_canonical prog st (f - (prog.length + 1) + k)
  have hshift : f = prog.length + 1 + (f - (prog.length + 1)) := by omega
  have hshift2 : f + k = prog.length + 1 + (f - (prog.length + 1) + k) := by omega
  rw [hshift] at h
  rw [h1] at h
  rw [hshift2, h2]
  exact h

/-! ## Fuel-irrelevance of the script verdicts -/

/-- **T2** — `runsClean` is fuel-independent above the canonical budget. -/
theorem runsClean_fuel_irrelevant (prog : List ScriptInstr) (k : Nat) :
    runsClean (prog.length + 1 + k) prog = runsClean (prog.length + 1) prog := by
  unfold runsClean
  rw [run_fuel_canonical prog [] k]

/-- **T2** — `runsTrue` is fuel-independent above the canonical budget. -/
theorem runsTrue_fuel_irrelevant (prog : List ScriptInstr) (k : Nat) :
    runsTrue (prog.length + 1 + k) prog = runsTrue (prog.length + 1) prog := by
  unfold runsTrue
  rw [run_fuel_canonical prog [] k]

/-- With the canonical budget the fuel error `scriptSize` is unreachable —
the only possible failures are genuine opcode errors
(stackUnderflow / verifyFailed / equalVerifyFailed). -/
theorem run_len1_not_scriptSize (prog : List ScriptInstr) (st : Stack) :
    run (prog.length + 1) prog st ≠ .error .scriptSize := by
  induction prog generalizing st with
  | nil => rw [run_nil_ok]; simp
  | cons op rest ih =>
    rw [run_cons_bind]
    cases hs : step op st
    · rename_i e
      show Except.error e ≠ .error .scriptSize
      have hne := step_ne_scriptSize op st
      rw [hs] at hne
      exact hne
    · rename_i s'
      show run (rest.length + 1) rest s' ≠ .error .scriptSize
      exact ih s'

/-! ## Axiom-footprint pins (L3): drift on any of these fails the build -/

/-- info: 'BitcoinProofs.Theorems.InterpCor.run_zero_scriptSize' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms run_zero_scriptSize

/-- info: 'BitcoinProofs.Theorems.InterpCor.run_nil_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms run_nil_ok

/-- info: 'BitcoinProofs.Theorems.InterpCor.run_cons_bind' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms run_cons_bind

/-- info: 'BitcoinProofs.Theorems.InterpCor.step_ne_scriptSize' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms step_ne_scriptSize

/-- info: 'BitcoinProofs.Theorems.InterpCor.run_fuel_canonical' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms run_fuel_canonical

/-- info: 'BitcoinProofs.Theorems.InterpCor.run_ok_fuel_bound' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms run_ok_fuel_bound

/-- info: 'BitcoinProofs.Theorems.InterpCor.run_fuel_mono' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms run_fuel_mono

/-- info: 'BitcoinProofs.Theorems.InterpCor.runsClean_fuel_irrelevant' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms runsClean_fuel_irrelevant

/-- info: 'BitcoinProofs.Theorems.InterpCor.runsTrue_fuel_irrelevant' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms runsTrue_fuel_irrelevant

/-- info: 'BitcoinProofs.Theorems.InterpCor.run_len1_not_scriptSize' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms run_len1_not_scriptSize

end BitcoinProofs.Theorems.InterpCor
