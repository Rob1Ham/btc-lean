# REDTEAM report — adversarial validation design (E0)

**Status:** design complete; **eight mutation runs (seven distinct IDs) have now
been executed and killed** (see §9 addendum). The original design text below
is retained.
**Date:** 2026-10-19. **Owner:** REDTEAM.
**Companion artifacts:** `cells/_redteam/PROTOCOL.md`,
`cells/_redteam/MUTATIONS.md`, `cells/_redteam/mutate.py`,
`findings/redteam/README.md`.

---

## 1. Summary

The campaign's claim is conditional and evidence-tier. The main way it can go
wrong is not a solver bug; it is a **false green**: a cell that proves the wrong
function, a shim that decides instead of marshalling, a corpus that avoids the
bug, a certificate replayed from another run, three legs agreeing because they
share a harness, or a hard cell quietly marked "unjudged" and counted as
coverage.

This design installs five controls before any gate cell is green:

1. **Mutation testing** with a required set per milestone, paired twin/Core-copy
   sites, a pre-declared kill witness, and a strict survivor/equivalence
   policy. A green family without a passed mutation test is not accepted.
2. **Harness attacks** against shims, corpus, pins, certificates/logs, contract
   ambiguity, and error-enum mapping, each with a detection method and a
   canary.
3. **Differential-oracle discipline**: the three-leg run is a test, never a
   proof; independence requirements and sensitivity canaries prevent
   correlated agreement from being cited as evidence.
4. **Unjudged-cell inflation controls**: only `GREEN-BOTH`/`GREEN-ONE` count;
   gaps need a named blocking feature and a tool log; timeouts are not
   inapplicability.
5. **Per-milestone sign-off (E0–E6)** with a record format, independence rules,
   refusal triggers, and re-pin invalidation.

Deliverables:

| Artifact | State |
|---|---|
| `cells/_redteam/PROTOCOL.md` | written, v0.1 |
| `cells/_redteam/MUTATIONS.md` | written, 32 planned mutants (E1–E4) |
| `cells/_redteam/mutate.py` | 32 catalogue entries; `M-E1-001`/`M-E1-002` twin anchors calibrated, rest **uncalibrated**; apply/revert/`--list` implemented |
| `findings/redteam/README.md` | written; finding format, dispositions, acceptance rule |
| `findings/redteam/redteam-report.md` | this file |

**Execution status:** eight mutant runs against campaign sources (seven
distinct IDs: `M-E1-001` twin and core-slice, `M-E1-002`, `M-E1-006`,
`M-E1-008`, `M-E2-010`, `M-E3-008`, `M-E4-004`) were executed and killed by
both Alive2 and SAW; see §9. The driver's apply/revert path was also exercised
on a synthetic `/tmp` fixture, validating hashing, diff capture, record
writing, and byte-identical reversion.

---

## 2. Protocol highlights

- **B-gate (B0–B8):** a mutation verdict is invalid unless the cell was green
  on unmutated sources, with unchanged spec/corpus/pins, a clean tree, and a
  pre-declared witness.
- **Mutant sites:** `model` (Lean input or `twin/ops_ir.py`), `twin` (generated
  `twin/build/twin.cpp`), `core-copy` (patched, test-only Core at the pin). A
  pair is required to catch asymmetric cells. A Core-copy mutant is never a
  `patches/` entry.
- **Kill criteria:** a named expected cell must fail on verdict, error kind, or
  postcondition; build errors, crashes, and timeouts are `INVALID`, not kills.
- **Survivor policy:** default is "cell too weak." Equivalence is an exception
  with a written argument, a bounded/solver check, and a second reviewer.
- **Witness rule:** if no concrete witness reaches the mutated behavior, the
  mutant is outside the cell domain — a coverage finding, not an equivalent
  mutant.
- **Observability rule:** a "did not crash" cell cannot kill a semantic mutant;
  each family needs at least one stack/error-observing postcondition.
- **Harness canaries:** shim-smuggle, pin-drift, corpus-poison, and
  certificate-replay attacks must be caught before sign-off.
- **Gap discipline:** a closed list of blocking IR features; no "SAW is slow"
  or "hard" gaps; `UNJUDGED` never counts as coverage.
- **Sign-off:** E0–E6 checklists, independence statement, refusal triggers,
  and re-pin invalidation.

