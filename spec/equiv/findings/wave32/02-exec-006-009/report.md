# Wave 32 — task 02-exec-006-009 (exec-verify SCR-006..009)

**Family:** exec-verify
**Assigned rows:** SCR-006, SCR-007, SCR-008, SCR-009
**Worktree:** `/tmp/opencode/wave32/02-exec-006-009`, branch `wave32/02-exec-006-009`
**Base:** PR #29 head `805c8042f92d3bed909ca40219a4d21fc9150cc1`
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
**Tools:** Alive2 v20 (LLVM 20.1.2), SAW 1.6 (`68eed5f`), z3, clang++-20, Lean 4.35.0 for the probe.

No shared ledger, generated results, contract, pins, Lean sources or existing
cells were edited.  Nothing was pushed.

---

## 1. Row table

| SCR | status | cell | what was proved | what remains | exact blocker |
|---|---|---|---|---|---|
| **SCR-006** | **full**, both tools green | `exec-verify/C-L-w32-p2sh-pushonly` | Symbolic over `(n_ops, w0, w1, w2, p2sh)`: the P2SH arm's `IsPushOnly` gate returns SIG_PUSHONLY (26) for every decoded scriptSig with an opcode `> 0x60`, passes every push-only scriptSig (including the `0x60`/`0x61` boundary), and is not entered with the P2SH flag clear. C and L agree on all values. | script decoding (GetScriptOp) is a declared abstraction; the malformed-tail error kind is F-DIV-001 and is excluded. Redeem-script execution after the gate is abstracted, and is not part of this row. | none for the row's branches |
| **SCR-007** | **full**, both tools green | `exec-verify/C-L-w32-p2sh-stackcopy` | Symbolic over two *independent* stacks (post-scriptSig and post-scriptPubKey, depth 0..2, symbolic bytes) and the P2SH bit: the redeem byte and the stack handed to `EvalScript(pubKey2, ...)` at :2080 are derived from the **post-scriptSig** snapshot for every input, never from the post-spk stack; the flag-conditional snapshot is unobservable when the arm is not entered. | the two EvalScript results are cell inputs (E5 residual B3); redeem-script execution at :2080 is abstracted to success. | none for the snapshot/restore relation |
| **SCR-008** | **partial** (flag/policy face green; witness-implicit face blocked) | `exec-verify/C-L-w32-cleanstack` (+ `divergence/`) | Symbolic over `(final_len, cs)`: CLEANSTACK fails exactly when the flag/policy bit is set and the cleanstack-relevant length is not 1; C and L agree on the flag and `pol.` faces. | the `implicit in witness` face: Core resizes the stack to 1 after a successful witness program (:2057 bare, :2102 P2SH-wrapped), so the check cannot fire there. The Lean model reproduces the bare resize but not the P2SH-wrapped one; a concrete Lean evaluation returns CLEANSTACK where Core succeeds. See finding F-DIV-W32-01. | Lean `verifyScriptFull` `finalLen` (Defs.lean:1395-1418) tests `isWitnessProgram spk` instead of the P2SH redeem script, and the model never resizes for the wrapped arm. Fix: carry the post-witness stack length (or a `hadWitness`/resize flag) out of `p2shInner` and set `finalLen = 1` for both witness arms; smallest next experiment: evaluate `verifyScriptFull` on a P2SH-P2WPKH tape with `pol.cleanstack = true` after the change (the probe in `divergence/lean-probe.lean` is that experiment, currently red). |
| **SCR-009** | **full**, both tools green | `exec-verify/C-L-w32-flag-combo` | Symbolic over the three relevant flag bits: the contract domain answer (0 admissible / 2 rejected) equals Lean `flagsComboOk` on all eight combinations, i.e. CLEANSTACK ⇒ P2SH ∧ WITNESS (and, as carried by both models, WITNESS ⇒ P2SH). | Core's release-build behaviour on an assert violation (the contract's total rule replaces it); the high-bit mask rule (tape.md §5.5) is not this row. The WITNESS ⇒ P2SH arm is SCR-014's row and is not claimed here. | none for the row |

Summary: **3 full rows (SCR-006, SCR-007, SCR-009), 1 partial row
(SCR-008), 0 rows left with no cell.**  One new model-divergence finding.

---

## 2. Cells

All four cells live under `spec/equiv/cells/exec-verify/` and share the
harness `spec/equiv/cells/_tools/w32-exec-006-009/`:

```
x_common.h     stack + packing helpers (head = top, depth <= 2)
c_cell.cpp     line-cited Core/shim excerpts (interpreter.cpp, script.cpp, shims/core/entry.cpp)
l_cell.cpp     reviewed transliterations of Lean p2shInner / verifyScriptFull / flagsComboOk
build_leaf.sh  clang++-20 -O1, llvm-extract per manifest function
run_alive2.sh  alive-tv per function, raw result + certificate
run_saw.sh     SAW per function and per leg against the cell's Cryptol spec, raw result + certificate
```

