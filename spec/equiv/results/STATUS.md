# STATUS — three-leg LLVM IR equivalence

**Last updated:** 2026-10-20 (wave 16/32 integration + wave64 E3/E4 mutation update)
**Current state:** **E0 PASS; E6 evidence-tier closure published.**

`make e0`, `make pins`, `make gate-ir-pin`, and `make equiv` all exit 0.
The cell suite contains **141 recorded cells**, all with both Alive2 and SAW
attempts; `make equiv` reports **141 cells with >=1 green tool, 0 red, 0 TODO**.
The ledger has **183/183 SCR rows adjudicated**: 143 both-tool green rows,
2 unjudged seams, 38 filed gaps, and **0 planned**. `coverage_report.py
--strict` passes. This is **not** an all-rows-green claim and not a
whole-engine equivalence proof; see the limits below.

## Milestones

| ID | Deliverable | Status | Evidence |
|---|---|---|---|
| **E0** | Harness/ABI, three hello-world shims, tool install + pins, capability matrix, `PINS.lock` | **PASS** | `make e0` green; 4/4 tapes; `results/e0/`; `tools/capability-matrix.md` |
| **E1** | Stack-op family, Alive2 + SAW, REDTEAM mutation test | **PASS (cells); mutation evidence incomplete** | 9 E1/stack control cells; SCR-069/071 green; SCR-072/074 demoted after audit; 6/8 mutation reports withdrawn, 2 observed, 0 admitted (`cells/_redteam/AUDIT-ADJUDICATION.md`) |
| **E2** | Flow / ScriptNum / hash families | **attempted; partial cells, rows filed gap** | `cells/e2-numeric/within-boundary` and `cells/e2-hash/hash160-vector` both tools green but row coverage partial; `findings/e2/report.md` |
| **E3** | CHECKSIG/CHECKMULTISIG + symbolic checker + error-enum equality | **attempted; partial cells, rows filed gap** | `cells/e3-checksig/C-L-checksig-dispatch`, `cells/e3-cms/C-L-cms-1of1`, fallback `cells/checksig/C-L-checksig-empty`; exact ordinals 2/13/14/18/28; **mutation 2/5 required** (`M-E3-002`, `M-E3-008` killed; three rows unobserved) — `cells/_redteam/WAVE64-MATRIX.md` |
| **E4** | SegWit v0 / taproot dispatch; seam-unjudged cells enumerated | **attempted; partial cell + 38-row inventory** | `cells/e4-witness/C-L-witness-v0-dispatch` (dispatch predicates only), `cells/tapscript/C-L-taproot-scriptpath-dispatch`, `cells/tapscript/C-L-tapscript-isopsuccess`; `findings/e4/seams.md`; **mutation 3/5 required** (`M-E4-003`, `M-E4-004`, `M-E4-007` killed; two rows unobserved) — `cells/_redteam/WAVE64-MATRIX.md` |
| **E5** | Whole-function `VerifyScript` (SAW invariants) or scoped residual | **scoped residual** | `findings/e5/E5-RESIDUAL.md`, `findings/e5/F-TOOL-001.md`; no whole-function proof; green empty-script run is concolic/non-pin |
| **E6** | Three-leg closure, full SCR coverage, `gate-ir-pin`, published matrix | **PASS for the evidence-tier deliverable** | 183/183 adjudicated; `make gate-ir-pin` 0 failures; `make equiv` 141 cells, 0 red; `results/matrix.md`; `findings/coverage/F-E6-GAPS.md` |
| **E6+** | Wave 16/32 row-family cells integrated | **partial, additive** | 143 total green: tapscript 21, limits 22, checksig 16, control-flow 16, exec-verify 13, locktime 11, push-encoding 10, policy 7, witness-v0 6, numeric 6, checkmultisig 5, disabled 4, stack-ops 4, hash 1, reimport 1; see `findings/wave16/` and `findings/wave32/` |

## Ledger snapshot

| Metric | Value |
|---|---:|
| SCR rows in `spec/db/rules.yaml` | 183 |
| Ledger entries in `spec/db/equiv-cells.yaml` | 183 |
| Families | 15 |
| Proof-cell directories (recorded) | 141 |
| `planned` | 0 |
| Both-tool green rows | 143 |
| Alive2-only / SAW-only green rows | 0 / 0 |
| `unjudged-seam` | 2 |
| Filed `gap` | 38 |
| Malformed cell records | 0 |
| `make equiv` | 141 cells green, 0 red, 0 TODO |
| `make gate-ir-pin` | PASS (0 failures, 0 warnings) |
| `coverage_report.py --strict` | PASS — all 183 rows adjudicated |

Green rows by family (the authoritative list is `results/matrix.md`):

- **control-flow (16):** SCR-056–071, except SCR-072 (withdrawn).
- **limits (22):** SCR-018–020, 022–035, 037–039, 041, 042.
- **tapscript (21):** SCR-143–145, 148–152, 155–166, 168; SCR-144 is
  conditional on the same-crypto premise P12.
- **locktime (11):** SCR-122–132.
- **checksig (16):** SCR-096–103, 105–111, 113.
- **policy-flags (7):** SCR-176–182; **tapscript-reimport (1):** SCR-183.
- **witness-v0 (6):** SCR-134, 135, 137, 138, 139, 141.
- **exec-verify (13):** SCR-002–004, 006–009, 011, 013–017; **checkmultisig (5):** SCR-114, 118–121.
- **push-encoding (10):** SCR-045–050, 052–055; **stack-ops (4):** SCR-073, 075–077; **numeric (6):** SCR-087–092.
- **disabled-opcodes (4):** SCR-170, 171, 173, 174.
- **hash-ops (1):** SCR-094.

SCR-021, 040, 072, 074, 133, 136, 140, 142, 175, and the other non-green rows
remain partial/seam/gap and are not promoted.

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
- **No mutation PASS.** Six of eight recorded 2026-10-19 mutation reports are
  withdrawn because their green tails contradict their `KILLED` headers; the
  two genuine non-green runs had pending records. Wave64 added five admissible
  kills (`M-E3-002`, `M-E3-008`, `M-E4-003`, `M-E4-004`, `M-E4-007`), but the
  required sets are still incomplete: **E3 2/5, E4 3/5**, E2 0/4. All five new
  kills are L-leg transliteration sites; the required model-site/core-copy
  pairing is unmet. See `cells/_redteam/WAVE64-ADJUDICATION.md` and
  `WAVE64-MATRIX.md`. This is a separate control from the cell Alive2/SAW
  results.
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
cell says `scr_row_coverage: full` and the updater derives green. No green row was
moved by hand; SCR-072 was explicitly withdrawn with a filed note after audit.

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
| `cells/_redteam/MUTATIONS.md`, `cells/_redteam/runs/`, `cells/_redteam/AUDIT-ADJUDICATION.md` | mutation catalogue, raw runs, adjudication |
| `contract/CHANGELOG.md` | contract v2 → v3 re-pin |
| `docs/TRUST-BASE.md`, `docs/STATE.md` | premises and current state |