The 183-row SCR census is consistent with `README.md`: `spec/db/rules.yaml`
contains 183 `SCR-*` rows (726 rows total), so the coverage oracle is
mechanically countable.

---

## 3. Recommended first mutation for E1

**Mutant:** `M-E1-001` — make `OP_SWAP` a no-op (do not exchange the top two
stack items).

**Why this one first:**

- it is a single, local, textual edit with no flag, crypto, locktime, or
  witness dependency;
- it is expressible in both Alive2 and SAW, so a failure is attributable to the
  cell, not to a tool limitation;
- it is verdict-observable with a tiny script, so it does not depend on a
  sophisticated corpus;
- it is trivially revertible and cheap for a second operator to reproduce;
- it catches a class the campaign is likely to miss: a cell that proves stack
  *values* but never observes stack *order*.

**Cell:** `cells/e1-stack/swap-order` must be green first, with both tools
attempted and at least one leaf postcondition that observes the stack.

**Witness script (hex):**

```
51 52 7c 51 87
OP_1 OP_2 OP_SWAP OP_1 OP_EQUAL
```

- Baseline: stack after `OP_1 OP_2` is `[1, 2]`; `OP_SWAP` gives `[2, 1]`;
  push `OP_1`; `OP_EQUAL` compares `1` and `1` → true → script passes.
- Mutant: `OP_SWAP` is a no-op, stack `[1, 2]`; push `OP_1`; `OP_EQUAL`
  compares `2` and `1` → false → script fails.
- The expected failing cell is `cells/e1-stack/swap-order`; the observed
  difference is verdict `1 → 0` (or the leaf stack postcondition, if the cell
  is expressed as a function).

**Procedure:**

1. Freeze the cell spec, corpus hash, and `PINS.lock`.
2. Run the B-gate; record the baseline evidence bundle.
3. Calibrate the `twin` and `core-copy` variants in `mutate.py` with exact
   anchors (do not guess). `--dry-run` first. For the generator site, apply the
   mutation to `twin/ops_ir.py`; for the generated site, apply it to
   `twin/build/twin.cpp` and record the `gen.py --check` drift.
4. Regenerate with `twin/gen.py` if the generator site was mutated, then
   rebuild from scratch with the pinned clang; record the new IR sha256.
5. Run both directions and both tools. The expected cell must fail; baseline
   cells outside the expected list must stay green (over-broad mutation check).
6. Record the witness, logs, and classification; revert; rebuild; confirm the
   baseline is green.
7. Repeat at the `core-copy` site. A twin-only kill is not enough for the
   E1 pair requirement.

**What a survivor means here:** if the cell stays green, the cell's script
likely preserves final truthiness (e.g. it only checks that the stack is
non-empty). That is a cell finding (`RT-…`, `MUT`/S2), not an equivalent
mutant. Strengthen the cell with the witness above and re-run.

---

## 4. Open design questions

The workstream advanced while this design was written. Questions already
answered by the contract/twin reports are marked **resolved**; the rest still
need an owner decision.

