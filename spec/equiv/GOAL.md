# GOAL — three-leg LLVM IR equivalence (long-running)

This file is the durable objective for the `spec/equiv` workstream. It is
written so a fresh session or subagent can resume without rediscovering
context. The human-facing evaluation guide is `README.md`; the normative
contract is `contract/ABI.md`.

> **Current checkpoint (2026-10-21):** E0 and E1 cells pass; E2/E3/E4 are
> tool-green but partial; E5 is a scoped residual; E6 has 183/183 SCR rows
> adjudicated (159 both-green, 1 seam, 23 gaps, 0 planned). `make pins`,
> `make e0`, `make gate-ir-pin`, and `make equiv` pass. This is evidence-tier,
> not an all-rows-green or whole-engine result. Read `results/STATUS.md`.

## Objective

Prove LLVM IR-level equivalence across the three script-engine legs — Core
C++ (**C**), the Lean-derived twin (**L**), and rbitcoin Rust (**R**) — using
**both** Alive2 and SAW, through milestones E0–E6. Every SCR rule row must be
covered by a green cell or a filed gap. No unconditional claim may be made.

## Success criteria (observable)

1. `spec/equiv/PINS.lock` pins every tool, commit, flag, and IR hash.
2. E0: three hello-world shims produce a green triple; capability matrix
   documents what each tool can and cannot ingest (exceptions, indirect
   calls, ptrtoint, LLVM versions).
3. E1–E4: every family has cells attempted with both tools, certificates (or
   inapplicability reasons) recorded, and a REDTEAM mutation test passed.
4. E5: whole-function `VerifyScript` proof, or a scoped residual naming the
   blocking IR feature.
5. E6: `spec/db/equiv-cells.yaml` covers all 183 SCR rows; `make gate-ir-pin`
   and `make equiv` pass; `results/matrix.md` published.
6. Any Core UB found is drafted as an upstream issue in `findings/`.
7. No unfiled gaps anywhere.

## Constraints

- Core source may be patched **only** per `patches/README.md` (minimal,
  tracked, behavior-preserving, evidence attached).
- Never change consensus semantics; never patch around a divergence to make
  a cell green.
- Crypto stays abstracted per `docs/DECISION-lax-ecdsa.md`; the claim is
  conditional on same-crypto.
- All results are evidence-tier; do not describe them as Lean-kernel theorems.
- Tool versions and IR hashes are immutable once recorded; re-pinning is a
  new result.
- No fabricated tool runs: if a tool is unavailable, record the blocker.

## Milestones and acceptance

| ID | Acceptance |
|---|---|
| E0 | hello-world triple green; capability matrix filled; PINS.lock committed |
| E1 | stack-op family green with both-tool attempts; mutation caught |
| E2 | flow/numeric/hash families green; gaps filed |
| E3 | checksig/CMS green with symbolic checker; error-enum equality |
| E4 | witness-v0/taproot dispatch green; unjudged seam cells enumerated |
| E5 | whole-function VerifyScript proved or scoped residual |
| E6 | SCR coverage complete; gates green; matrix + trust base published |

## Fleet (maximum parallelization)

| Role | Write scope | Owns |
|---|---|---|
| CONTRACT | `contract/`, `shims/*/` skeletons | ABI, tape, error enum, corpus schema, hello-world shims |
| CORE-IR | `findings/core/`, `patches/core/` | Core pin/build, IR extraction, cell slicing, patch proposals |
| TWIN-IR | `twin/`, `findings/twin/` | generator/transliteration, IR, generator audit |
| RUST-IR | `findings/rust/`, `shims/rust/` | rbitcoin pin/build, IR, panic shim, Kani/Miri |
| TOOLS | `tools/` | install/pin Alive2+SAW+solvers, capability matrix, gate scripts |
| CELLS | `cells/<family>/` | per-family Alive2 + SAW cells, certificates |
| LEDGER | `spec/db/equiv-cells.yaml`, `results/` | SCR coverage, matrix generation, gates |
| REDTEAM | `findings/redteam/` | mutation tests, harness attacks, divergence triage, sign-off |

### Parallelization protocol

- **Strict directory ownership** — no agent writes outside its scope; shared
  files are proposed via handoff notes in `findings/handoffs/`.
- **Handoff format**: `findings/handoffs/<from>-to-<to>-<topic>.md` with
  status, artifacts, blockers, next action.
- **Independent work runs concurrently**: families E1–E4 in parallel; the
  three legs build in parallel; tool installation runs in parallel with leg
  builds.
- **Dependencies** are explicit: CELLS waits for CONTRACT (ABI) and the leg
  IRs; E6 waits for all families and LEDGER.
- **Conflict avoidance**: one writer per file; generated files are rebuilt,
  never hand-edited; certificates are content-addressed.
- **Checkpoint** after each milestone: update `results/STATUS.md` with
  green/blocked cells, gaps, and next actions.

## Resume protocol

1. Read `README.md`, `PINS.lock`, `results/STATUS.md`.
2. Check `findings/handoffs/` for open work.
3. Run `make gate-ir-pin` to see what is actually green.
4. Continue from the first unmet milestone criterion; do not redo green cells.

## Reporting discipline

Every claim points to a cell record with tool version, IR hash, spec, and
certificate. Divergences get finding IDs. A green cell may be demoted only
with a recorded counterexample or a pin change.
