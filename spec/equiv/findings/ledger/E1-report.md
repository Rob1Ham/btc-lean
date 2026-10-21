> **HISTORICAL ROLE REPORT — not the current state.** The live E6 checkpoint is
> `spec/equiv/results/STATUS.md` and `spec/equiv/docs/STATE.md`; the generated
> coverage view is `spec/equiv/results/matrix.md`. This file is retained for
> provenance and may describe an earlier zero-green/TODO-pin state.

# E1 report — ledger machinery and zero-green state

**Role:** LEDGER-E1
**Date:** 2026-10-19
**Repository:** `/home/ubuntu/btc-lean-public`
**Write scope used:** `spec/db/equiv-cells.yaml`, `spec/equiv/results/`
(scripts, `STATUS.md`, `matrix.md`), `spec/equiv/findings/ledger/`.
No commits. No files under `cells/`, `contract/`, `tools/`, `shims/`, `twin/`,
`corpus/`, or other `findings/` areas were modified.

## 0. Bottom line

- The deterministic cell → ledger updater and published matrix now exist and
  were exercised against real and isolated fixtures.
- **The real ledger is still 183 `planned`, 0 green, 0 filed gaps, 0
  `unjudged-seam`.** No proof-cell directory exists under
  `spec/equiv/cells/<family>/<cell>/` yet (only the REDTEAM-owned
  `cells/_redteam/`, which the scanner correctly ignores).
- No row was promoted by hand. A green row is impossible unless a validated
  cell lists it and its raw `alive2/result.txt` / `saw/result.txt` contains the
  tool success marker.
- `make gate-ir-pin` is red for three independent reasons: one TODO build
  pin (`[rbitcoin] build`), no proof-cell records, and 0/183 coverage.
- `make e0` is red because R is a stub (`E0_TRIPLE_PENDING`); C and L are
  correct on all four tapes.

## 1. Delivered artifacts

| Path | What it does |
|---|---|
| `spec/equiv/results/scripts/update_ledger.py` | validates cells and derives `status` / `cells` / `alive2` / `saw` / `gap_note`; `--check`, `--from-cells`, `--cells-dir`, `--ledger`, `--pins` |
| `spec/equiv/results/scripts/build_matrix.py` | writes `results/matrix.md`: per-family counts, trust base, claim form, cell links; fails if a green row has no cell |
| `spec/equiv/results/scripts/coverage_report.py` | extended minimally: green rows must cite an existing valid cell whose record lists the row and contains the matching tool success marker; gap/seam still require a note |
| `spec/equiv/results/scripts/build_equiv_cells.py` | unchanged default behavior; added optional `--ledger PATH` testability hook; still preserves all five hand-maintained fields |
| `spec/equiv/results/matrix.md` | generated matrix (honest zero-green state) |
| `spec/equiv/results/STATUS.md` | updated checkpoint |
| `spec/equiv/results/LEDGER-REPORT.md` | §6 records the E1 changes |
| `spec/equiv/findings/ledger/E1-report.md` | this report |

## 2. Exact commands and current output

Run from `spec/equiv` unless noted.

### 2.1 Ledger round trip / generated-file check

```sh
cd /home/ubuntu/btc-lean-public
python3 spec/equiv/results/scripts/update_ledger.py --check
python3 spec/equiv/results/scripts/build_matrix.py --check
python3 spec/equiv/results/scripts/build_equiv_cells.py --check
```

Observed (2026-10-19, before any cell landed):

```text
$ python3 spec/equiv/results/scripts/update_ledger.py --check
ledger derivation
=================
ledger:  /home/ubuntu/btc-lean-public/spec/db/equiv-cells.yaml
cells:   /home/ubuntu/btc-lean-public/spec/equiv/cells
cells scanned: 0 (valid 0, malformed 0)
rows:    183
statuses: planned=183, alive2-green=0, saw-green=0, both-green=0, unjudged-seam=0, gap=0
green rows: 0; blocked rows: 0
changes: 0
check: /home/ubuntu/btc-lean-public/spec/db/equiv-cells.yaml is up to date
# exit 0
```