| # | Question | Why it matters | Decision owner |
|---|---|---|---|
| Q1 | **Resolved (design):** the twin is generated by `twin/gen.py` from `twin/ops_ir.py`. Required model-site mutants edit `ops_ir.py` and regenerate; generated-only mutants edit `build/twin.cpp` and record the drift. | A generated twin has no stable hand-written anchors. The generator-site mutant tests generator faithfulness; the generated-site mutant tests proof sensitivity. Both must be labelled. | TWIN-IR + REDTEAM |
| Q2 | What is the Core-copy base and lifecycle? `P-CORE-01/02/03` are **PROPOSED** with no differential evidence. Is a core-copy mutant applied to unpatched Core (behavior oracle) or the patched proof lane? | The copy must be at the pin, rebuilt from scratch, never a `patches/` entry, and must not contain undeclared changes. Proposed: run behavior-sensitive mutants on unpatched Core and proof-sensitive mutants on the declared patch set; record `patched: yes/no` and patch ids. | CORE-IR |
| Q3 | How are hash and crypto externals modeled in Alive2? | With uninterpreted externals, some hash/checker mutants may be unprovable; SAW overrides or differential may be the only catchers. | TOOLS + CELLS |
| Q4 | **Resolved (contract):** error precedence is "first failing check" (`contract/error_enum.md`). Remaining: the twin/Rust maps must be total, and `F-DIV-001` is a known L deviation on malformed tails. | A cell cannot compare error kinds until the mapping and precedence behavior are total; "both fail" is not equality. | TWIN-IR + RUST-IR + CONTRACT |
| Q5 | **Resolved (contract):** `tape.md` §7 defines the domain and result `2` for out-of-domain input. Remaining: multi-input taproot uses synthetic spent outputs (`tape.md` §6), so genuine multi-input sighash cells are out of contract and must be filed as gaps. | Silent domain narrowing is the easiest way to hide a divergence. | CONTRACT + CELLS |
| Q6 | Are the three shims independent enough for the differential? They now exist (`shims/core`, `shims/twin`, `shims/rust`), but share helpers? | Shared marshalling makes agreement cheap. At least one independently written decoder is needed. | CONTRACT + leg owners |
| Q7 | Is a `rust-copy` mutation canary required in E3/E4? Alive2 cannot ingest the pinned rbitcoin 1.95 IR (`F-TOOL-001`), so R is SAW/differential-only. | R-specific blind spots may remain; a canary must be scoped to what SAW/differential can observe. | RUST-IR + REDTEAM |
| Q8 | What is the acceptable unjudged/gap budget per family? | The 20% review trigger is a policy proposal, not a measured threshold. A human must accept it. | LEDGER + human |
| Q9 | How are certificates authenticated? | Deterministic proofs have no nonce; binding + clean replay is the substitute. The trust boundary must be stated. | TOOLS |
| Q10 | How do we distinguish a tool timeout from inapplicability? | A timeout must not be filed as a named feature gap. A resource budget and decomposition attempt are required. | TOOLS + CELLS |
| Q11 | Are cell postconditions strong enough at the ABI boundary? | Entry-level cells only expose verdict/error, so order-only mutants may survive; leaf cells with stack postconditions are needed. | CELLS |
| Q12 | What is the exact mapping from a mutation to the generated twin diff? | For generator-site mutations, the generated diff must be recorded or the kill is not attributable. `gen.py --check` must be run and the drift recorded. | TWIN-IR + REDTEAM |
| Q13 | What is the dual-tool policy for R at the pin? | `PINS.lock` records that Alive2 cannot ingest the pinned rbitcoin IR (`F-TOOL-001`). R cells cannot be `GREEN-BOTH`; the named feature and SAW/differential substitute must be filed. | TOOLS + RUST-IR |

---

## 5. Blockers and readiness

**Current blockers to executing the protocol:**

- There are no gate cell directories yet. `cells/README.md` specifies the first
  batch (`cells/e1-stack/swap-order`, `cells/e1-stack/dup-order`) but neither
  has a spec, certificate, or green baseline.
- Only the `M-E1-001` and `M-E1-002` twin anchors are calibrated. All other
  anchors still need a patched Core copy and the generated twin; applying them
  now refuses with `MUTATION_NOT_CALIBRATED`.
- The twin handoff is open: decode `scriptSig` from `tx_bytes`, accept
  P2SH/flag cases, and emit Core `ScriptError` ordinals (today `EVAL_FALSE` is
  14 in the twin vs 2 in Core). The swap/dup gate cells use empty scriptSig and
  flags 0, so they are usable inside the skeleton domain; general E1 is blocked.
- `PINS.lock` still has `[core] build = TODO` and `[rbitcoin] build = TODO`.
  The contract hash, clang/LLVM, Alive2, SAW, solvers, rbitcoin commit, and
  Lean revision are present. `F-TOOL-001` makes R/Alive2 cells inapplicable at
  the pin.
- `spec/db/equiv-cells.yaml` now exists (183 rows) but every row is `planned`;
  `coverage_report.py --strict` fails. REDTEAM has not audited it for
  unjudged-cell inflation or gap-note quality.
- Core patches `P-CORE-01/02/03` are PROPOSED, not behavior-preservation
  evidence-complete. The unpatched binary remains the behavior oracle; no
  differential run has been executed.
- `F-DIV-001` (Lean eager parse vs Core streaming) is open. Malformed-tail
  cells must restrict the domain to fully parseable scripts or be filed
  `unjudged-seam`.

**What REDTEAM needs from other roles before E0 sign-off:**

