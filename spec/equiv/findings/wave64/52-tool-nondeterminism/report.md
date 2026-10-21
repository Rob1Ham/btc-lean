# Wave 64 / 52 — tool nondeterminism in the SAW + Alive2 equivalence stack

**Status:** complete, findings only. No cell was modified.
**Branch:** `wave64/52-tool-nondeterminism` (base `5946c02`).
**Probe:** [`probe/`](probe/) — 137 repeated runs + 6 `--smt-stats` runs, executed
2026-10-20 22:24–22:50 UTC on a 16-vCPU host shared with other wave-64 agents.

## Question

Which observed "green" results in `spec/equiv/cells` are properties of the C/Lean
pair, and which are properties of the solver and runner flags? Concretely:

1. Does SAW `abc` terminate where `z3` does, and is the verdict solver-dependent?
2. Does Alive2 silently skip work on raw clang `-O1` IR, and does the 10 s default
   SMT budget change verdicts run to run?
3. What runner flags make a green result stable and non-vacuous?

## Method

Three representative green cells were re-built from their checked-in sources with
the exact runner recipes and then run repeatedly. The cell directories were only
read; compilation and all outputs went to `probe/build/` and `probe/raw/`. This is
deliberate: invoking a cell's `run.sh` would overwrite its `result.txt` and
certificate.

| id | cell | why it is representative |
|---|---|---|
| A | `numeric/C-L-within-4byte` (SCR-089) | SAW `z3` green; prior evidence that `abc` does not terminate (>13 min) |
| B | `tapscript/C-L-w32-op-success-prescan` (SCR-153/154) | SAW `abc` green; prior Alive2 silent-skip finding on raw `-O1` |
| C | `exec-verify/C-L-w32-p2sh-stackcopy` (SCR-007) | SAW `z3` green; prior `abc` >300 s timeout |
| D | `wave32/27-tapscript-149-155` F-DIV probe | **control, not a cell**: the only checked-in pair that demonstrates Alive2's raw-`-O1` under-query |

Per run the probe records: parsed verdict, wall time, process exit code, SHA-256 of
the complete output, SAW proof counts, and Alive2 query / timeout / skip counts
(`--smt-stats`). SAW was repeated 5× with `z3` and 3× with `abc`; Alive2 4–8× per
flag set. Timeouts kill the whole process group.

Reproduce, from this directory:

```sh
./probe/build_pairs.sh          # read-only w.r.t. cells; writes probe/build/
python3 probe/run_matrix.py     # ~25 min; writes probe/raw/, results.json/csv
python3 probe/analyze.py        # writes probe/summary.md
python3 probe/static_audit.py   # writes probe/static_audit.csv
```

Tool pins (full hashes in `probe/build-info.txt`): Alive2 v20.0
(`Ubuntu LLVM version 20.1.2`), SAW 1.6 (`68eed5f`), system z3 4.8.12,
bundled z3 4.8.14, clang/LLVM 20.1.2.

## Results

### SAW, repeated runs

| cell | solver | n | verdicts | proofs | wall min / median / max (s) |
|---|---|---:|---|---|---|
| A | z3 | 5 | green ×5 | 2/2 | 3.80 / 4.07 / 4.30 |
| A | abc | 3 | **timeout ×3** | **0/2** | 60.10 / 60.10 / 60.11 (60 s cap) |
| B | z3 | 5 | green ×5 | 4/4 | 18.23 / 20.23 / 22.09 |
| B | abc | 3 | green ×3 | 4/4 | 48.27 / 49.62 / 62.11 |
| C | z3 | 5 | green ×5 | 2/2 | 1.97 / 2.06 / 2.48 |
| C | abc | 3 | **timeout ×3** | **1/2** | 60.15 / 60.16 / 60.19 (60 s cap) |

### Alive2, repeated runs

