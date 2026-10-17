import Bitcoin.Interpreter.Defs

/-!
# Z09 dark-corner audit — dead-branch opcode counting + disabled opcodes in
unexecuted branches (W4 suite, 2026-10-16)

NEW file, owned by Z09 alone. Python3 probes:
`build/scratch/build/scratch/scratch/Z09/xcheck.py` (transcription of
`EvalScript`'s pre-execution block, vendored Core @ `c50817f`,
`build/scratch/W02/bitcoin/src/script/interpreter.cpp:448-500`).
Findings: `spec/db/findings-w4/Z09.md`.

## Corners audited

* **C1 — dead-branch opcode counting** (SCR-022/023/024; Review-1 report
  `research/06-script-interpreter.md`): the 201-opcode budget check
  (interpreter.cpp:462-463) sits BEFORE the `fExec` gate (:488-490),
  applies only under BASE/WITNESS_V0, and counts only opcodes
  `> OP_16` — but it counts **unexecuted-branch opcodes too**
  (flow-insensitive). In this tree: `stepBody` check (2), before
  `fExec` is even computed.

* **C2 — disabled opcodes fail even in unexecuted branches**
  (SCR-152/153/170 + SCR-025; CVE-2010-5137): the disabled-opcode check
  (interpreter.cpp:467-482) also sits before the `fExec` gate — a dead
  `OP_CAT` still fails with DISABLED_OPCODE — and it is ORDERED AFTER
  the op-count check, so a disabled opcode that is also the 202nd
  counting opcode dies of OP_COUNT, not DISABLED_OPCODE.
  In this tree: `disabledWire` (exactly Core's 15 disabled bytes) at
  `stepBody` check (3); the tapscript composition stays faithful
  because disabled ⊆ OP_SUCCESSx and `executeWitnessScript` runs the
  `opSuccessScan` pre-pass first.

## Verdicts (details + evidence in findings-w4/Z09.md)

* C1: **CAPTURED** — fold theorems `deadNops_endif_ok` /
  `deadNops_endif_opCount` pin flow-insensitive accumulation and the
  dead-branch 202nd-op failure; byte-level `decide` examples B6-B9
  (python3-cross-checked 13/13).
* C2: **CAPTURED** — `stepBody_disabled_deadBranch` (BASE + WITNESS_V0)
  + all-15 python3 sweep + byte-level B1-B5.
* C1×C2 ordering (SCR-025): **CAPTURED** — `stepBody_count_beats_disabled`,
  `deadNops_cat_disabled` / `deadNops_cat_opCount`, byte-level B10/B11.

All theorems sorry-free; axiom footprint (scratch `axioms.out`, doctrine
rule 4) is a subset of `{propext}`.
-/

namespace Bitcoin.Proofs.Audit.Z09

open Bitcoin.Interpreter Bitcoin.Activation Bitcoin.Crypto.Seam

set_option maxRecDepth 10000
set_option maxHeartbeats 4000000

deriving instance DecidableEq for Except

/-! ## Fixtures -/

/-- Wire-op witness (O02 pattern): `.op` AST carrying wire byte `n`. -/
def opw (n : Nat) : WireOp := ⟨.op ⟨n % 256, by omega⟩, n, 1⟩

/-- Hex digit value (test-only, W09/W12 convention). -/
def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

/-- Hex decode (test-only). -/
def fromHex (s : String) : ByteArray :=
  go s.toList ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some ha, some hb => go rest (acc.push ((ha * 16 + hb).toUInt8))
        | _, _ => go rest acc

/-- `k` copies of the OP_NOP wire byte, as a hex string. -/
def nopHex (k : Nat) : String := String.intercalate "" (List.replicate k "61")

/-- No consensus flags (all false). -/
def noflags : ScriptFlags := { p2sh := false }

/-- Base-sigversion step context (flags/policy all false, stub checker). -/
def octx : Ctx :=
  ⟨noflags, default, default, SigVersion.base, ByteArray.empty, default⟩

/-- The empty machine state. -/
def st0 : State := ⟨[], [], [], 0, 0, none⟩

/-- A dead innermost branch (`OP_0 OP_IF` consumed, branch skipped). -/
def deadSt : State := { st0 with vf := [false] }

/-- Run a raw script from empty stack under a chosen sig version. -/
def runSV (sv : SigVersion) (s : String) : Except ExecError Stack :=
  evalScriptBytes 512 noflags default (fromHex s) [] default sv default

def runBase (s : String) : Except ExecError Stack := runSV .base s
def runWV0 (s : String) : Except ExecError Stack := runSV .witnessV0 s
def runTS (s : String) : Except ExecError Stack := runSV .tapscript s

/-- `MAX_OPS_PER_SCRIPT` computes to 201 (feeds `omega`). -/
theorem maxOps_201 : MAX_OPS_PER_SCRIPT = 201 := rfl

/-- `disabledWire w = true` forces `OP_16 < w` (the disabled set is a
closed 15-element list, all members above the counting threshold). -/
theorem disabledWire_gt16 {w : Nat} (h : disabledWire w = true) : 0x60 < w := by
  have h2 : w = 0x7e ∨ w = 0x7f ∨ w = 0x80 ∨ w = 0x81 ∨ w = 0x83 ∨ w = 0x84 ∨
            w = 0x85 ∨ w = 0x86 ∨ w = 0x8d ∨ w = 0x8e ∨ w = 0x95 ∨ w = 0x96 ∨
            w = 0x97 ∨ w = 0x98 ∨ w = 0x99 := by
    simpa [disabledWire] using h
  omega

/-! ## C2 — the disabled check is `fExec`-free (interpreter.cpp:467-482
precedes the :488-490 gate) -/