| Role | Needed |
|---|---|
| CONTRACT | ABI conformance validator/tests for `(result, error_kind)`; total L/R error maps; multi-input taproot gap policy |
| CORE-IR | Core build hash for `PINS.lock`; detached-copy procedure; unpatched-vs-patched differential evidence for P-CORE-01/02/03 |
| TWIN-IR | first two `ops_ir.py` anchors calibrated; remaining anchors, scriptSig/flags/error-ordinal handoff, `gen.py --check` drift recording |
| RUST-IR | rbitcoin build hash; SAW-only lane evidence; panic policy; optional R canary scope |
| TOOLS | `[core]`/`[rbitcoin]` build pins; gate scripts; timeout/resource policy; R/Alive2 inapplicability record |
| CELLS | The two first gate cells with specs, both-tool attempts, certificates, and a green baseline; then a third E1 gate cell |
| LEDGER | `equiv-cells.yaml` exists but all 183 rows are `planned`; gap schema and inflation audit remain |

**E0 sign-off requires** the shim-smuggle and pin-drift canaries, ABI
conformance, determinism, and complete-or-named-blocker pins. It does not
require a semantic mutant; E1 is the first semantic gate. E1 cannot be signed
from two gate cells: the required third mutation needs a third gate cell.

---

## 6. What would falsify this design

- A required mutant survives and the family is still signed green.
- A cell is killed by a comment-only control mutant (source-text sensitivity).
- A shim can change a verdict and the review/static check does not catch it.
- `gate-ir-pin` passes after a pin is altered in a copy.
- A certificate from one cell is accepted for another.
- A gap is filed as "tool timeout" or "hard" and counted as coverage.
- The three legs agree on a corpus that contains no boundary cases and the
  agreement is cited as evidence.
- A family is signed without a passed mutation test.

Any one of these is an S1 finding and blocks the milestone.

---

## 9. Execution addendum — 2026-10-19 (first kills)

The protocol was executed against the green baseline with
`cells/_redteam/run_mutant.py` (apply via `mutate.py` only; rebuild the
expected cell; require at least one tool non-green; revert; re-run baseline
green). Raw run records are in `cells/_redteam/runs/`; mutant records and
revert records are in `cells/_redteam/mutants/`.

| Run | Site | Expected cell | Alive2 mutant | SAW mutant | Revert + baseline |
|---|---|---|---|---|---|
| `M-E1-001` | twin `OP_SWAP` | `e1-stack/swap-order` | not-green | not-green | restored, green |
| `M-E1-002` | twin `OP_DUP` | `e1-stack/dup-order` | not-green | not-green | restored, green |
| `M-E1-006` | twin `OP_DEPTH` | `e1-stack/depth-count` | not-green | not-green | restored, green |
| `M-E1-001` | core-slice `OP_SWAP` (`cells/_tools/gate/c_leaf.cpp`) | `e1-stack/swap-order` | not-green | not-green | restored, green |
| `M-E2-010` | twin `OP_RETURN` | `control-flow/C-L-nop-return` | not-green | not-green | restored, green |
| `M-E1-008` | twin `OP_2DROP` | `stack-ops/C-L-arity` | not-green | not-green | restored, green |
| `M-E4-004` | E4 cell `l_cell.cpp` 20-byte arm | `e4-witness/C-L-witness-v0-dispatch` | not-green | not-green | restored, green |
| `M-E3-008` | E3 reviewed `l_cms.cpp` CHECKMULTISIGVERIFY | `e3-cms/C-L-cms-1of1` | not-green | not-green (11/16) | restored, green (16/16) |

**Result:** PASS for the E1/E2/E3/E4 mutation requirement: seven distinct mutant
IDs, model-site and core-slice applications, all killed by both tools, with
byte-identical source restoration. The E1 cell role also records independent
kills of `M-E1-003`, `M-E1-004`, and `M-E1-007` in a disposable copy under
`findings/cells/mutations/`; those are not re-run here.

**Residual:** the core application is the **line-cited Core source-excerpt
slice** used by the cell, not a rebuild of the whole Core translation unit.
A full-Core rebuild mutation remains `E1-CORE-RESIDUAL`; it is not claimed as
done. The core-slice mutation is labelled as such in the run report and in
`mutate.py`.

No survivor was observed. A survivor would be a finding, not a green.