| cell | form | flags | n | verdicts | wall min / median / max (s) |
|---|---|---|---:|---|---|
| A | `opt -O2` | `--smt-to=120000` | 4 | correct ×4 | 15.87 / 19.69 / 20.54 |
| A | `opt -O2` | *(default 10 s, no `--always-verify`)* | 4 | **timeout ×4** | 10.21 / 10.27 / 10.34 |
| A | `opt -O2` | `--always-verify --smt-to=120000` | 4 | correct ×4 | 19.01 / 20.29 / 24.10 |
| A | `opt -O2` | `--always-verify --smt-to=10000` | 4 | **timeout ×4** | 10.20 / 10.56 / 11.37 |
| A | `opt -O2` | `--skip-smt` | 3 | **failed-to-prove ×3** | 0.06 / 0.11 / 0.11 |
| B | **raw `-O1`** | `--always-verify --smt-to=10000` | 8 | **correct ×5, timeout ×3** | 8.33 / 9.85 / 33.12 |
| B | **raw `-O1`** | *(default 10 s, no `--always-verify`)* | 6 | **correct ×4, timeout ×2** | 7.74 / 10.71 / 12.52 |
| B | raw `-O1` | `--always-verify --smt-to=30000` | 4 | correct ×4 | 8.44 / 11.09 / 12.61 |
| B | raw `-O1` | `--always-verify --smt-to=60000` | 4 | correct ×4 | 6.72 / 7.32 / 9.58 |
| B | `opt -O2` | `--always-verify --smt-to=60000` | 4 | correct ×4 | 4.95 / 6.72 / 8.23 |
| B | `opt -O2` | `--always-verify --smt-to=10000` | 6 | correct ×6 | 4.87 / 6.51 / 11.79 |
| B | `opt -O2` | *(default 10 s)* | 6 | correct ×6 | 3.47 / 4.65 / 35.23 |
| B | either | `--skip-smt` | 3 | **failed-to-prove ×3** | < 1.5 |
| C | raw `-O1` | *(default 10 s)* | 8 | correct ×8 | 0.12 / 0.40 / 1.01 |
| C | raw `-O1` | `--always-verify` | 8 | correct ×8 | 0.10 / 0.19 / 0.70 |
| C | raw `-O1` | `--always-verify --smt-to=120000` | 5 | correct ×5 | 0.10 / 0.12 / 0.15 |
| D | **raw `-O1`** | `--always-verify --smt-to=60000` | 8 | **correct ×8** (0.11–0.82 s) | — |
| D | `opt -O2` | `--always-verify --smt-to=60000` | 8 | **incorrect ×8** | 7.03 / 7.31 / 96.03 |

### SMT statistics (one shot each)

| cell | form | verdict | queries | per-query timeouts | skips |
|---|---|---|---:|---:|---:|
| A | canon | correct | 6 | 0 | 0 |
| B | raw | correct | 7 | 0 | 0 |
| B | opt | correct | 6 | 0 | 0 |
| C | raw | correct | 6 | 0 | 0 |
| D | raw | **correct** | **2** | 0 | 0 |
| D | opt | **incorrect** | **34** | 0 | 0 |

## Findings

### 1. Two SAW greens are solver-dependent: without `z3`, A and C never report

`abc` did not produce a single proof for A (0/2, 3/3 timeouts) or C (1/2, 3/3
timeouts) at a 60 s cap; prior wave-32 evidence has the same cells exceeding
13 min and 300 s. `z3` proves both in seconds, 5/5, with one unique output hash.
This is deterministic resource-bound behavior, not a verdict flip: `abc` is not
"wrong", it simply fails to be a decision procedure for these queries within any
practical budget. A green recorded from `abc` on such a cell would be a green
only because the runner did not bound or report the timeout.

B is the counter-example to a blanket "abc is broken" claim: `abc` and `z3` both
return green 3/3 and 5/5, with identical output. Medians differ by ~2.4× (49.6 s
vs 20.2 s), worst observed by ~3.4×. The verdict is solver-independent here; only
cost is.

### 2. Alive2's default 10 s budget is a verdict-changing flag, not a detail

For A, the default and an explicit 10 s budget both give 4/4 `ERROR: Timeout`.
The recorded cell uses `--smt-to=120000`, which gives 4/4 correct at 15.9–20.5 s.
The same query is therefore green only because the cell overrides the default:
the default timeout is shorter than the proof.

For B on raw `-O1`, 10 s gives **5 correct / 3 timeout** (8 runs); the default
gives **4 correct / 2 timeout** (6 runs). 30 s and 60 s give 4/4 correct. These
are true run-to-run verdict flips on identical inputs — the clearest
nondeterminism observed. Note that wall time can exceed the per-query budget
(33.1 s worst case at `--smt-to=10000`) because the budget applies per query.

### 3. Alive2 can return "correct" without doing the proof (control D)

On the raw clang `-O1` form, Alive2 reports `Transformation seems to be correct!`
8/8 in 0.11–0.82 s with **2 SMT queries**. On the same pair canonicalized with
`opt -O2` it reports `incorrect` 8/8 with **34 queries**. The pair is genuinely
non-equivalent: a concrete driver linked against the exact `probe/build/D` IR
(`probe/raw/D-driver/`) returns

```
probe_prescan_order(1, 02 00 00 00, tm=1, os=0, di=0) = 64   (C leg)
probe_prescan_order(1, 02 00 00 00, tm=1, os=0, di=0) = 32   (L leg)
```

So the raw-`-O1` "correct" is **unsound, deterministically vacuous**, not a
flaky timeout. `--always-verify` does *not* fix it on this shape; only the
`opt -O2` canonical form does. Any generic "run alive-tv on the clang IR" recipe
is exposed to this.

### 4. `--skip-smt` is never evidence

On every cell it changed the verdict to `failed-to-prove` (3/3 each), sometimes
after printing a vacuous-looking `correct` line. It must not appear in a green
recipe, including as a "fast pre-check".

### 5. Exit codes cannot gate any of this

`alive-tv` returned `0` for timeouts, for counterexamples, and for vacuous
skips. SAW's timeout is a runner-imposed kill, so `rc` is meaningful only if the
runner actually imposes one. Every green gate must parse the text and require
positive evidence: proof counts, `Num queries > 0`, `Num timeout = 0`,
`Num skips = 0`.

