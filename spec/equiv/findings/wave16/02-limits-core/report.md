# Wave 16 — `02-limits-core` report

**Task:** bounded C-vs-L cells for the size / opcount / stack limits.
**Branch:** `wave16/02-limits-core`, cut from PR head `805c804`.
**Pin:** Core `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`.
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`.
**Scope written:** `spec/equiv/cells/limits/**` and this report only.
**Ledger/results/shared files:** untouched; the orchestrator runs the updater.

## Result

11 assigned rows: **10 now both-tool green with full row coverage**, **1
tool-green but partial** (SCR-021), **0 remaining gap/seam**, **0 tool
blockers**.

`update_ledger.py --check` (read-only) reports: `cells scanned: 23 (valid
23, malformed 0)`, `changes: 11`, and derives `both-green` for SCR-018,
019, 020, 022, 023, 024, 025, 029, 030, 031; SCR-021 stays `gap` with the
auto partial-coverage note. No cell record was hand-promoted.

| SCR | Cell | Coverage | Alive2 | SAW |
|---|---|---|---|---|
| SCR-018 | `cells/limits/C-L-script-size` | full | green | green |
| SCR-019 | `cells/limits/C-L-script-size` | full | green | green |
| SCR-020 | `cells/limits/C-L-push-size` | full | green | green |
| SCR-021 | `cells/limits/C-L-witness-push-size` | **partial** | green | green |
| SCR-022 | `cells/limits/C-L-opcount` | full | green | green |
| SCR-023 | `cells/limits/C-L-opcount` | full | green | green |
| SCR-024 | `cells/limits/C-L-opcount` | full | green | green |
| SCR-025 | `cells/limits/C-L-opcount` | full | green | green |
| SCR-029 | `cells/limits/C-L-stack-limit` | full | green | green |
| SCR-030 | `cells/limits/C-L-stack-limit` | full | green | green |
| SCR-031 | `cells/limits/C-L-tapscript-precheck` | full | green | green |

Every cell has a real `alive2/result.txt`, `saw/result.txt`, and a
`certificate.sha256` that verifies with `sha256sum -c` from the repo root.

## Row-by-row disposition

### SCR-018 / SCR-019 — `LIMITS/C-L-script-size` (full, both-green)

The row is exactly Core's EvalScript entry guard
`(sigversion == BASE || WITNESS_V0) && script.size() > MAX_SCRIPT_SIZE`
(`interpreter.cpp:438-440`; `script.h:41`) and its TAPSCRIPT exclusion. The
cell is symbolic over **all 2^64 script lengths** and all three executable
sigversions:

- BASE/WITNESS_V0, length 10001 → `SCRIPT_SIZE`; length 10000 → admitted.
- TAPSCRIPT, every length (including > 10000) → admitted (payload carries the
  length), which is SCR-019.
- The guard is modelled once, at entry, before the opcode loop
  (`interpreter.cpp:449`), which is the "checked once" part of SCR-018.

L source: `Defs.lean:1163-1166` (`evalScriptBytes`), structurally identical to
`twin/runtime.inc:594-597`.

### SCR-020 — `LIMITS/C-L-push-size` (full, both-green)

Symbolic over all 2^16 push-value lengths, the three decoded instruction
classes (byte push / numeric push / other opcode), and both `fExec` values.
`dlen = 521` returns `PUSH_SIZE` with `fExec = 0` as well as `1`, which is the
"even unexecuted" claim. The payload is the post-check push depth, so the
executed/unexecuted push effect is observable too.

L source: `Defs.lean:817-826` (`stepBody` `sizeOk`, computed from `op.ast`
alone), matching `twin/runtime.inc:603-606`.

### SCR-022 / SCR-023 / SCR-024 / SCR-025 — `LIMITS/C-L-opcount` (full, both-green)

One `stepBody` step, symbolic over **all 256 opcode bytes**, incoming
`nOpCount ∈ [0,202]`, both `fExec` values, and all three sigversions:

- SCR-022: `wire > 0x60` charges the budget in BASE/WITNESS_V0; the
  201→202 transition returns `OP_COUNT`. OP_NOP (0x61) is in the symbolic
  domain. The `OP_COUNT` return is before the disabled table and before the
  dispatch entry.
- SCR-023: `fExec` is a free input, never read before the charge/check; the
  payload exposes both the charged count and `fExec`, so flow-insensitivity
  is proved, not assumed.
- SCR-024: all of 0x00-0x60 is proved exempt, every 0x61-0xff byte charged.
- SCR-025: at `nOpCount = 201` with any disabled wire, the result is
  `OP_COUNT` (7), not `DISABLED_OPCODE` (17), for every disabled wire.

L source: `Defs.lean:826-833` (`stepBody` order) + `:455-457`
(`disabledWire`), matching `twin/runtime.inc:607-614`. The disabled set is
written independently in each leg (Core switch list vs Lean list).

### SCR-029 / SCR-030 — `LIMITS/C-L-stack-limit` (full, both-green)

Symbolic over every bounded `(stack.size(), altstack.size())` pair in
`[0,2000]^2`; sum 1000 admits, 1001 rejects; the payload is the exact sum, so
the altstack's contribution (SCR-030) is observable. This is `stepChecked`'s
terminal guard, which every executed opcode passes through ("checked per
opcode").

L source: `Defs.lean:1131-1136`, matching `twin/runtime.inc:642-643`.

### SCR-031 — `LIMITS/C-L-tapscript-precheck` (full, both-green)

Symbolic over the bounded initial main depth, sigversion, the abstract
OP_SUCCESSx outcome, the DISCOURAGE_OP_SUCCESS bit, and **every**
`inner_err ∈ [0,55]` standing for EvalScript's opaque outcome. For TAPSCRIPT
with `depth > 1000` and no OP_SUCCESSx, the result is `STACK_SIZE` for every
`inner_err`, which proves the guard cannot be preempted by anything EvalScript
would do ("checked before EvalScript"). The altstack is empty at this point,
so only main depth is an input.

L source: `Defs.lean:1207-1239` (`executeWitnessScript`). The generated twin
has no witness engine at the pin (`runtime.inc` returns
`TWIN_INVALID_UNSUPPORTED` on that path), so the Lean definition is the L
source of record; this is stated in the cell's `trust_note`.

### SCR-021 — `LIMITS/C-L-witness-push-size` (partial, both-green)

Proved: the witness item-size predicate `any item.size() > 520 ⇒ PUSH_SIZE`
(represented exactly by `max_item > 520`), for base/v0 and for
tapscript-without-OP_SUCCESSx, in the correct order after the initial-stack
guard, plus the BIP342 exemption ordering (OP_SUCCESSx success before the item
loop; DISCOURAGE_OP_SUCCESS returns 36).

**Exact missing feature (why partial):** `opSuccessScan exec` is a real
per-opcode scan over the tapscript bytes with an early success return
(`interpreter.cpp:1848-1862`). The cell takes its outcome as a Boolean input;
deciding the scan over symbolic script bytes requires the decode loop and is
the same feature that blocks SCR-153. So the "tapscript containing
OP_SUCCESSx" branch is modelled at its outcome, not by scanning bytes. No
tool blocker — both tools ingested the abstracted model.

## Validation

Run from the worktree root:

```sh
for c in C-L-script-size C-L-push-size C-L-opcount C-L-stack-limit \
         C-L-tapscript-precheck C-L-witness-push-size; do
  bash spec/equiv/cells/limits/$c/alive2/run.sh
  bash spec/equiv/cells/limits/$c/saw/run.sh
  sha256sum -c spec/equiv/cells/limits/$c/alive2/certificate.sha256
  sha256sum -c spec/equiv/cells/limits/$c/saw/certificate.sha256
done
```

Observed: all 12 cell-leg runs `rc=0`; every `alive2/result.txt` has
`Transformation seems to be correct` + `1 correct transformations` + `0
incorrect transformations` + `0 Alive2 errors` + `STATUS=alive2-green`; every
`saw/result.txt` has two `Proof succeeded!` and `STATUS=saw-green`; all 12
certificates verify.

Read-only ledger check:

```sh
python3 spec/equiv/results/scripts/update_ledger.py --check
```

→ `cells scanned: 23 (valid 23, malformed 0)`; `changes: 11`; the ten full
rows derive `both-green`; SCR-021 derives `gap` with the partial-coverage
note.

Non-vacuity spot check (not committed): changing the L opcount comparison from
`MAX_OPS_PER_SCRIPT < opCount_next` to `<=` made SAW report
`Proof failed.` / `STATUS=saw-not-green` while the C leg still passed. The
mutant was reverted and the cell re-run green.

## Honest scope / abstractions

- These are bounded **predicate/step** cells, not whole-`EvalScript` proofs.
  Each cell's `spec.md` names exactly what it abstracts: decoded instruction
  for SCR-020, no GetOp/dispatch for SCR-022..025, one step guard for
  SCR-029/030, opaque EvalScript for SCR-031, and abstract `opSuccessScan`
  for SCR-021.
- C legs are line-cited source-excerpt slices, not the whole Core translation
  unit. L legs are reviewed transliterations of the Lean definitions /
  structural twin code; there are no per-opcode twin handlers for these
  limits. Both facts are recorded in every `trust_note`.
- Alive2 reports `syntactically equal` for four cells because the two
  straight-line predicates compile to the same IR; the independent check for
  those cells is the SAW Cryptol predicate. That is recorded rather than
  hidden.
- No Core patch, no consensus-semantics change, no crypto/hash claim.
- `make equiv` was intentionally not run (brief: run the cell scripts, not the
  whole suite). `make gate-ir-pin`/ledger updates are the orchestrator's job.

## Remaining blockers

- SCR-021 only: symbolic `opSuccessScan` over tapscript bytes (parser loop +
  `IsOpSuccess` set + early success). This is shared with SCR-153; a bounded
  one-byte script would not generalize and was not used to fake coverage.
- No tool/infrastructure blocker: Alive2 v20.0 and SAW 1.6 both ingested every
  module.
