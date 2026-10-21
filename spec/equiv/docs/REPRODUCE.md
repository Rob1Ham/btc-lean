# REPRODUCE — evaluator command book

**Snapshot:** `2026-10-21` (post-wave65 audit correction)
**Tree:** `/home/ubuntu/btc-lean-public/spec/equiv/`
**Rule:** every command block below was run at this snapshot; the quoted output
is from the actual run, not reconstructed.

All commands assume:

```sh
cd /home/ubuntu/btc-lean-public/spec/equiv
```

Bitcode under `/tmp/opencode/equiv-work/` is regenerable and deliberately not
tracked. `spec/equiv/` itself is untracked in the surrounding repo; all changes
remain uncommitted by instruction.

---

## 1. The acceptance commands

### 1.1 Pins

```sh
make pins; echo "rc=$?"
```

Observed:

```
Installed tool probes:
  OK  alive-tv: Ubuntu LLVM version 20.1.2 | Optimized build.
  OK  saw: 1.6 (68eed5f release-1.6)
  OK  z3: Z3 version 4.8.12 - 64 bit
  OK  cvc5: This is cvc5 version 1.3.1 [git ea1b484fa on branch HEAD]

RESULT: OK (pins complete and tool probes passed)
rc=0
```

Pins are complete. This does **not** make the R proof lane admissible: the
ingestible lane is rustc 1.88 / LLVM 20.1.5, explicitly NON-PIN, and Alive2
rejects the pinned 1.95 IR (`F-TOOL-001`). The behavioral R shim is real.

### 1.2 E0 triple

```sh
make e0; echo "rc=$?"
```

Observed:

```
== E0 tool probes ==
  PASS  alive2 positive
  PASS  alive2 negative
  PASS  saw positive

== three-leg E0 shims ==
  C: present: entry.cpp
  L: present: entry.cpp
  R: present: entry.rs
  triple script: GREEN (rc=0)

== summary ==
  TOOLS probes: GREEN
  Three-leg hello-world: GREEN
  RESULT: PASS
rc=0
```

`results/e0/run-triple.txt` records the four tapes:

```
[PASS] OP_1 passes:      C=(1,0) L=(1,0) R=(1,0) want=(1,0)
[PASS] OP_0 fails:       C=(0,2) L=(0,2) R=(0,2) want=(0,2)
[PASS] OP_RETURN fails:  C=(0,3) L=(0,3) R=(0,3) want=(0,3)
[PASS] empty tx bad input: C=(2,1) L=(2,1) R=(2,1) want=(2,1)
E0_TRIPLE_OK
```

This is a harness/ABI gate, not an IR proof: C is a g++ 13.3 behavior build
with test-only file-I/O stubs; L is `twin/build/libtwin.so`; R is the clean
1.95 public-API shim. `shims/twin/entry.cpp` is still a stub and is bypassed.

### 1.3 Pin/coverage gate

```sh
make gate-ir-pin; echo "rc=$?"
```

Observed:

```
== 1. PINS.lock ==
OK    all required pins are filled

== 2. cell records ==
  cell directories: 17; with a record file: 17

== 3. SCR coverage ==
  SCR rows in rules.yaml: 183
  rows in equiv-cells.yaml: 183
  status counts: both-green=152, gap=29, unjudged-seam=2
OK    all 183 SCR rows adjudicated

== summary ==
  cell records: 17
  failures: 0; warnings: 0
RESULT: PASS
rc=0
```

### 1.4 Cell suite and matrix

```sh
make equiv; echo "rc=$?"
```

Observed:

```
summary: 17 cell(s) with >=1 green tool, 0 red, 0 TODO
wrote /home/ubuntu/btc-lean-public/spec/equiv/results/matrix.md
rc=0
```

`tools/run_equiv.py` runs each cell's Alive2 and SAW runner, reads
`result.txt`, ignores runner `#` annotations, and skips auxiliary dirs
(`alive2/`, `saw/`, `build/`, `logs/`, `witnesses/`, `behavior/`, `_tools/`,
`_redteam/`). Both tools are attempted on every recorded cell.

### 1.5 Ledger and strict coverage

