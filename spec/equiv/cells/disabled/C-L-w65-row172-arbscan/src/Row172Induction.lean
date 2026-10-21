import Bitcoin.Script.Tapscript.Delta

/-!
# SCR-172 — arbitrary-length reachability induction (cell-local)

This file belongs to the cell `disabled/C-L-w65-row172-arbscan`.  It is *not*
part of `spec/proofs` and it edits nothing shared.  It closes, on the Lean side,
the part of SCR-172 that the bounded IR cells cannot state: the pre-scan and the
legacy disabled gate are byte predicates folded over a decode walk of
**arbitrary** length.

## Tapscript half

`opSuccessScanFrom` / `opSuccessScan` (Defs.lean:479-492) are the literal
transcription of Core's `ExecuteWitnessScript` OP_SUCCESSx pre-scan
(interpreter.cpp:1846-1862).  `ScanPath` records the index sequence of the
decode walk; `opSuccessScan_of_reaches_success` says that if the walk reaches
*any* decoded `.op` whose wire byte is in `IsOpSuccess`, the scan returns
`true`, for any script length and any suffix after that opcode.  Applied to a
legacy-disabled wire (`disabledWire_success`), and composed with
`executeWitnessScript_success_total` / `_success_discourage`, this yields the
row's tapscript outcome before the stack-size and 520-byte item checks.

## Base half

`evalFrom_prefix_disabled` says that if the BASE/WITNESS_V0 `EvalScript` walk
steps a prefix without error and then reaches a decoded wire op in the legacy
disabled table, it returns `SCRIPT_ERR_DISABLED_OPCODE` — again for a script of
arbitrary length.  The `opCount < MAX_OPS_PER_SCRIPT` hypothesis is real, not
cosmetic: at the 201-op boundary a counting disabled opcode yields
`OP_COUNT`, so the disabled verdict is conditional on the budget (PDW60's
exact dichotomy).

The file is compiled by `lean/run.sh` with `lake env lean`; the runner checks
the `#print axioms` footprints below and rejects any `sorryAx`.
-/

namespace Wave65Row172

set_option linter.deprecated false
set_option linter.unusedSimpArgs false

open Bitcoin.Interpreter
open Bitcoin.Script.Parser
open Bitcoin.Script.Tapscript
open Bitcoin.Crypto.Seam (SigVersion)
open Bitcoin.Activation

/-! ## A fuel-free decode path

