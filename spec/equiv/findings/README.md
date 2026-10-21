# Findings protocol

Every non-green result is a finding with an ID, evidence, and a disposition.

## Format

```
F-<area>-<nnn>: <one-line title>
  legs: C | L | R
  cell: <path or "n/a">
  symptom: what was observed (counterexample, divergence, UB, tool block)
  evidence: command + hash + log path
  disposition: open | upstream-issue | domain-restricted | tool-gap | fixed
  notes: blocking IR feature, upstream link, or patch id
```

## Areas

- `UB` — undefined behavior in Core/rbitcoin/twin (Core UB ⇒ draft upstream issue)
- `DIV` — verdict/error divergences between legs
- `TOOL` — tool cannot ingest a cell (name the feature: invoke, indirect call, ptrtoint, loop, LLVM version)
- `HARNESS` — contract/shims/corpus defects
- `PATCH` — patch behavior-preservation failures

## Rules

- No green cell may hide an open finding.
- Counterexamples are preserved verbatim (input tape + expected/actual).
- Findings are append-only; corrections are new entries.

## Namespacing

A bare `F-<AREA>-<nnn>` id is **global** to `spec/equiv`. Role-local ledgers
(e.g. `findings/core/findings-ledger.md`) are cited as `<ROLE>:F-...` and do
not collide with global ids; promoting one requires a fresh global number and
a pointer to the local entry. Currently global: `F-DIV-001`, `F-UB-001`,
`F-TOOL-001` (Alive2 × rustc-1.95), `F-HARNESS-001` (Lean verdicts labelled
L), `F-HARNESS-002` (R ABI domain), `F-PATCH-002` (R FFI proposal). Local:
`CORE:F-TOOL-001..006`, `CORE:F-HARNESS-001`, `CORE:F-PATCH-001`,
`CORE:F-PIN-001`, `IR:F-PIN-001..002`, `E4:F-TOOL-001`,
`E5:F-TOOL-001` (whole-function blockers; see `E5-RESIDUAL.md`).

## Index

| ID | Area | Status | One line |
|---|---|---|---|
| F-DIV-001 | DIV | open | Lean eager `parseWire` vs Core streaming `GetOp` (error kind on malformed tails) |
| F-UB-001 | UB | closed | Core `int64_t` ScriptNum bounds not reachable |
| F-TOOL-001 | TOOL | open | Alive2 v20 cannot ingest real rustc-1.95/LLVM-22 R IR (`dead_on_return`, metadata 8) |
| F-HARNESS-001 | HARNESS | open | `differential/` labels the Lean model runner as the L leg; not C-twin evidence |
| F-HARNESS-002 | HARNESS | open | R ABI boundary is untyped (string map) and limited to one input / flags 0; E3 blocked |
| F-PATCH-002 | PATCH | open | rbitcoin `equiv-ffi` diff is proposal-only; official R uses the clean public-API shim |
| F-DIV-002 | DIV | fixed | Twin false `OP_EQUAL` pushed `{00}` instead of empty; fixed and re-run green |
| IR:F-PIN-001 | PIN | open | `[core.ir]` single-TU and `[ir]` 15-TU closure are different artifact scopes; not substitutes |
| IR:F-PIN-002 | PIN | fixed | `[rbitcoin] build` prose now names the official 1.95 IR lane and the advisory 1.88 Alive2 lane separately |
| E4:F-TOOL-001 | TOOL | open | full witness/taproot dispatch needs loop/tx/hash/EC context; bounded leaf cannot judge those rows |
| E5:F-TOOL-001 | TOOL | open | whole `VerifyScript`/`EvalScript` blocked by `GetScriptOp`, heap, dispatch loop, and exception edges |
| E5-RESIDUAL | TOOL | open | no whole-function proof; scoped residual with concrete empty-script concolic run only |

## Current integration index (post-E6)

| Location | Scope | Status |
|---|---|---|
| `findings/coverage/F-E6-GAPS.md` | every non-green SCR row, generated from the ledger | 2 seam + 29 gap, 0 planned |
| `findings/e2/report.md` | WITHIN/HASH160 partial cells | tools green, rows gap |
| `findings/e3/report.md` | CHECKSIG/1-of-1 CMS, symbolic checker, error enums | tools green, rows partial; M-E3-008 killed |
| `findings/e4/report.md`, `findings/e4/seams.md` | v0 dispatch partial cell and 38-row seam/gap inventory | dispatch predicates only |
| `findings/e4/F-TOOL-001.md` | witness/taproot dispatch needs context | open tool gap |
| `findings/e5/E5-RESIDUAL.md`, `findings/e5/F-TOOL-001.md` | whole-function VerifyScript blockers | scoped residual, no proof |
| `findings/ir/report.md` | 15-TU Core/twin/R IR closure | hashes verified |
| `findings/redteam/redteam-report.md` | mutation campaign | 8 runs / 7 distinct IDs, all killed |
| `findings/evaluator/audit.md` §13 | post-snapshot dispositions | B-01/B-04/B-06/B-07/B-09/B-10/M-15/M-16 resolved; B-03/B-05/B-08 open |

No non-green cell hides an open finding. The partial cells are deliberately
not promoted to green; their missing branches are named in their `spec.md`
and in the generated gap report.