```sh
python3 results/scripts/update_ledger.py --check; echo "rc=$?"
python3 results/scripts/coverage_report.py --strict; echo "rc=$?"
python3 results/scripts/build_matrix.py --check; echo "rc=$?"
```

Observed:

```
statuses: planned=0, alive2-green=0, saw-green=0, both-green=4,
          unjudged-seam=2, gap=29
green rows: 4; blocked rows: 0
check: .../spec/db/equiv-cells.yaml is up to date
rc=0

cell records scanned: 17 (malformed: 0)
strict: PASS - all 183 SCR rows adjudicated (green, unjudged-seam, or filed gap)
rc=0

.../results/matrix.md: up to date
rc=0
```

**Reading:** the suite is green at the tool level and the ledger is fully
adjudicated, but only 152 SCR rows are both-tool green. The remaining 2 are
unjudged seams and 29 are filed gaps; partial cells do not promote rows.

---

## 2. Contract binding

```sh
{ cat contract/ABI.md; cat contract/tape.md; \
  cat contract/error_kind.h; cat contract/corpus_schema.md; \
  cat contract/error_enum.md; } | sha256sum
```

Observed:

```
f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6  -
```

This matches `PINS.lock [contract] hash` exactly. v3 includes
`error_enum.md`; v2 (`c2fcc67a…`) omitted it and is historical
(`contract/CHANGELOG.md`). Any contract edit invalidates cell records and
requires a re-pin.

---

## 3. Mutation test (representative)

The full catalogue and all eight run reports are in
`cells/_redteam/MUTATIONS.md` and `cells/_redteam/runs/`. A representative
E3 run:

```sh
python3 cells/_redteam/mutate.py \
  --target cells/_tools/e3/cellsig/l_cms.cpp \
  --mutation M-E3-008 --target-kind e3-cell
(cd cells/e3-cms/C-L-cms-1of1 && bash alive2/run.sh)
(cd cells/e3-cms/C-L-cms-1of1 && bash saw/run.sh)
python3 cells/_redteam/mutate.py --revert <record.json>
```

Observed: baseline Alive2 green / SAW 16/16; mutant Alive2 not-green on
`cell_cmsverify` (source `0x34`, target `0x18`) and SAW 11/16; after revert,
baseline green again. Full transcript:
`cells/_redteam/runs/M-E3-008-e3-cell-20261019T230115Z.md`.

The other killed mutants: M-E1-001 (twin and core-slice), M-E1-002, M-E1-006,
M-E1-008, M-E2-010, M-E4-004.

---

## 4. What the evaluator should not infer

- `make equiv` green means **every recorded cell has a raw tool success
  marker**, not that its SCR row is fully covered. Read `scr_row_coverage`.
- The authoritative green-row list is `results/matrix.md`; the ledger is
  152/2/29 after the wave65/32 audit correction.
- No whole-function `VerifyScript`/`EvalScript` proof exists. E5 is a scoped
  residual (`findings/e5/E5-RESIDUAL.md`); its one green empty-script SAW run
  is concolic/non-pin and is not a ledger row.
- No R proof lane at the pin; R behavioral E0 only (`F-TOOL-001`, B-03).
- Crypto/hash transforms are abstracted or concrete-witness only; the claim is
  conditional on same-crypto (`docs/DECISION-lax-ecdsa.md`).
- Core patches P-CORE-01/02/03 are PROPOSED and used by no green cell.
- The tree is untracked; results are reproducible from the working tree and
  pins, not from a commit.

---

## 5. Evidence index

- `results/STATUS.md` — current checkpoint.
- `results/matrix.md` — generated per-family matrix and named trust base.
- `findings/coverage/F-E6-GAPS.md` — every non-green row and disposition.
- `docs/STATE.md`, `docs/TRUST-BASE.md` — current state and premises.
- `findings/e2/report.md`, `findings/e3/report.md`, `findings/e4/report.md`
  — family attempts and limits.
- `findings/e5/E5-RESIDUAL.md`, `findings/e5/F-TOOL-001.md` — E5 blockers.
- `findings/ir/report.md`, `ir/manifest.json` — IR closure and hashes.
- `findings/evaluator/audit.md` §13 — post-snapshot addendum.
