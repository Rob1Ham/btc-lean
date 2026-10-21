# INDEX — `spec/equiv` reading map

**Snapshot:** `2026-10-21` (post-wave66 accepted integration)
**Purpose:** get a reviewer from "what is this?" to "what exactly is proved,
what is only claimed, and what is missing" without reading every role report.

---

## 1. Start here

| If you have… | Read | Time |
|---|---|---|
| 2 minutes | this page + the box below | 2 min |
| 10 minutes | [`STATE.md`](STATE.md) §1–§5 + [`../findings/coverage/F-E6-GAPS.md`](../findings/coverage/F-E6-GAPS.md) | 10 min |
| 1 hour | `STATE.md`, `TRUST-BASE.md`, `../results/matrix.md`, then the normative contract | 1 h |
| a day | all of the above, then the family reports and raw logs | 1 d |

> **Current status in one line:** E0 passes; E1 has bounded cells and killed
> mutations; E2/E3/E4 have tool-green but **partial** cells; E5 is a scoped
> residual with no whole-function proof; E6 has **183/183 SCR rows
> adjudicated** (159 both-tool green, 1 unjudged seam, 23 filed gaps, 0
> planned). `make pins`, `make e0`, `make gate-ir-pin`, and `make equiv` all
> exit 0. The result is **conditional evidence-tier**, not an all-green or
> Lean-kernel claim.

---

## 2. The claim and its tiers

The normative claim is a **conditional** statement, not a theorem:

> If the pinned front-ends, Alive2/SAW semantics, solvers, shims,
> twin/translations, contract, and same-crypto premise are sound, then the
> Core slice and the Lean-derived twin agree on verdict and error kind for the
> harness domain.  No R cell exists; the R lane is advisory/blocked.

Evidence tiers actually present:

| Tier | What exists | What it covers |
|---|---|---|
| **T0 — pins/contract** | verified versions, HEADs, contract v3 hash, ABI v2, 56-entry enum | the harness, not the engines |
| **T1 — tool probes** | Alive2/SAW positive + negative controls; capability matrix | tool ingestion, not cells |
| **T2 — bounded cells** | 177 cell directories, all with Alive2 and SAW success markers | bounded leaves/predicates; partial cells do not promote rows |
| **T3 — behavioral differential** | C vs expected 1258/1258; C vs Lean model 1251/1258; C vs twin 922/0/336 (v2-historical) | behavior, not IR; R absent |
| **T4 — E0 triple** | C/L/R agree on 4/4 tapes; clean 1.95 R shim | harness/ABI smoke, not proof |
| **T5 — ledger** | 159 both-green, 1 unjudged-seam, 23 gap, 0 planned | every row has a disposition |
| **T6 — whole-engine proof** | **none** | E5 residual, not a proof |

---

## 3. Document map

### Evaluator (start here)

| File | What it is |
|---|---|
| [`STATE.md`](STATE.md) | dated E0–E6 table, what is/isn't established, current commands, open limits |
| [`REPRODUCE.md`](REPRODUCE.md) | copy-paste commands with actual output and exit codes |
| [`TRUST-BASE.md`](TRUST-BASE.md) | premises P1–P20, verified pins, compiler provenance, tool limits, re-pin rules |
| [`../findings/evaluator/audit.md`](../findings/evaluator/audit.md) | historical audit; **§13 is the current post-E6 addendum** |
| `INDEX.md` | this page |

### Normative contract (source of truth)

| File | Role |
|---|---|
| [`../contract/ABI.md`](../contract/ABI.md) | ABI v2, result codes, error-kind out-param |
| [`../contract/tape.md`](../contract/tape.md) | tape layout, domain rules, contract hash recipe |
| [`../contract/error_enum.md`](../contract/error_enum.md) | 56 Core ordinals, 1:1 mapping |
| [`../contract/error_kind.h`](../contract/error_kind.h) | machine-readable enum (generated) |
| [`../contract/corpus_schema.md`](../contract/corpus_schema.md) | corpus/selection schema |
| [`../contract/CHANGELOG.md`](../contract/CHANGELOG.md) | v2 → v3 re-pin history |

The recipe now includes `error_enum.md` and recomputes to
`f1841e36…`; v2 `c2fcc67a…` is historical (audit B-06 resolved).

### Source and harness

| Path | State |
|---|---|
| [`../shims/core/entry.cpp`](../shims/core/entry.cpp) | C shim: marshalling + `VerifyScript`; no engine logic |
| [`../shims/twin/entry.cpp`](../shims/twin/entry.cpp) | **stub** (`3`/`UNKNOWN`); bypassed by E0 |
| [`../shims/rust/entry.rs`](../shims/rust/entry.rs) | live clean 1.95 public-API shim; source `1fd706b8…`, `.so` `73e3d2d9…` |
| [`../twin/`](../twin/) | generator, smoke driver, generated C++; pinned-clang smoke **147/147** |
| [`../patches/core/`](../patches/core/) | P-CORE-01/02/03 **PROPOSED**, no differential, no green cell; 04/05 design only |
| [`../ir/`](../ir/) | 15-TU Core/twin/R closure and `manifest.json` (`bef064db…`) |

### Evidence and results

| Path | State |
|---|---|
| [`../results/STATUS.md`](../results/STATUS.md) | current E0–E6 checkpoint |
| [`../results/matrix.md`](../results/matrix.md) | generated; 159 green / 1 seam / 23 gap; named trust base |
| [`../results/e0/README.md`](../results/e0/README.md) | three-leg PASS, R `73e3d2d9…`, L `b9ed129b…`; C provenance caveat |
| [`../results/LEDGER-REPORT.md`](../results/LEDGER-REPORT.md) | bootstrap history; current counts in its addendum |
| [`../findings/coverage/F-E6-GAPS.md`](../findings/coverage/F-E6-GAPS.md) | every non-green SCR row and disposition |
| [`../findings/core/core-ir-report.md`](../findings/core/core-ir-report.md) | Core IR hashes, tool ingest, no engine proof |
| [`../findings/ir/report.md`](../findings/ir/report.md) | 15-TU closure, 19 smoke checks, hash manifest |
| [`../findings/e2/report.md`](../findings/e2/report.md) | WITHIN/HASH160 partial cells |
| [`../findings/e3/report.md`](../findings/e3/report.md) | CHECKSIG/CMS cells, error enums, mutation |
| [`../findings/e4/report.md`](../findings/e4/report.md) | v0 dispatch cell and seam inventory |
| [`../findings/e5/E5-RESIDUAL.md`](../findings/e5/E5-RESIDUAL.md) | why whole-function proof is blocked |
| [`../findings/redteam/redteam-report.md`](../findings/redteam/redteam-report.md) | mutation catalogue and eight kills |
| [`../cells/INDEX.md`](../cells/INDEX.md) | all 177 cell directories and coverage |

### Historical snapshots

The independent evaluator's original state and trust-base pages are preserved
under [`archive/`](archive/):

- `archive/STATE-2026-10-19T223700Z.md`
- `archive/TRUST-BASE-2026-10-19T223700Z.md`

They describe the earlier `0 green / 178 planned / make equiv red` state; they
are history, not current coverage.