```text
$ python3 spec/equiv/results/scripts/build_matrix.py --check
/home/ubuntu/btc-lean-public/spec/equiv/results/matrix.md: up to date
# exit 0
```

```text
$ python3 spec/equiv/results/scripts/build_equiv_cells.py --check
/home/ubuntu/btc-lean-public/spec/db/equiv-cells.yaml: up to date
# exit 0
```

### 2.2 Coverage gate (expected red)

```sh
cd /home/ubuntu/btc-lean-public
python3 spec/equiv/results/scripts/coverage_report.py --strict
# exit 1
```

Tail of the output:

```text
TOTAL                    183      0      183         0    0      0

cell records scanned: 0 (malformed: 0)

strict: FAIL (1 issue(s))
  - 183 SCR row(s) still planned: SCR-001, SCR-002, SCR-003, SCR-004,
    SCR-005, ... (+163 more)
```

This is exactly one issue class: every row is still planned. The extension
did **not** change the 183-row census or the missing/unknown/duplicate checks.
A separate isolated fixture with all 183 rows adjudicated (2 synthetic green +
181 synthetic gaps) made the extended script print
`strict: PASS - all 183 SCR rows adjudicated`, confirming the gate still
accepts full coverage.

### 2.3 `make gate-ir-pin`

```sh
cd spec/equiv
make gate-ir-pin
# make exit 2; gate reports RESULT: FAIL
```

Observed:

```text
gate-ir-pin root: /home/ubuntu/btc-lean-public/spec/equiv
== 1. PINS.lock ==
FAIL  1 TODO pin(s): [rbitcoin] build

== 2. cell records ==
  cell directories: 1; with a record file: 0
WARN  cell without record: cells/_redteam/mutants

== 3. SCR coverage ==
  SCR rows in rules.yaml: 183
  rows in equiv-cells.yaml: 183
  status counts: planned=183
WARN  183 SCR row(s) still 'planned' (not adjudicated)
FAIL  coverage incomplete: 0/183 SCR rows adjudicated

== summary ==
  cell records: 0
  failures: 2; warnings: 2
RESULT: FAIL
make: *** [Makefile:23: gate-ir-pin] Error 1
```

The `_redteam/mutants` directory is REDTEAM scratch, not a cell record.
`gate_ir_pin.py` globs `cells/*/*` and therefore warns on it;
`update_ledger.py` deliberately skips every directory whose name starts with
`_`. This is a gate-discovery defect (TOOLS scope), not evidence of a cell.
The coverage failure and the `[rbitcoin] build` TODO are the only hard
failures.

### 2.4 `make e0` (R still a stub)

```sh
cd spec/equiv
make e0
# make exit 2; RESULT: TOOLS READY; E0 TRIPLE PENDING
```

Observed excerpt:

```text
== E0 tool probes ==
  alive-tv: /usr/local/bin/alive-tv
  saw:      /usr/local/bin/saw
  PASS  alive2 positive: hello-a.ll vs hello-b.ll
  PASS  alive2 negative: hello-a.ll vs hello-bad.ll
  PASS  saw positive: tools/tests/hello.saw
...
        [FAIL] OP_1 passes: C=(1,0)  L=(1,0)  R=(3,1)  want=(1, 0)
        [FAIL] OP_0 fails: C=(0,2)  L=(0,2)  R=(3,1)  want=(0, 2)
        [FAIL] OP_RETURN fails: C=(0,3)  L=(0,3)  R=(3,1)  want=(0, 3)
        [FAIL] empty tx is bad input: C=(2,1)  L=(2,1)  R=(3,1)  want=(2, 1)
        STUB legs (returned 3/UNKNOWN on every failing case): R
        E0_TRIPLE_PENDING
== summary ==
  TOOLS probes: GREEN
  Three-leg hello-world: RED (triple script ran but did not pass)
  RESULT: TOOLS READY; E0 TRIPLE PENDING
```