Each cell has `spec.md` (front-matter with contract hash, pin, legs,
precondition, postcondition, direction, `scr_rows`, `scr_row_coverage`,
`patches`, citations, trust note), `notes.md`, `manifest.txt`, `alive2/`,
`saw/` with `cell.cry` and `solver.txt` (z3).  Cell 3 additionally has
`divergence/` with a `red`-mode probe pair (Alive2 + SAW), the Lean probe and
its transcript.

Cell paths:

- `spec/equiv/cells/exec-verify/C-L-w32-p2sh-pushonly`
- `spec/equiv/cells/exec-verify/C-L-w32-p2sh-stackcopy`
- `spec/equiv/cells/exec-verify/C-L-w32-cleanstack`
- `spec/equiv/cells/exec-verify/C-L-w32-cleanstack/divergence`
- `spec/equiv/cells/exec-verify/C-L-w32-flag-combo`

---

## 3. Exact commands and raw outcomes

Run from the repository root (this worktree):

```sh
spec/equiv/cells/exec-verify/C-L-w32-p2sh-pushonly/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-p2sh-pushonly/saw/run.sh
spec/equiv/cells/exec-verify/C-L-w32-p2sh-stackcopy/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-p2sh-stackcopy/saw/run.sh
spec/equiv/cells/exec-verify/C-L-w32-cleanstack/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-cleanstack/saw/run.sh
spec/equiv/cells/exec-verify/C-L-w32-flag-combo/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-flag-combo/saw/run.sh
spec/equiv/cells/exec-verify/C-L-w32-cleanstack/divergence/alive2/run.sh   # expected red
spec/equiv/cells/exec-verify/C-L-w32-cleanstack/divergence/saw/run.sh      # expected red
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-*/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-*/saw/certificate.sha256
sha256sum -c spec/equiv/cells/exec-verify/C-L-w32-cleanstack/divergence/*/certificate.sha256
```

Raw outcomes (full text in each `result.txt`):

| cell | Alive2 | SAW |
|---|---|---|
| p2sh-pushonly | `1 correct transformations, 0 incorrect, 0 failed-to-prove, 0 errors` / `STATUS=alive2-green` | `Proof succeeded! cell_p2sh_pushonly_gate` x2 (C, L) / `STATUS=saw-green` |
| p2sh-stackcopy | `1 correct / 0 incorrect / 0 failed-to-prove / 0 errors` / `STATUS=alive2-green` | `Proof succeeded! cell_p2sh_stackcopy` x2 / `STATUS=saw-green` |
| cleanstack (flag face) | `1 correct / 0 incorrect / 0 failed-to-prove / 0 errors` / `STATUS=alive2-green` | `Proof succeeded! cell_cleanstack_flag` x2 / `STATUS=saw-green` |
| flag-combo | `1 correct / 0 incorrect / 0 failed-to-prove / 0 errors` / `STATUS=alive2-green` | `Proof succeeded! cell_flag_combo_admissible` x2 / `STATUS=saw-green` |
| cleanstack divergence | `0 correct / 1 incorrect`, source `1` (ok) vs target `120` (CLEANSTACK) / `STATUS=alive2-counterexample-as-expected` | C module `Proof succeeded!`; L module `Proof failed.` / `STATUS=saw-proof-failed-as-expected` |

All ten certificates verify with `sha256sum -c --quiet` from the repository
root (10/10 OK).

Tooling notes (recorded, not hidden):

- The stackcopy cell is seven symbolic 64-bit arguments; `abc` did not
  discharge it inside a 300 s timeout, z3 proves it in ≈2 s.  All four cells
  therefore record `solver = z3` in `saw/solver.txt` and in `saw/result.txt`.
  The abc timeout is not cited as a result.
- The first SAW spec revision for p2sh-pushonly clamped the full 64-bit
  `n_ops` where the C leg masks to a byte first; SAW returned a
  counterexample, the spec was corrected to mirror `n_ops & 0xff`, and the
  cell was re-run green.  The failed run is not part of the certificate.

---

## 4. Finding F-DIV-W32-01 (proposed global id F-DIV-003)