`ScanPath b s i j` says: starting the decode walk at byte index `i`, after `s`
successful `getOp` decodes the walk stands at index `j`.  This is exactly the
index sequence Core's `while (pc < pend)` and Lean's `opSuccessScanFrom`
follow (both advance by `getOp`'s `next`). -/

inductive ScanPath (b : ByteArray) : Nat → Nat → Nat → Prop where
  | refl (i : Nat) : ScanPath b 0 i i
  | step {s i i' j : Nat} {o : Opcode}
      (h : getOp b i = some (o, i')) (hr : ScanPath b s i' j) :
      ScanPath b (s + 1) i j

/-- Every decode advances by at least one byte, so a path of `s` decodes that
starts in bounds ends in bounds and consumes at least `s` bytes. -/
theorem ScanPath.progress {b : ByteArray} :
    ∀ {s i j : Nat}, ScanPath b s i j → i ≤ b.size → i + s ≤ j ∧ j ≤ b.size := by
  intro s i j hp
  induction hp with
  | refl i => intro hi; exact ⟨by omega, hi⟩
  | @step s i i' j o h hr ih =>
      intro hi
      obtain ⟨hlt, hle, _⟩ := getOp_spec h
      obtain ⟨h1, h2⟩ := ih hle
      exact ⟨by omega, h2⟩

/-- **Soundness**: a successful scan means some decoded `.op` on the path has a
success wire byte. -/
theorem opSuccessScanFrom_sound {f : Nat} {b : ByteArray} {i : Nat}
    (h : opSuccessScanFrom f b i = true) :
    ∃ (s j : Nat) (c : Fin 256) (j' : Nat),
      ScanPath b s i j ∧ getOp b j = some (Opcode.op c, j') ∧
        isOpSuccessWire c.toNat = true := by
  induction f generalizing i with
  | zero => simp [opSuccessScanFrom] at h
  | succ f ih =>
      unfold opSuccessScanFrom at h
      by_cases hsize : b.size ≤ i
      · simp [hsize] at h
      · rw [if_neg hsize] at h
        cases hg : getOp b i with
        | none => rw [hg] at h; simp at h
        | some p =>
            obtain ⟨o, i'⟩ := p
            rw [hg] at h
            cases o with
            | pushBytes d =>
                obtain ⟨s, j, c, j', hp, hgot, hs⟩ := ih h
                exact ⟨s + 1, j, c, j', ScanPath.step hg hp, hgot, hs⟩
            | pushNum n =>
                obtain ⟨s, j, c, j', hp, hgot, hs⟩ := ih h
                exact ⟨s + 1, j, c, j', ScanPath.step hg hp, hgot, hs⟩
            | op c =>
                by_cases hc : isOpSuccessWire c.toNat = true
                · exact ⟨0, i, c, i', ScanPath.refl i, hg, hc⟩
                · simp only [hc] at h
                  obtain ⟨s, j, c', j', hp, hgot, hs⟩ := ih h
                  exact ⟨s + 1, j, c', j', ScanPath.step hg hp, hgot, hs⟩

/-- **Completeness**: if a path reaches a decoded `.op` with a success wire
byte and the fuel is at least the path length plus one (so the opcode itself is
inspected), the scan returns `true`. -/
theorem opSuccessScanFrom_complete {b : ByteArray} :
    ∀ {s i j : Nat}, ScanPath b s i j →
      ∀ (f : Nat), s + 1 ≤ f →
        ∀ (c : Fin 256) (j' : Nat), getOp b j = some (Opcode.op c, j') →
          isOpSuccessWire c.toNat = true → opSuccessScanFrom f b i = true := by
  intro s i j hp
  induction hp with
  | refl i =>
      intro f hf c j' hget hs
      cases f with
      | zero => omega
      | succ f =>
          unfold opSuccessScanFrom
          have hsize : ¬ b.size ≤ i := by
            have := getOp_lt hget; omega
          rw [if_neg hsize, hget]
          simp only [hs, ite_true]
  | @step s i i' j o hget hr ih =>
      intro f hf c j' hgetj hs
      cases f with
      | zero => omega
      | succ f =>
          unfold opSuccessScanFrom
          have hsize : ¬ b.size ≤ i := by
            have := getOp_lt hget; omega
          rw [if_neg hsize, hget]
          cases o with
          | pushBytes d => exact ih f (by omega) c j' hgetj hs
          | pushNum n => exact ih f (by omega) c j' hgetj hs
          | op c0 =>
              by_cases hc0 : isOpSuccessWire c0.toNat = true
              · simp only [hc0, ite_true]
              · simp only [hc0]
                exact ih f (by omega) c j' hgetj hs

/-- **Main arbitrary-length theorem (tapscript success reachability).**  If the
decode walk from index `0` reaches a decoded opcode whose wire byte is in the
`IsOpSuccess` set, then `opSuccessScan` succeeds, with no bound on the script
length and no condition on the bytes after that opcode. -/
theorem opSuccessScan_of_reaches_success {b : ByteArray} {s j : Nat} {c : Fin 256} {j' : Nat}
    (hp : ScanPath b s 0 j)
    (hget : getOp b j = some (Opcode.op c, j'))
    (hs : isOpSuccessWire c.toNat = true) :
    opSuccessScan b = true := by
  have hprog := hp.progress (by omega)
  have hfuel : s + 1 ≤ b.size + 1 := by omega
  exact opSuccessScanFrom_complete hp (b.size + 1) hfuel c j' hget hs

/-- A decoded legacy-disabled wire is by definition an OP_SUCCESSx under
tapscript (`disabledWire_success`), so the reachability theorem applies to
every disabled byte that the decode walk actually reaches as an opcode. -/
theorem opSuccessScan_of_reaches_disabled {b : ByteArray} {s j : Nat} {c : Fin 256} {j' : Nat}
    (hp : ScanPath b s 0 j)
    (hget : getOp b j = some (Opcode.op c, j'))
    (hd : disabledWire c.toNat = true) :
    opSuccessScan b = true :=
  opSuccessScan_of_reaches_success hp hget (disabledWire_success c.toNat hd)

/-- **Same bytes, tapscript outcome (arbitrary length).**  For every script
containing a reachable disabled opcode, `ExecuteWitnessScript` at the tapscript
sigversion returns `ok` under the consensus policy (bit clear) or the named
policy failure (bit set) — before the initial stack-size check, the 520-byte
item check and EvalScript, for every witness stack, including oversized items
and more than 1000 items. -/
theorem executeWitnessScript_tapscript_of_reaches_disabled
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) {b : ByteArray}
    {s j : Nat} {c : Fin 256} {j' : Nat} (hp : ScanPath b s 0 j)
    (hget : getOp b j = some (Opcode.op c, j'))
    (hd : disabledWire c.toNat = true)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker) :
    executeWitnessScript fuel items vwSer b flags
        { pol with discourageOpSuccess := false } chk SigVersion.tapscript
      = VerifyOutcome.ok ∧
    executeWitnessScript fuel items vwSer b flags
        { pol with discourageOpSuccess := true } chk SigVersion.tapscript
      = VerifyOutcome.fail ExecError.discourageOpSuccess :=
  ⟨executeWitnessScript_success_total fuel items vwSer b flags pol chk
      (opSuccessScan_of_reaches_disabled hp hget hd),
   executeWitnessScript_success_discourage fuel items vwSer b flags pol chk
      (opSuccessScan_of_reaches_disabled hp hget hd)⟩

/-! ## Base half: the legacy disabled gate over an arbitrary prefix -/

/-- Every legacy-disabled wire byte is > 0x60, so BASE/WITNESS_V0 count it
against the 201-op budget (local copy of PDW60's helper; the cell may not
import `spec/proofs`). -/
theorem disabledWire_gt_60 (w : Nat) (h : disabledWire w = true) : 0x60 < w := by
  simp only [Bitcoin.Interpreter.disabledWire, decide_eq_true_eq,
    List.mem_cons, List.not_mem_nil, or_false] at h
  rcases h with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl <;> decide

/-- A disabled wire opcode fails with `disabledOpcode`, provided the
BASE/WITNESS_V0 op-count budget is not already exhausted.  Same proof shape as
PDW60's `stepBody_disabled`; kept cell-local because this file imports only the
core package. -/
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

theorem stepChecked_disabled {ctx : Ctx} {op : WireOp} {st : State} {b : Fin 256}
    (hast : op.ast = .op b) (hdis : disabledWire op.wire = true)
    (hoc : st.opCount < MAX_OPS_PER_SCRIPT) :
    stepChecked ctx op st = .error ExecError.disabledOpcode := by
  unfold stepChecked
  rw [stepBody_disabled ctx st op b hast hdis hoc]

/-- Prefix runner: the state after stepping a list of wire ops, if every step
returns `.ok`.  This is the state-threading fragment of `evalFrom`. -/
def runPrefix (ctx : Ctx) : List WireOp → State → Option State
  | [], st => some st
  | op :: rest, st =>
      match stepChecked ctx op st with
      | .ok st' => runPrefix ctx rest { st' with opcodeIndex := st.opcodeIndex + 1 }
      | .error _ => none

/-- **Base-side arbitrary-length theorem.**  If the `EvalScript` walk reaches a
decoded wire op that is in the legacy disabled set, and the op-count budget is
not exhausted there, it returns `SCRIPT_ERR_DISABLED_OPCODE`, for any script
length.  `runPrefix` is the hypothesis that the preceding opcodes step without
error (if one of them errors first, that error is what Core returns).  The
budget caveat is PDW60's exact dichotomy: at `opCount = 201` a counting
disabled opcode yields OP_COUNT, not DISABLED_OPCODE. -/
theorem evalFrom_prefix_disabled (ctx : Ctx) :
    ∀ (pre : List WireOp) (op : WireOp) (rest : List WireOp) (st st' : State),
      runPrefix ctx pre st = some st' →
      (∃ b : Fin 256, op.ast = .op b) →
      disabledWire op.wire = true →
      st'.opCount < MAX_OPS_PER_SCRIPT →
      evalFrom ctx (pre.length + 1) (pre ++ op :: rest) st
        = .error ExecError.disabledOpcode := by
  intro pre
  induction pre with
  | nil =>
      intro op rest st st' hrun hast hd hoc
      simp only [List.length_nil, Nat.zero_add, List.nil_append] at *
      obtain ⟨b, hb⟩ := hast
      cases hrun
      simp only [evalFrom]
      rw [stepChecked_disabled hb hd hoc]
  | cons op0 pre ih =>
      intro op rest st st' hrun hast hd hoc
      simp only [List.length_cons, List.cons_append]
      simp only [runPrefix] at hrun
      cases hstep : stepChecked ctx op0 st with
      | error e => rw [hstep] at hrun; simp at hrun
      | ok st1 =>
          rw [hstep] at hrun
          simp only [evalFrom]
          rw [hstep]
          exact ih op rest { st1 with opcodeIndex := st.opcodeIndex + 1 } st' hrun hast hd hoc

/-! ## Axiom footprints (checked by `lean/run.sh`) -/

#print axioms opSuccessScan_of_reaches_success
#print axioms opSuccessScan_of_reaches_disabled
#print axioms executeWitnessScript_tapscript_of_reaches_disabled
#print axioms evalFrom_prefix_disabled

end Wave65Row172