The C and L columns are correct on all four tapes (including the Core error
ordinals); R returns `3` (`UNKNOWN`) because its shim is still a stub. This is
outside the LEDGER write scope and is recorded so the matrix claim is not
overstated.

## 3. What the updater enforces

### 3.1 Cell schema (expected by `update_ledger.py`)

```markdown
---
contract: <64-hex sha256 from PINS.lock [contract] hash>
legs: [C, L]                 # subset of C, L, R; at least two
precondition: <exact tape subset>
postcondition: <verdict and error_kind relation>
direction: L ⊑ C             # or C ⊑ L / R ⊑ C / C ⊑ R
scr_rows: [SCR-073]          # must exist in rules.yaml / ledger
patches: none                # or patch ids
trust_note: none             # non-empty; anything beyond the global trust base
# optional, for a crypto-seam cell:
# unjudged_seam: <reason; notes.md must cite DECISION-lax-ecdsa.md + finding id>
---
```

Required layout and evidence:

```text
cells/<family>/<cell>/
  spec.md
  alive2/result.txt          # required, non-empty
  alive2/run.sh              # warning if absent
  alive2/certificate.sha256  # warning if absent; if present must hash result.txt
  saw/result.txt             # required, non-empty
  saw/run.sh                 # warning if absent
  saw/certificate.sha256     # warning if absent; if present must hash result.txt
  notes.md                   # required for a filed inapplicability; must name
                             # the blocking feature and an F-TOOL-nnn id
```

### 3.2 Success markers

- Alive2: `Transformation seems to be correct` **and**
  `0 incorrect transformations`, with no nonzero error/counterexample marker.
- SAW: `Proof succeeded`, with no `Proof failed`.

If a success marker and a failure/inapplicability marker both appear, the
result is ambiguous and the cell is malformed. An empty or marker-free
`result.txt` is never green. A missing `alive2/` or `saw/` directory is
malformed (the README says absence is a gate failure; inapplicability must be
a recorded result).

### 3.3 Status derivation

| Cell evidence | Row status |
|---|---|
| Alive2 success + SAW success | `both-green` (at least one cell with both) |
| Alive2 success + SAW filed inapplicable | `alive2-green` |
| SAW success + Alive2 filed inapplicable | `saw-green` |
| Any red/ambiguous leg, or neither leg green | `gap` with `auto(cells): ...` note naming cell and leg outcomes |
| Both legs filed inapplicable + valid `unjudged_seam` declaration | `unjudged-seam` with note citing `DECISION-lax-ecdsa.md` and the finding |
| Malformed cell covering the row | row stays `planned`; exact path and schema error reported |
| No cell covers the row | no status change (normally `planned`) |

`unjudged-seam` is only auto-derived from an explicit `unjudged_seam:` front
matter declaration whose `notes.md` cites `docs/DECISION-lax-ecdsa.md` and a
finding id, and whose two tool legs are both filed inapplicable. A green or red
tool result with a seam declaration is malformed. Manual `gap`/`unjudged-seam`
filings for rows with no cell are preserved when they have a note; a filed
status with an empty note is reset to `planned` in both modes.

## 4. Tests performed in isolation (not evidence about the engines)

All fixtures were created under `/tmp/opencode/ledger-work/`. **No synthetic
cell was placed under `spec/equiv/cells/` and no synthetic status was written
into the real ledger.**

1. **Updater fixture.** Five cells: one both-green (SCR-073), one Alive2-green
   with a filed SAW inapplicability (SCR-075), one Alive2-green + SAW red
   (SCR-077), one malformed missing `trust_note` (SCR-074), one empty Alive2
   output (SCR-076). Result:
   `both-green=1, alive2-green=1, gap=1, planned=180`, blocked rows 074/076,
   exit 1 with exact malformed paths and the expected schema. Re-running
   `--check` reported `up to date`.
2. **Drift check.** Hand-changing SCR-073 to `planned` in a copy made
   `update_ledger.py --check` exit 1 and print `DRIFT` plus the row diff.
3. **False-green matrix guard.** Deleting `cells` from a both-green row made
   `build_matrix.py` exit 1 with
   `SCR-073: both-green but cells is empty (a green row must name at least one cell record)`
   and write no matrix.