/-- **Dark corner (C2)**: in a dead innermost branch (`vf = [false]`),
a disabled wire opcode still fails with `disabledOpcode` — the
CVE-2010-5137 lesson — exactly as in the live branch. The budget
hypothesis only excludes the (earlier, see SCR-025) OP_COUNT outcome. -/
theorem stepBody_disabled_deadBranch (ctx : Ctx) (st : State) (w : Nat)
    (hsv : ctx.sv = SigVersion.base)
    (hdis : disabledWire w = true)
    (hlt : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT) :
    stepBody ctx (opw w) { st with vf := false :: st.vf } =
      .error .disabledOpcode := by
  have hw16 : 0x60 < w := disabledWire_gt16 hdis
  have hb : ¬(MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have := maxOps_201; simp only [this] at hlt ⊢; omega
  simp [stepBody, opw, hsv, hdis, hb, hw16]

/-- Same dark corner under WITNESS_V0 (the disabled check is
sigversion-independent; only the op-count check around it is scoped). -/
theorem stepBody_disabled_deadBranch_wv0 (ctx : Ctx) (st : State) (w : Nat)
    (hsv : ctx.sv = SigVersion.witnessV0)
    (hdis : disabledWire w = true)
    (hlt : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT) :
    stepBody ctx (opw w) { st with vf := false :: st.vf } =
      .error .disabledOpcode := by
  have hw16 : 0x60 < w := disabledWire_gt16 hdis
  have hb : ¬(MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have := maxOps_201; simp only [this] at hlt ⊢; omega
  simp [stepBody, opw, hsv, hdis, hb, hw16]

/-- The disabled verdict is execution-independent: identical for the
live state (`vf = []`) and the dead state (`vf = [false]`) — this IS
the corner. -/
theorem disabled_verdict_exec_independent (ctx : Ctx) (st : State) (w : Nat)
    (hsv : ctx.sv = SigVersion.base)
    (hdis : disabledWire w = true)
    (hlt : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT) :
    stepBody ctx (opw w) st =
      stepBody ctx (opw w) { st with vf := false :: st.vf } := by
  rw [stepBody_disabled_deadBranch ctx st w hsv hdis hlt]
  -- live side: same error, since the disabled check precedes the fExec gate
  have hlive : stepBody ctx (opw w) st = .error .disabledOpcode := by
    have hw16 : 0x60 < w := disabledWire_gt16 hdis
    have hb : ¬(MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
      have := maxOps_201; simp only [this] at hlt ⊢; omega
    simp [stepBody, opw, hsv, hdis, hb, hw16]
  rw [hlive]

/-! ## C1 — flow-insensitive opcode counting (interpreter.cpp:459-466
precedes :488-490) -/

/-- A dead OP_NOP burns exactly one budget unit and is then a no-op on
the rest of the machine state (:462 increment precedes the :493
fExec/window gate). (BASE; the W6/O02 dark-corner theorem, restated for
the fold lemmas below; WITNESS_V0 twin next.) -/
theorem stepBody_nop_burn (ctx : Ctx) (st : State)
    (hsv : ctx.sv = SigVersion.base)
    (hvf : st.vf = [false])
    (hlt : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT) :
    stepBody ctx (opw 0x61) st = .ok { st with opCount := st.opCount + 1 } := by
  have hf : st.vf.all id = false := by simp [hvf]
  have hd : disabledWire 0x61 = false := by decide
  have hb : ¬(MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have := maxOps_201; simp only [this] at hlt ⊢; omega
  simp [stepBody, opw, hsv, hf, hd, hb]

/-- Dead-NOP budget burn under WITNESS_V0 (C1 applies in segwit too). -/
theorem stepBody_nop_burn_wv0 (ctx : Ctx) (st : State)
    (hsv : ctx.sv = SigVersion.witnessV0)
    (hvf : st.vf = [false])
    (hlt : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT) :
    stepBody ctx (opw 0x61) st = .ok { st with opCount := st.opCount + 1 } := by
  have hf : st.vf.all id = false := by simp [hvf]
  have hd : disabledWire 0x61 = false := by decide
  have hb : ¬(MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have := maxOps_201; simp only [this] at hlt ⊢; omega
  simp [stepBody, opw, hsv, hf, hd, hb]

/-- The NOP step at budget exhaustion: OP_COUNT fires BEFORE the fExec
gate (so also inside dead branches). -/
theorem stepChecked_nop_trip (ctx : Ctx) (st : State)
    (hsv : ctx.sv = SigVersion.base)
    (hover : MAX_OPS_PER_SCRIPT < st.opCount + 1) :
    stepChecked ctx (opw 0x61) st = .error .opCount := by
  simp [stepChecked, stepBody, opw, hsv, hover]

/-- The NOP step within budget: burn, plus the STACK_SIZE guard which a
stack-preserving step never trips. -/
theorem stepChecked_nop_burn (ctx : Ctx) (st : State)
    (hsv : ctx.sv = SigVersion.base)
    (hvf : st.vf = [false])
    (hlt : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hsz : st.stack.length + st.alt.length ≤ MAX_STACK_SIZE) :
    stepChecked ctx (opw 0x61) st = .ok { st with opCount := st.opCount + 1 } := by
  have hg : ¬(MAX_STACK_SIZE < ({ st with opCount := st.opCount + 1 } : State).stack.length +
      ({ st with opCount := st.opCount + 1 } : State).alt.length) := by
    show ¬(MAX_STACK_SIZE < st.stack.length + st.alt.length)
    omega
  rw [stepChecked, stepBody_nop_burn ctx st hsv hvf hlt]
  simp [hg]

/-- A dead OP_CAT within budget dies of `disabledOpcode` BEFORE any
`fExec` consultation (stepChecked wrapper included). -/
theorem stepChecked_cat_disabled (ctx : Ctx) (st : State)
    (hsv : ctx.sv = SigVersion.base)
    (hlt : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT) :
    stepChecked ctx (opw 0x7e) st = .error .disabledOpcode := by
  have hdis : disabledWire 0x7e = true := by decide
  have hb : ¬(MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
    have := maxOps_201; simp only [this] at hlt ⊢; omega
  simp [stepChecked, stepBody, opw, hsv, hb, hdis]

/-- An OP_CAT that is also the 202nd counting opcode dies of
`opCount` — the count check PRECEDES the disabled check (SCR-025). -/
theorem stepChecked_cat_opCount (ctx : Ctx) (st : State)
    (hsv : ctx.sv = SigVersion.base)
    (hover : MAX_OPS_PER_SCRIPT < st.opCount + 1) :
    stepChecked ctx (opw 0x7e) st = .error .opCount := by
  simp [stepChecked, stepBody, opw, hsv, hover]

/-- General (any disabled byte): a disabled wire opcode that is ALSO the
202nd counting opcode dies of `opCount`, NOT `disabledOpcode` — the
count check runs first (:462-463 before :467-482). -/
theorem stepBody_count_beats_disabled (ctx : Ctx) (st : State) (w : Nat)
    (hsv : ctx.sv = SigVersion.base)
    (hw : 0x60 < w) (hdis : disabledWire w = true)
    (hover : MAX_OPS_PER_SCRIPT < st.opCount + 1) :
    stepBody ctx (opw w) st = .error .opCount := by
  simp [stepBody, opw, hsv, hw, hover]

/-- Composed cons-step: a dead NOP within budget consumes one fuel unit
and burns one budget unit (match already iota-resolved). -/
theorem evalFrom_nop_cons (ctx : Ctx) (st : State) (rest : List WireOp) (f : Nat)
    (hsv : ctx.sv = SigVersion.base)
    (hvf : st.vf = [false])
    (hlt : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT)
    (hsz : st.stack.length + st.alt.length ≤ MAX_STACK_SIZE) :
    evalFrom ctx (f + 1) (opw 0x61 :: rest) st =
      evalFrom ctx f rest { st with opCount := st.opCount + 1 } := by
  simp only [evalFrom, stepChecked_nop_burn ctx st hsv hvf hlt hsz]
  simp

/-- `({st with opCount := c+1}).opCount` is `c+1` by projection (feeds
`omega`, which otherwise treats the projection as an unrelated atom). -/
theorem stateOpCount_update (st : State) :
    ({ st with opCount := st.opCount + 1 } : State).opCount = st.opCount + 1 := rfl

/-! ## Dead-branch fold theorems (the corner, end-to-end at the
`evalFrom` level). All take a dead innermost state `vf = [false]` and a
list of dead OP_NOPs; BASE sigversion. -/

/-- **C1 fold, within budget**: `k` dead OP_NOPs (as `ops`) then a dead
OP_ENDIF end `.ok` with `opCount` increased by `ops.length + 1` — the
UNEXECUTED NOPs and the ENDIF all counted, exactly as if executed
(SCR-022/023; interpreter.cpp:459-466). -/
theorem deadNops_endif_ok (ctx : Ctx) (hsv : ctx.sv = SigVersion.base) :
    ∀ (f : Nat) (ops : List WireOp) (st : State),
      ops.length + 2 ≤ f →
      (∀ op ∈ ops, op = opw 0x61) →
      st.vf = [false] →
      st.stack.length + st.alt.length ≤ MAX_STACK_SIZE →
      st.opCount + ops.length + 1 ≤ MAX_OPS_PER_SCRIPT →
      evalFrom ctx f (ops ++ [opw 0x68]) st =
        .ok { st with vf := [], opCount := st.opCount + ops.length + 1 } := by
  intro f
  induction f with
  | zero =>
      intro ops st hfuel _ _ _ _
      exact absurd hfuel (by omega)
  | succ f ih =>
      intro ops st hfuel hall hvf hsz hbud
      cases ops with
      | nil =>
          -- script = [OP_ENDIF]: a DEAD ENDIF still pops the condition stack
          have hd68 : disabledWire 0x68 = false := by decide
          have hf : st.vf.all id = false := by simp [hvf]
          have hbud' : ¬(MAX_OPS_PER_SCRIPT < st.opCount + 1) := by
            have := maxOps_201; simp only [this] at hbud ⊢; omega
          cases f with
          | zero => exact absurd hfuel (by omega)
          | succ f' =>
              have hng : ¬(MAX_STACK_SIZE < List.length st.stack + List.length st.alt) := by
                omega
              simp [evalFrom, stepChecked, stepBody, stepBody.dispatchOp, opw, hsv, hvf,
                hd68, hbud', hng]
      | cons op rest =>
          have hrest : ∀ op' ∈ rest, op' = opw 0x61 := fun op' h' =>
            hall op' (List.mem_cons_of_mem _ h')
          have hlen : rest.length + 1 = (op :: rest).length := by simp
          have hpc : ({ st with opCount := st.opCount + 1 } : State).opCount
              = st.opCount + 1 := rfl
          have hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT := by
            have := maxOps_201; omega
          rw [show (op :: rest) ++ [opw 0x68] = op :: (rest ++ [opw 0x68]) from rfl,
            evalFrom_nop_cons ctx st (rest ++ [opw 0x68]) f hsv hvf hbudget hsz,
            ih rest { st with opCount := st.opCount + 1 }
              (by omega) hrest hvf hsz (by omega)]
          simp [stateOpCount_update]

/-- **C1 fold, exhausted**: same dead-branch run, but the 202nd counting
opcode (a dead NOP or the ENDIF) trips `.error .opCount` — the failure
is raised on an UNEXECUTED opcode (SCR-022/023 dark corner). -/
theorem deadNops_endif_opCount (ctx : Ctx) (hsv : ctx.sv = SigVersion.base) :
    ∀ (f : Nat) (ops : List WireOp) (st : State),
      ops.length + 2 ≤ f →
      (∀ op ∈ ops, op = opw 0x61) →
      st.vf = [false] →
      st.stack.length + st.alt.length ≤ MAX_STACK_SIZE →
      MAX_OPS_PER_SCRIPT < st.opCount + ops.length + 1 →
      evalFrom ctx f (ops ++ [opw 0x68]) st = .error .opCount := by
  intro f
  induction f with
  | zero =>
      intro ops st hfuel _ _ _ _
      exact absurd hfuel (by omega)
  | succ f ih =>
      intro ops st hfuel hall hvf hsz hover
      cases ops with
      | nil =>
          -- the dead ENDIF itself is the 202nd counting opcode
          have hover' : MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
            have := maxOps_201; simpa using hover
          simp [evalFrom, stepChecked, stepBody, opw, hsv, hover']
      | cons op rest =>
          have hrest : ∀ op' ∈ rest, op' = opw 0x61 := fun op' h' =>
            hall op' (List.mem_cons_of_mem _ h')
          have hlen : rest.length + 1 = (op :: rest).length := by simp
          have hpc : ({ st with opCount := st.opCount + 1 } : State).opCount
              = st.opCount + 1 := rfl
          rw [show (op :: rest) ++ [opw 0x68] = op :: (rest ++ [opw 0x68]) from rfl]
          by_cases hlt : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT
          · -- burn and recurse: (c+1) + rest.length + 1 > 201
            rw [evalFrom_nop_cons ctx st (rest ++ [opw 0x68]) f hsv hvf hlt hsz,
              ih rest { st with opCount := st.opCount + 1 }
                (by omega) hrest hvf hsz (by omega)]
          · -- this very (unexecuted) NOP trips OP_COUNT
            have hover' : MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
              have := maxOps_201; simp only [this] at hlt ⊢; omega
            simp [evalFrom, stepChecked_nop_trip ctx st hsv hover']

/-- **C2 fold, within budget**: `k` dead OP_NOPs then a dead OP_CAT then
OP_ENDIF — when the CAT is within budget it dies of `disabledOpcode`
(C2), never reaching the ENDIF. -/
theorem deadNops_cat_disabled (ctx : Ctx) (hsv : ctx.sv = SigVersion.base) :
    ∀ (f : Nat) (ops : List WireOp) (st : State),
      ops.length + 3 ≤ f →
      (∀ op ∈ ops, op = opw 0x61) →
      st.vf = [false] →
      st.stack.length + st.alt.length ≤ MAX_STACK_SIZE →
      st.opCount + ops.length + 1 ≤ MAX_OPS_PER_SCRIPT →
      evalFrom ctx f (ops ++ [opw 0x7e, opw 0x68]) st = .error .disabledOpcode := by
  intro f
  induction f with
  | zero =>
      intro ops st hfuel _ _ _ _
      exact absurd hfuel (by omega)
  | succ f ih =>
      intro ops st hfuel hall hvf hsz hbud
      cases ops with
      | nil =>
          have hbud' : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT := by
            have := maxOps_201; simpa using hbud
          simp [evalFrom, stepChecked_cat_disabled ctx st hsv hbud']
      | cons op rest =>
          have hrest : ∀ op' ∈ rest, op' = opw 0x61 := fun op' h' =>
            hall op' (List.mem_cons_of_mem _ h')
          have hlen : rest.length + 1 = (op :: rest).length := by simp
          have hpc : ({ st with opCount := st.opCount + 1 } : State).opCount
              = st.opCount + 1 := rfl
          have hbudget : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT := by
            have := maxOps_201; omega
          rw [show (op :: rest) ++ [opw 0x7e, opw 0x68]
                = op :: (rest ++ [opw 0x7e, opw 0x68]) from rfl,
            evalFrom_nop_cons ctx st (rest ++ [opw 0x7e, opw 0x68]) f hsv hvf hbudget hsz,
            ih rest { st with opCount := st.opCount + 1 }
              (by omega) hrest hvf hsz (by omega)]

/-- **C2×C1 fold, exhausted (SCR-025 decisive)**: when the dead OP_CAT
is the 202nd counting opcode (or an earlier dead NOP already crossed
the budget), the verdict is `.error .opCount` — OP_COUNT beats
DISABLED_OPCODE even though the disabled check would also fire. -/
theorem deadNops_cat_opCount (ctx : Ctx) (hsv : ctx.sv = SigVersion.base) :
    ∀ (f : Nat) (ops : List WireOp) (st : State),
      ops.length + 3 ≤ f →
      (∀ op ∈ ops, op = opw 0x61) →
      st.vf = [false] →
      st.stack.length + st.alt.length ≤ MAX_STACK_SIZE →
      MAX_OPS_PER_SCRIPT < st.opCount + ops.length + 1 →
      evalFrom ctx f (ops ++ [opw 0x7e, opw 0x68]) st = .error .opCount := by
  intro f
  induction f with
  | zero =>
      intro ops st hfuel _ _ _ _
      exact absurd hfuel (by omega)
  | succ f ih =>
      intro ops st hfuel hall hvf hsz hover
      cases ops with
      | nil =>
          -- the dead CAT is the 202nd counting opcode: OP_COUNT wins
          have hover' : MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
            have := maxOps_201; simpa using hover
          simp [evalFrom, stepChecked_cat_opCount ctx st hsv hover']
      | cons op rest =>
          have hrest : ∀ op' ∈ rest, op' = opw 0x61 := fun op' h' =>
            hall op' (List.mem_cons_of_mem _ h')
          have hlen : rest.length + 1 = (op :: rest).length := by simp
          have hpc : ({ st with opCount := st.opCount + 1 } : State).opCount
              = st.opCount + 1 := rfl
          rw [show (op :: rest) ++ [opw 0x7e, opw 0x68]
                = op :: (rest ++ [opw 0x7e, opw 0x68]) from rfl]
          by_cases hlt : st.opCount + 1 ≤ MAX_OPS_PER_SCRIPT
          · rw [evalFrom_nop_cons ctx st (rest ++ [opw 0x7e, opw 0x68]) f hsv hvf hlt hsz,
              ih rest { st with opCount := st.opCount + 1 }
                (by omega) hrest hvf hsz (by omega)]
          · have hover' : MAX_OPS_PER_SCRIPT < st.opCount + 1 := by
              have := maxOps_201; simp only [this] at hlt ⊢; omega
            simp [evalFrom, stepChecked_nop_trip ctx st hsv hover']

/-! ## Python3-cross-checked byte-level verdicts (scratch/Z09/xcheck.py,
13/13 PASS against interpreter.cpp:448-500 @ c50817f) -/

-- B1 (xcheck E1) — dead OP_CAT: DISABLED_OPCODE even unexecuted (C2, BASE)
example : runBase "00637e68" = .error .disabledOpcode := by decide

-- B2 (xcheck E2) — same under WITNESS_V0 (C2 holds in segwit too)
example : runWV0 "00637e68" = .error .disabledOpcode := by decide

-- B3 (xcheck E4) — contrast: dead OP_RESERVED (0x50) PASSES (SCR-066):
--    only the 15 DISABLED bytes fail unexecuted; reserved fail executed-only
example : runBase "00635068" = .ok [] := by decide

-- B4 (xcheck E5) — dead OP_VERIF (0x65, in the IF..ENDIF window) still
--    hits default: → BAD_OPCODE unexecuted (SCR-065, O02-pinned too)
example : runBase "00636568" = .error .badOpcode := by decide

-- B5 (xcheck E6) — executed OP_CAT: the CVE-2010-5137 headline
example : runBase "7e" = .error .disabledOpcode := by decide

-- B6 (xcheck E7) — C1 e2e: 201 dead NOPs (+IF, +ENDIF = 202 counting ops
--    total): OP_COUNT raised on an UNEXECUTED opcode
example : runBase ("0063" ++ nopHex 201 ++ "68") = .error .opCount := by decide

-- B7 (xcheck E8) — C1 boundary e2e: 199 dead NOPs (+IF+ENDIF = 201
--    counting ops): exactly at budget, script is fine
example : runBase ("0063" ++ nopHex 199 ++ "68") = .ok [] := by decide

-- B8 (xcheck E9) — C1 e2e under WITNESS_V0 (budget applies there too)
example : runWV0 ("0063" ++ nopHex 201 ++ "68") = .error .opCount := by decide

-- B9 (xcheck E11) — tapscript contrast: no 201-op budget at all, the same
--    201-dead-NOP script validates (validation-weight regime instead)
example : runTS ("0063" ++ nopHex 201 ++ "68") = .ok [] := by decide

-- B10 (xcheck E12) — C1×C2 e2e: 200 dead NOPs then dead OP_CAT as the
--    202nd counting op → OP_COUNT, NOT DISABLED_OPCODE (SCR-025 order)
example : runBase ("0063" ++ nopHex 200 ++ "7e68") = .error .opCount := by decide

-- B11 (xcheck E13) — same layout, CAT as the 2nd counting op (within
--    budget) → DISABLED_OPCODE wins
example : runBase ("0063" ++ "7e" ++ nopHex 200 ++ "68") = .error .disabledOpcode := by decide

/-! ## Single-step cross-checks (stepBody level, kernel decide) -/

-- dead 0x7e (op #1, budget fine): DISABLED_OPCODE
example : stepBody octx (opw 0x7e) deadSt = .error .disabledOpcode := by decide

-- dead 202nd counting NOP: OP_COUNT, not skipped, not disabled
example : stepBody octx (opw 0x61) { deadSt with opCount := 201 } =
  .error .opCount := by decide

-- dead NOP within budget: skipped BUT budget burned (O02's dark corner)
example : stepBody octx (opw 0x61) deadSt =
  .ok { deadSt with opCount := 1 } := by decide

-- the general SCR-025 theorem instance at the byte level: dead CAT as the
-- 202nd counting op dies of OP_COUNT (not DISABLED_OPCODE)
example : stepBody octx (opw 0x7e) { deadSt with opCount := 201 } =
  .error .opCount := by decide

end Bitcoin.Proofs.Audit.Z09