### 6. The static risk surface is much wider than the three probed cells

`probe/static_audit.csv` classifies all 141 cells with a recorded green in both
legs:

| property | count |
|---|---:|
| SAW green with `abc` | **114 / 141** |
| SAW green with `z3` | 27 / 141 |
| Alive2 green **without** `--always-verify` | **133 / 141** |
| Alive2 green on the default 10 s budget | **118 / 141** |

The 8 cells that use `--always-verify` are the tapscript siblings of B and four
`exec-verify` cells; C is not among them. The 23 cells that override 10 s mostly
use 60 s (10 cells) or 120–180 s (8 cells). The audit reads
records, not proofs, so these are exposure counts, not claims that 114 cells are
wrong. But it means the probe's three cells are not unusual: the default posture
of the corpus is a solver and budget that this audit shows can change or withhold
a verdict.

## What each green depends on

| green | depends on | stable? |
|---|---|---|
| A SAW | solver = `z3` | yes; `abc` never reports |
| B SAW | either solver; `abc` needs a bound > ~62 s | yes in verdict, `abc` ~2.4× slower |
| C SAW | solver = `z3` | yes; `abc` never reports |
| A Alive2 | `--smt-to >= ~120000` | yes at 120 s, timeout at 10 s |
| B Alive2 (opt) | `opt -O2`, budget >= ~30 s | yes at 30/60 s |
| B Alive2 (raw) | luck at 10 s | **no: 5/8 or 4/6 correct, rest timeout** |
| C Alive2 | nothing special | yes, 0.1–1.0 s at every flag set |
| D Alive2 (raw) | — | **"correct" is unsound** (2 vs 34 queries) |

## Recommendations

### Alive2 runner (apply to all 141 legs)

```sh
opt -O2 -S pair.ll -o pair.opt.ll          # canonicalize raw clang -O1
timeout 600 alive-tv --always-verify --smt-to=300000 --smt-stats \
  c.opt.ll l.opt.ll
```

- Keep `--always-verify`: without it, 133/141 recorded legs are not even asking
  the question.
- Use a generous per-query budget (300 s) and a *separate* process timeout.
- Gate green on parsed text: `1 correct transformations`, `0 incorrect`,
  `0 failed-to-prove`, `Num queries > 0`, `Num timeout: 0`, `Num skips: 0`.
  Never on exit code, and never on `--skip-smt`.
- Canonicalize with `opt -O2` **before** verification, and keep a mutation check
  (flip a return constant; the run must go red). Control D shows that
  `--always-verify` alone does not protect against the raw-`-O1` under-query.
- Record `--smt-stats` in the certificate so a `queries=2` result is visible.

### SAW runner

```sh
timeout 900 saw --detect-vacuity -s summary.json cell.saw
```

- Pin `z3` explicitly for numeric/exec-style queries (A, C). Treat `abc` runs
  with a hard `timeout` and classify a kill as **non-result**, never green.
- If `abc` coverage is wanted (e.g. B), run it as a second opinion with a bound
  above the observed worst case and report both. Do not let an `abc` timeout
  stand in for a failed proof.
- Use `--detect-vacuity` and `-s` so contradictory assumptions and the summary
  are recorded rather than inferred from log text.
- Require `Proof succeeded!` count == expected and zero `Proof failed`; do not
  treat a killed process as success.

### Corpus hygiene

- Add a CI check that every `alive2/result.txt` contains an explicit
  `--smt-to` and `--always-verify`, and every `saw/result.txt` contains an
  explicit solver. The 114-abc / 118-default-10s counts are mechanical to fix.
- Store the full Alive2 summary block (queries, timeouts, skips) in the
  certificate, not only the final phrase.
- Do not promote a cell from "timeout" to "green" by raising a budget without
  also re-running the mutation check: a higher budget can turn a silent skip
  into a *sound* timeout or counterexample.

## Limitations

- Three cells plus one control; the static audit covers all 141 green cells but
  only reads their records.
- Wall times include co-tenant load from other wave-64 agents. Verdict counts
  are the primary result; timing spreads are upper bounds on intrinsic variance.
- SAW `abc` was capped at 60 s. Prior evidence (>13 min, >300 s) is consistent
  with nontermination but the probe does not prove it.
- The report does not re-verify the 141 recorded greens; it quantifies the
  flags they used and demonstrates the failure modes on representative inputs.

## Evidence map

| path | contents |
|---|---|
| `probe/results.json` | every run: verdict, wall, rc, output hash, query/timeout/skip counts |
| `probe/results.csv` | flat per-run table |
| `probe/summary.md` | generated variance tables and flip list |
| `probe/static_audit.csv` | all 141 green cells with solver and Alive2 flags/budget |
| `probe/raw/<experiment>/runNN.log` | unmodified tool output per run |
| `probe/raw/D-driver/` | concrete driver source + `build.sh`, `64` vs `32` outputs, hashes |
| `probe/build-info.txt` | tool versions, source SHA-256s, built IR SHA-256s |
| `probe/build_pairs.sh`, `run_matrix.py`, `analyze.py`, `static_audit.py` | reproducibility |