4. **Coverage false-green guards.** In a copied tree:
   - green row with `cells: []` → issue
     `both-green without a non-empty cells list`;
   - gap row with `gap_note: null` → issue
     `gap without a non-empty gap_note`;
   - green row citing a cell that does not list the row → issues for missing
     `scr_rows` membership and missing tool success markers;
   - all 183 rows adjudicated → `strict: PASS`.
5. **Round trip.** `build_equiv_cells.py --ledger <copy>`:
   - bootstrap copy: byte-identical (sha256 unchanged) and `--check` up to date;
   - mutated copy with `status: gap`, `cells`, `alive2`, `saw`, `gap_note`:
     regeneration preserved all five fields and kept computed `summary`
     verbatim; `--check` up to date.
6. **Seam derivation.** A fixture with both legs filed inapplicable and an
   explicit `unjudged_seam:` declaration plus `notes.md` citing
   `DECISION-lax-ecdsa.md` and `F-TOOL-001` produced `unjudged-seam` with a
   note. Removing the finding id made the record malformed and left the row
   `planned`.

## 5. What remains red, and why

1. **All 183 SCR rows are `planned`.** There is no cell record yet. This is
   the correct E1-start state; the updater cannot and must not invent one.
2. **No proof-cell directories.** `cells/` contains only `README.md` and the
   REDTEAM-owned `_redteam/` directory (protocol, mutation tooling, mutants).
   CELLS-E1 owns the first stack-op records.
3. **One unpinned build.** `PINS.lock` still has `[rbitcoin] build = TODO`
   (the Core build pin is filled). `gate-ir-pin` fails on it independently of
   coverage.
4. **E0 triple red.** R still returns `UNKNOWN`; `make e0` prints
   `E0_TRIPLE_PENDING`. C and L are correct on all four tapes. No ledger
   action can fix this.
5. **Gate integration nuance.** `tools/gate_ir_pin.py` has its own coverage
   checks but does not call the stricter `coverage_report.py`. Wiring the
   authoritative gate into `gate-ir-pin` is a TOOLS change (outside this
   role's write scope); recommended command:
   `python3 results/scripts/coverage_report.py --strict`.
6. **Matrix honesty.** `results/matrix.md` currently reports 0 green and 183
   planned. It is generated from the ledger and will stay red until real
   cells land. It is not a placeholder claiming progress.

## 6. Handoff for CELLS-E1

1. Create `cells/<family>/<cell>/` using the schema in §3.1. Use
   `spec/equiv/cells/README.md` naming (`C-L-*`, `C-R-*`, `L-R-*`).
2. Put real raw tool output in `alive2/result.txt` and `saw/result.txt`. Do not
   write a success marker that the tool did not print. Record
   `certificate.sha256 = sha256(result.txt)` and the exact `run.sh`.
3. For a tool that cannot express the cell, write an `INAPPLICABLE:` line in
   its `result.txt` naming the blocking IR feature, and put the same feature
   plus an `F-TOOL-nnn` finding id in `notes.md`.
4. Do **not** edit `spec/db/equiv-cells.yaml` by hand. Run:
   ```sh
   python3 spec/equiv/results/scripts/update_ledger.py --from-cells
   python3 spec/equiv/results/scripts/coverage_report.py --strict
   python3 spec/equiv/results/scripts/build_matrix.py
   ```
5. If the updater reports a malformed record, fix the record at the exact
   path/schema named in stderr; the affected rows remain `planned` until then.
6. A row with a counterexample (red tool output) is a filed `gap`, not green.
   The auto note names the cell and leg outcomes; add a human finding in the
   owning area for triage.

## 7. Reproducibility statement

The ledger contains no timestamps or absolute paths. The matrix contains no
timestamps; it includes the sha256 of the ledger it was generated from.
`build_equiv_cells.py --check`, `update_ledger.py --check`, and
`build_matrix.py --check` are all clean on the delivered tree. All green
statuses in the real tree: none. All status changes made by this role: none.