```
F-DIV-W32-01: Lean verifyScriptFull rejects P2SH-wrapped witness spends under CLEANSTACK
  legs: C | L
  cell: spec/equiv/cells/exec-verify/C-L-w32-cleanstack (divergence/)
  symptom: Core returns success; the Lean model returns .fail .cleanstack.
  evidence:
    - Core source at the pin:
        interpreter.cpp:2100-2102  // Bypass the cleanstack check ...
                                   stack.resize(1);      // P2SH-wrapped arm
        interpreter.cpp:2055-2057  same resize for the bare arm
        interpreter.cpp:2110-2118  terminal CLEANSTACK check (sees size 1)
    - Lean source: Defs.lean:1395-1418
        finalLen := if flags.witness ∧ (isWitnessProgram spk).isSome then 1
                    else <re-evaluate the redeem script on stackCopy; length>
      `spk` is the P2SH scriptPubKey, so the condition is false in the wrapped
      arm and the model keeps the inner length (2 for a v0 program: OP_0 and
      the 20-byte program are pushed).
    - concrete Lean evaluation (divergence/lean-probe.lean, transcript in
      divergence/lean-eval.txt):
        cd spec/core && lake env lean \
          ../equiv/cells/exec-verify/C-L-w32-cleanstack/divergence/lean-probe.lean
        Bitcoin.Interpreter.VerifyOutcome.fail (Bitcoin.Interpreter.ExecError.cleanstack)
    - Alive2 counterexample (divergence/alive2/result.txt): at
      (final_len=2, cs=1, kind=2 P2SH-wrapped) the C excerpt returns 1 (ok)
      and the Lean rule returns 120 (CLEANSTACK).
    - SAW (divergence/saw/result.txt): C module proves the Core
      postcondition; L module proof fails.
  disposition: open (model divergence, not a tool gap)
  notes: fix carries the post-witness stack length out of p2shInner (or a
    `hadWitness`/resize flag) and sets finalLen = 1 for both witness arms;
    the row's core_ref is only :2110-2118, so an alternative disposition is
    to re-scope SCR-008 to the flag/policy faces and track the witness
    implicit cleanstack on SCR-138/SCR-183.  Not promoted to the shared
    findings index; the orchestrator owns the global id.
```

Scope note: Core was **not executed** on the tape — there is no Core build in
this worktree.  The C side of the probe is the line-cited excerpt used by
Alive2/SAW; the success claim for Core is read off :2055-2057 and
:2100-2102.  The Lean side is executed (Lean 4.35.0, `lake env lean`).

---

## 5. What was not done, and why

- **No whole-`VerifyScript` proof.**  The EvalScript loop / heap / exception
  edges remain the E5 residual (B1-B6); these cells take EvalScript results
  as inputs and say so in every `spec.md`.
- **No witness-program execution.**  `VerifyWitnessProgram` /
  `ExecuteWitnessScript` are not modelled; SCR-008's witness face is
  consequently partial.
- **No ledger / generated-result edits.**  `spec/db/equiv-cells.yaml`,
  `results/**`, `findings/coverage/F-E6-GAPS.md`, `cells/INDEX.md` are
  untouched.  The orchestrator should regenerate them; the intended ledger
  entries are: SCR-006 → both-green, `C-L-w32-p2sh-pushonly`; SCR-007 →
  both-green, `C-L-w32-p2sh-stackcopy`; SCR-008 → partial, a
  `C-L-w32-cleanstack` citation with the gap note from F-DIV-W32-01; SCR-009
  → both-green, `C-L-w32-flag-combo`.
- **No mutation runs.**  Each cell's `spec.md` records a proposed mutation
  (the analogue of the E1 gate discipline) that the observable is designed to
  catch; none was executed in this task.

---

## 6. Files added

```
spec/equiv/cells/_tools/w32-exec-006-009/{x_common.h, c_cell.cpp, l_cell.cpp, build_leaf.sh, run_alive2.sh, run_saw.sh}
spec/equiv/cells/exec-verify/C-L-w32-p2sh-pushonly/{spec.md,notes.md,manifest.txt,alive2/*,saw/*}
spec/equiv/cells/exec-verify/C-L-w32-p2sh-stackcopy/{spec.md,notes.md,manifest.txt,alive2/*,saw/*}
spec/equiv/cells/exec-verify/C-L-w32-cleanstack/{spec.md,notes.md,manifest.txt,alive2/*,saw/*,divergence/*}
spec/equiv/cells/exec-verify/C-L-w32-flag-combo/{spec.md,notes.md,manifest.txt,alive2/*,saw/*}
spec/equiv/findings/wave32/02-exec-006-009/report.md
```

`build/` directories are regenerated by the runners and are matched by the
existing `spec/equiv/.gitignore` `build/` rule, so they are not committed —
the same convention as the existing `e1-*` / `e2-*` cells, whose certificates
also hash generated IR.  The committed artifacts are `result.txt` +
`certificate.sha256`; because the certificates include the generated
`build/*.ll`/`*.bc`, `sha256sum -c` is meaningful after re-running the cell's
`alive2/run.sh` and `saw/run.sh` (which regenerate `build/` deterministically
in this worktree).  The verification reported in §3 was done after the final
re-run, with all ten certificates returning `OK`.
