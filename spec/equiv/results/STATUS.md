# STATUS — three-leg LLVM IR equivalence

**Last updated:** 2026-10-20 (wave 16 integration checkpoint)
**Current state:** **E0 PASS; E6 evidence-tier closure published.**

`make e0`, `make pins`, `make gate-ir-pin`, and `make equiv` all exit 0.
The cell suite contains **28 recorded cells**, all with both Alive2 and SAW
attempts; `make equiv` reports **28 cells with >=1 green tool, 0 red, 0 TODO**.
The ledger has **183/183 SCR rows adjudicated**: 22 both-tool green rows,
17 unjudged seams, 144 filed gaps, and **0 planned**. `coverage_report.py
--strict` passes. This is **not** an all-rows-green claim and not a
whole-engine equivalence proof; see the limits below.

## Milestones

| ID | Deliverable | Status | Evidence |
|---|---|---|---|
| **E0** | Harness/ABI, three hello-world shims, tool install + pins, capability matrix, `PINS.lock` | **PASS** | `make e0` green; 4/4 tapes; `results/e0/`; `tools/capability-matrix.md` |
| **E1** | Stack-op family, Alive2 + SAW, REDTEAM mutation test | **PASS (cells + mutations)** | 9 E1/stack control cells; SCR-069/071/072/074 green; 8 mutation runs killed (7 distinct IDs) |
| **E2** | Flow / ScriptNum / hash families | **attempted; partial cells, rows filed gap** | `cells/e2-numeric/within-boundary` and `cells/e2-hash/hash160-vector` both tools green but row coverage partial; `findings/e2/report.md` |
| **E3** | CHECKSIG/CHECKMULTISIG + symbolic checker + error-enum equality | **attempted; partial cells, rows filed gap** | `cells/e3-checksig/C-L-checksig-dispatch`, `cells/e3-cms/C-L-cms-1of1`, fallback `cells/checksig/C-L-checksig-empty`; exact ordinals 2/13/14/18/28; `M-E3-008` killed |
| **E4** | SegWit v0 / taproot dispatch; seam-unjudged cells enumerated | **attempted; partial cell + 38-row inventory** | `cells/e4-witness/C-L-witness-v0-dispatch` (dispatch predicates only); `findings/e4/seams.md`; `M-E4-004` killed |
| **E5** | Whole-function `VerifyScript` (SAW invariants) or scoped residual | **scoped residual** | `findings/e5/E5-RESIDUAL.md`, `findings/e5/F-TOOL-001.md`; no whole-function proof; green empty-script run is concolic/non-pin |
| **E6** | Three-leg closure, full SCR coverage, `gate-ir-pin`, published matrix | **PASS for the evidence-tier deliverable** | 183/183 adjudicated; `make gate-ir-pin` 0 failures; `make equiv` 28 cells, 0 red; `results/matrix.md`; `findings/coverage/F-E6-GAPS.md` |
| **E6+** | Wave 16 row-family cells; limits and tapscript dispatch integrated | **partial, additive** | 10 limits rows + 8 tapscript rows both-tool green; 22 total green; see `findings/wave16/` |

## Ledger snapshot

| Metric | Value |
|---|---:|
| SCR rows in `spec/db/rules.yaml` | 183 |
| Ledger entries in `spec/db/equiv-cells.yaml` | 183 |
| Families | 15 |
| Proof-cell directories (recorded) | 28 |
| `planned` | 0 |
| Both-tool green rows | 22 |
| Alive2-only / SAW-only green rows | 0 / 0 |
| `unjudged-seam` | 17 |
| Filed `gap` | 144 |
| Malformed cell records | 0 |
| `make equiv` | 28 cells green, 0 red, 0 TODO |
| `make gate-ir-pin` | PASS (0 failures, 0 warnings) |
| `coverage_report.py --strict` | PASS — all 183 rows adjudicated |

Green rows: **SCR-018–020, SCR-022–025, SCR-029–031** (limits,
`cells/limits/C-L-*`), **SCR-069, SCR-071, SCR-072**
(`control-flow/C-L-nop-return`), **SCR-074** (`stack-ops/C-L-arity`,
corroborated by three E1 stack cells and `stack/C-L-dup-drop-swap`), and
**SCR-143–145, SCR-148–152** (tapscript dispatch, `cells/tapscript/C-L-*`).
The tapscript key-path row (SCR-144) is conditional on the same-crypto
premise P12; SCR-021 and SCR-142 remain partial and are not promoted.

### What is *not* claimed

- No unconditional Lean == Core or C == L == R statement. The matrix claim is
  conditional on the pinned front-ends, Alive2/SAW semantics, the shims, the
  twin/translations, and same-crypto.
- No whole-engine `VerifyScript`/`EvalScript` proof. E5 is a scoped residual:
  SAW stops at `GetScriptOp`, the heap allocator, the dispatch loop, and
  exception edges. The one green empty-script SAW run is a concrete,
  concolic, non-pin execution, not a ledger row.
- R has no admissible proof-lane artifact. The pinned rustc 1.95/LLVM 22 IR
  is rejected by Alive2 v20 (`F-TOOL-001`); the rustc 1.88/LLVM-20 derivative
  is a non-pin advisory lane only. R behavioral E0 passes; R proof cells do
  not.
- E2, E3, and E4 cells are deliberately **partial**. Their SCR rows are gaps,
  with the missing branches named in `findings/coverage/F-E6-GAPS.md`.
- Crypto is abstracted on both legs; see `docs/DECISION-lax-ecdsa.md`. No
  libsecp256k1-internals claim.

## Reproduce

```sh
cd spec/equiv
make pins
make e0
make gate-ir-pin
make equiv
python3 results/scripts/coverage_report.py --strict
```

The matrix is `results/matrix.md`; the complete non-green disposition index
is `findings/coverage/F-E6-GAPS.md`. The trust base is `docs/TRUST-BASE.md`
and `results/matrix.md` §Trust base.

## Cell → ledger rule

`results/scripts/update_ledger.py` is the supported updater. A row becomes
green only when a valid cell lists it and the raw `alive2/result.txt` and
`saw/result.txt` both contain the success marker. A partial-coverage cell can
be tool-green without promoting its row; the ledger keeps it gap unless the
cell says `scr_row_coverage: full` and the updater derives green. No row was
moved by hand.

## Artifacts

| Artifact | Purpose |
|---|---|
| `spec/db/equiv-cells.yaml` | 183-row SCR coverage ledger |
| `results/matrix.md` | generated per-family matrix, trust base, cell links |
| `results/STATUS.md` | this checkpoint |
| `findings/coverage/F-E6-GAPS.md` | every non-green row and disposition |
| `findings/e2/report.md`, `findings/e3/report.md`, `findings/e4/report.md` | family attempts and limits |
| `findings/e5/E5-RESIDUAL.md` | whole-function residual |
| `findings/ir/report.md` | 15-TU closure and tool-ingestion findings |
| `cells/_redteam/MUTATIONS.md`, `cells/_redteam/runs/` | mutation catalogue and kills |
| `contract/CHANGELOG.md` | contract v2 → v3 re-pin |
| `docs/TRUST-BASE.md`, `docs/STATE.md` | premises and current state |
