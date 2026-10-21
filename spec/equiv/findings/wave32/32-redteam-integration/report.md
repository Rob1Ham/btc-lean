# Wave 32 — `32-redteam-integration` independent audit

- **Task:** `32-redteam-integration` (friendly adversarial re-audit of the
  published LLVM-IR equivalence evidence)
- **PR head audited:** `805c8042f92d3bed909ca40219a4d21fc9150cc1`
  (`fix(equiv): drop absolute checkout fallback in mk_leaf.py`)
- **Evidence baseline cited by cells:** `4d62a97e551082a69b13f495365bff0a903b0c99`
  (cell front-matter `repo_head`)
- **Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **Contract hash (v3):**
  `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- **Date:** 2026-10-20
- **Mode:** read-only. No `cells/**/run.sh`, `make equiv`, or mutation driver
  was executed, because those scripts rewrite tracked `result.txt` /
  `certificate.sha256` files. No evidence, ledger, matrix, contract, or pin
  file was modified.

## Verdict

**Clean pass: NO.**

| Measure | Result |
|---|---|
| Published both-tool green SCR rows | 4 (`SCR-069`, `SCR-071`, `SCR-072`, `SCR-074`) |
| Rows closed with evidence verifiable at PR head | **0 / 4** |
| Rows semantically defensible as bounded witnesses | **2 / 4** (`SCR-069`, `SCR-071`) |
| Rows whose published coverage claim is too strong | **1 / 4** (`SCR-074`: `full` → `partial`) |
| Rows not exercised at all | **1 / 4** (`SCR-072`: false green) |
| Certificates re-verifying at PR head | **10 / 45** total; **1 / 34** tool certificates |
| Required mutation subsets met | **E1 only, partially**; E2 **0/4**, E3 **1/5**, E4 **1/5** |
| Promoted cells using `llvm_unsafe_assume_spec` | **none** (one disclosed use in the partial `e2-hash` cell) |

The infrastructure gates (`coverage_report.py --strict`, `build_matrix.py
--check`, `gate_ir_pin.py`, `update_ledger.py --check`) all pass. That is
consistent with the claims: those gates do **not** verify certificate
contents, mutation evidence, or semantic row coverage. Passing them is not a
clean pass for this task.

---

## 1. Scope and method

Worktree: `/tmp/opencode/wave32/32-redteam-integration`, branch
`wave32/32-redteam-integration`, clean at start and end apart from this
report.

Reviewed: `BRIEF`-level task requirements, `spec/equiv/results/STATUS.md`,
`docs/STATE.md`, `results/matrix.md`, `spec/db/equiv-cells.yaml`,
`spec/db/rules.yaml`, all 17 cell `spec.md` files and notes, the four rows'
`result.txt` / `certificate.sha256` files, `cells/_redteam/MUTATIONS.md`,
the eight `runs/*.md` reports, the eight mutant JSON records,
`run_mutant.py`, `update_ledger.py`, `gate_ir_pin.py`, and the control/arity
leaf sources.

A key distinction is maintained throughout:

- **Semantic overclaim** — the cell does not exercise what the row says
  (`SCR-072`, `SCR-074`).
- **Evidence-binding failure** — the cell may have exercised the row, but the
  certificate no longer verifies at the audited commit (all four rows).

These are separate defects and must not be collapsed.

---

## 2. SCR row table

| SCR | status | cell | proved | remains | blocker |
|---|---|---|---|---|---|
| **SCR-069** | green, bounded; certificate blocked | `control-flow/C-L-nop-return` | `OP_RETURN` closed witness returns packed `(result=0, error=3, n=0)`; Alive2 green and SAW `cell_op_return` succeeded | Nothing further for the row inside the declared bound (`flags=0`, depth ≤ 6); certificate must be regenerated at head | Cert manifest fails at head (`_tools/mk_leaf.py` hash stale; `build/twin_ops.h` absent) |
| **SCR-071** | green, bounded; certificate blocked | `control-flow/C-L-nop-return` | `OP_NOP1` and `OP_NOP4..OP_NOP10` closed witnesses return `1`; Alive2 green and SAW `cell_nop1` / `cell_nop4_to_10` succeeded | Nothing further for the row inside the declared bound; certificate must be regenerated at head | Same certificate binding failure |
| **SCR-072** | **FALSE GREEN → gap** | `control-flow/C-L-nop-return` | **Nothing for this row.** No `0xb1` (`CLTV`) or `0xb2` (`CSV`) execution exists in either leaf | A pre-activation `CLTV`/`CSV` case proving both are plain NOPs when `flags=0` | Cell dispatch omits `0xb1`/`0xb2`; the spec's `full` claim cites `interpreter.cpp:534-537,573-576` but executes neither branch |
| **SCR-074** | **overclaimed `full` → partial** | `stack-ops/C-L-arity` (ledger provenance wrongly points at `e1-stack/dup-order`) | 16 arity functions return the constant `ret i64 72` at `n=0`; Alive2 and SAW are green on that constant witness | Per-op threshold boundary (`n=k-1` fails, `n=k` succeeds), non-constant witness, and a proof sensitive to guard off-by-one | Alive2 sees two identical constants; an off-by-one threshold mutant survives. Ledger `alive2.cell` / `saw.cell` cite a **partial** cell |

**No row in the table has a tool certificate that re-verifies at PR head.**
`SCR-069` and `SCR-071` are defensible as *bounded closed witnesses*; they are
not defensible as *PR-head-verifiable evidence*.

---

## 3. Certificate audit at PR head

Commands and result:

```sh
cd /tmp/opencode/wave32/32-redteam-integration
pass=0; fail=0
while read -r c; do
  tmp=$(mktemp)
  sed "s#/home/ubuntu/btc-lean-public/#$PWD/#g" "$c" > "$tmp"
  if sha256sum -c "$tmp" >/dev/null 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); fi
  rm -f "$tmp"
done < <(find spec/equiv/cells -name certificate.sha256 | sort)
echo "pass=$pass fail=$fail"
```

```
HEAD-BOUND pass=10 fail=35 total=45
```

The `sed` is necessary because four manifests embed absolute
`/home/ubuntu/btc-lean-public/...` paths. Without rebinding they appear to
pass **against the producer tree**, not against the PR.

| Class | Total | Pass at head | Fail at head |
|---|---:|---:|---:|
| Alive2 tool certs | 17 | 1 | 16 |
| SAW tool certs | 17 | 0 | 17 |
| Behavior certs | 11 | 9 | 2 |
| **Total** | **45** | **10** | **35** |

Root causes:

1. **30 certificates cite the pre-PR `mk_leaf.py` hash.**
   Cert manifests record
   `dafb4080901010e6479e000b5796ab51966c7bea9e70b1a16b6bb35de24b14c5`;
   the file at PR head hashes to
   `709b50d0aefcdbe619341d3ab79fcbf3b02f16f64769a7f4cb60d5e23baf6cc8`.
   PR commit `805c804` changes only the absolute-checkout fallback in
   `mk_leaf.py` (one line). The change is semantics-neutral but hash-breaking.
2. **155 referenced `build/` artifacts are absent.** `build/` is gitignored
   and `git ls-files spec/equiv/cells | grep -c '/build/'` returns `0`.
   41 of 45 certificates reference at least one missing build path
   (`build/twin_ops.h`, `build/cell.cry`, `build/cell.saw`, etc.).
3. **Four manifests bind the producer tree, not the PR.** The `alive2` and
   `saw` manifests for `stack-ops/C-L-arity` and `checksig/C-L-checksig-empty`
   use absolute `/home/ubuntu/btc-lean-public/...` paths. After rebinding to
   the PR root, only `checksig/C-L-checksig-empty/alive2` still passes.
4. **All 45 certificates pass in `/home/ubuntu/btc-lean-public`.** The
   evidence was internally consistent there; it is not reproducible from the
   commit under review.

The only tool certificate that survives at head is
`cells/checksig/C-L-checksig-empty/alive2/certificate.sha256`. It is not
evidence for any of the four green rows.

`gate_ir_pin.py` does not help here; its own docstring records certificate
hash verification as a known TODO (`tools/gate_ir_pin.py:15`). Its `PASS`
means the pin/manifest shape is consistent, not that certificates verify.

---

## 4. Top defects

### F-32-01 — `SCR-072` is a false green (High)

`spec/db/rules.yaml:2770-2775` defines the row as:

```
summary: "without flags they are plain NOPs"
check: "CLTV/CSV as NOP pre-activation"
core_ref: interpreter.cpp:EvalScript:534-537,573-576
```

The cited cell
`cells/control-flow/C-L-nop-return/spec.md:22-25` claims
`scr_row_coverage: full`, arguing that "SCR-072's premise is flags=0, under
which those opcodes are plain NOPs." But the cell's leaves execute only
`OP_NOP`, `OP_NOP1`, `OP_NOP4..OP_NOP10`, and `OP_RETURN`:

- `cells/_tools/control/l_leaf.cpp:21-25` dispatches `0x61`, `0x6a`,
  `0xb0`, and `0xb3..0xb9`; it has **no `0xb1` or `0xb2` case**.
- `cells/_tools/control/c_leaf.cpp:48` documents and implements only
  `OP_NOP4..OP_NOP10`.
- The cell's source citations (`spec.md:28-31`) omit the very lines named by
  the rule (`534-537`, `573-576`).

So the row is not exercised, and a pre-activation `CLTV`/`CSV` dispatch bug
would not be caught. The ledger promotes `SCR-072` to `both-green` because it
shares the cell's certificate, not because the row has evidence. Required
fix: demote `SCR-072` to `gap`/`partial` until a `0xb1`/`0xb2` witness exists.

### F-32-02 — `SCR-074` is overclaimed as `full` (High)

`cells/stack-ops/C-L-arity/spec.md:14-16` fixes the precondition to **empty
main and alt stacks**, and `:29-32` calls the row `full` because every opcode
is "exercised at an empty stack (n=0)". That proves one underflow point per
op, not the per-op depth guard:

- Every function in `cells/_tools/arity/l_leaf.cpp` starts empty and returns
  the same packed constant. The Alive2 output is literally
  `ret i64 72` on both sides (e.g.
  `cells/stack-ops/C-L-arity/alive2/result.txt:8-17`).
- An off-by-one guard (`depth < k` → `depth < k+1`) still returns the same
  constant at `n=0` and **survives** the proof.
- The `full` claim needs boundary pairs (`n=k-1` fails, `n=k` succeeds) or a
  symbolic guard law. The spec explicitly says the success branches are
  "covered by the other E1 cells", but those cells do not establish the
  threshold either.
- `E1-arity.md` confirms the harness only ever uses `(0, 18, n=0)` for all 16
  functions.

Required fix: relabel `SCR-074` `partial` (bounded underflow witness) unless
a boundary-sensitive proof is added. The row text ("each op checks depth")
is not established by one constant witness per op.

### F-32-03 — Certificate binding fails at the audited commit (High)

35/45 certificates fail at `805c804`; 33/34 tool certificates fail. Details
in §3. The evidence is only reproducible in the producer tree. For a PR
audit, a certificate that cannot be checked out and re-verified at the PR is
not evidence at the PR.

Required fix: either regenerate and commit the build inputs and certificate
manifests at the PR head, or record in `STATUS`/`matrix` that certificates
are producer-tree-only and cannot be re-verified from the commit. Do not
describe the suite as verified at `805c804` while 35 manifests fail.

### F-32-04 — Mutation evidence is not preserved and the required subsets are unmet (High)

`cells/_redteam/runs/` contains eight reports. **Six** of them have a
self-contradictory body: the header says `KILLED`, while the preserved
"Mutant result tails" end in `STATUS=alive2-green`. This is caused by
`run_mutant.py:151,156` reading `result.txt` **after** the baseline re-run
(the revert happens in the `finally` block at `run_mutant.py:114-116`, and
the tails are rendered from the post-revert file).

- Contradictory: `M-E1-001` (twin), `M-E1-001` (core-copy), `M-E1-002`,
  `M-E1-006`, `M-E1-008`, `M-E2-010`.
- Genuinely non-green tails: `M-E3-008`, `M-E4-004`.

All eight mutant JSON records under `cells/_redteam/mutants/` have
`outcome=pending`, `observed=null`, `operator=null`, and `log_hashes=[]`;
the verdict exists only in the hand-written report header.

Required subsets from `cells/_redteam/MUTATIONS.md:186-192`:

| Milestone | Required | Executed required | Status |
|---|---|---:|---|
| E1 | `M-E1-001` + one model-site + one core-copy (≥3 distinct) | 4 distinct (`001` twin/core-copy, `002`, `006`, `008`) | Met in count; preserved evidence incomplete |
| E2 | `001`, `002`, `005`, + one of `003/004/008/009` | **0 / 4** | **Unmet** (`M-E2-010` is OP_RETURN, not an E2 required mutant) |
| E3 | `001`, `002`, `003`, `008`, + one of `004-007` | **1 / 5** (`008`) | **Unmet** |
| E4 | `001`, `002`, `003`, `004`, `007` | **1 / 5** (`004`) | **Unmet** |

Independent raw logs under `findings/cells/mutations/raw/` do support
non-green mutant output for `M-E1-001` (twin and core-slice), `002`, `003`,
`004`, `006`, and `007`. `M-E1-005` was not run; the core application is a
line-cited slice, not a full Core rebuild. There is no independent raw log
for `M-E1-008`.

Despite this, `findings/redteam/redteam-report.md:254-257` says
"**Result:** PASS for the E1/E2/E3/E4 mutation requirement ... all killed by
both tools". That statement is not supported by the preserved artifacts and
must be withdrawn or narrowed.

### F-32-05 — Ledger provenance selects a partial cell for `SCR-074` (Medium)

`results/scripts/update_ledger.py:748-749` chooses `both[0]` from the
`row_cells` list. For `SCR-074`, the cell order is
`e1-stack/dup-order`, `e1-stack/rot-direction`, `e1-stack/swap-order`,
`stack-ops/C-L-arity`, `stack/C-L-dup-drop-swap`, so the ledger records the
**partial** `e1-stack/dup-order` as the `alive2.cell` and `saw.cell`
(`spec/db/equiv-cells.yaml`, `SCR-074`), even though
`stack-ops/C-L-arity` is the only cell claiming `full`.

The row's `both-green` status happens to be legitimate because *some* cell
is both-green, but the cited evidence pointer does not correspond to the
cell that justifies `full` coverage. A reader following the ledger lands on a
cell whose own spec (`e1-stack/dup-order/spec.md:26-27`) says the
depth-failure branch of `SCR-074` is **not** exercised.

### F-32-06 — `llvm_unsafe_assume_spec` in the E2 hash cell (Low / disclosed)

`cells/e2-hash/hash160-vector/src/cell.saw:20,23` uses
`llvm_unsafe_assume_spec` for `hash160` on both modules. It is disclosed in
`cells/e2-hash/hash160-vector/notes.md:62` and `findings/e2/report.md:49`,
and the cell is partial, not one of the four promoted rows. There is **no**
`llvm_unsafe_assume_spec` in the control-flow, arity, E1-stack, or stack
cells. No promoted-cell acceptance depends on it.

### F-32-07 — Documentation overstates the mutation and cell counts (Medium)

- `docs/STATE.md:38` says "8 mutation runs, 7 distinct IDs, all killed". The
  eight reports include six self-contradictory tails and eight pending JSON
  records; the required E2/E3/E4 subsets are unmet.
- `docs/STATE.md:78` says "The other 17 cell directories are recorded and
  tool-green" while `STATUS.md` reports 17 total cells and 4 green rows.
  The "other 17" count is inconsistent with the 17-cell suite (15
  non-promoted cells).
- `results/STATUS.md:44` lists `SCR-072` as green; see F-32-01.
- `findings/redteam/redteam-report.md:254` claims a PASS; see F-32-04.

### F-32-08 — Generated-file checks do not cover the defects (Informational)

`coverage_report.py --strict`, `build_matrix.py --check`, and
`update_ledger.py --check` are internally consistent, but they check
adjudication shape and sheet equality. They do not check that a `full` claim
is semantically earned, that a certificate verifies, or that mutation records
are non-pending. `gate_ir_pin.py` passes with 17 cells and 0 failures while
35/45 certificates fail. This is expected given the tool docstrings, but the
`STATUS` prose should not let a reader infer otherwise.

---

## 5. Integration checklist

| Check | Command | Result |
|---|---|---|
| Head identity | `git rev-parse HEAD` | `805c8042f92d3bed909ca40219a4d21fc9150cc1` |
| Contract hash | `{ cat contract/ABI.md; cat contract/tape.md; cat contract/error_kind.h; cat contract/corpus_schema.md; cat contract/error_enum.md; } \| sha256sum` | `f1841e36…c7773c1c6` — **match** |
| Ledger hash | `sha256sum spec/db/equiv-cells.yaml` | `62d8b6f4…d99616` — **matches `matrix.md`** |
| Coverage | `python3 results/scripts/coverage_report.py --strict` | **PASS**: 183 rows, 4 green, 20 seam, 159 gap, 0 planned; 17 cells, 0 malformed |
| Matrix freshness | `python3 results/scripts/build_matrix.py --check` | `results/matrix.md: up to date` |
| Pin gate | `python3 tools/gate_ir_pin.py` | **PASS**: 17 cells, 0 failures, 0 warnings |
| Ledger freshness | `python3 results/scripts/update_ledger.py --check` | `changes: 0`; `up to date`; 2 family-name warnings |
| Certificate re-verification at head | rebinding loop in §3 | **FAIL**: 35/45 (33/34 tool) |
| Mutation required subsets | manual audit of `runs/` + `mutants/` | **FAIL**: E2 0/4, E3 1/5, E4 1/5 |
| Unsafe-assume scan (promoted cells) | `grep -rn llvm_unsafe_assume_spec cells/{control-flow,stack-ops,e1-stack,stack}` | **clean** (no hits) |
| Generated files / ledger consistency | matrix + ledger + coverage | internally consistent; provenance pointer wrong for `SCR-074` (F-32-05) |

`update_ledger.py --check` warnings (non-blocking, but relevant to the
"17 cells" bookkeeping):

```
WARN e3-cms/C-L-cms-1of1/: family directory 'e3-cms' is not in cells/README.md or the ledger family list
WARN e4-witness/C-L-witness-v0-dispatch/: family directory 'e4-witness' is not in cells/README.md or the ledger family list
```

---

## 6. What would change the verdict

Minimum work to make these four rows defensible at PR head:

1. **`SCR-072`:** add `0xb1`/`0xb2` dispatch and a pre-activation NOP witness
   in both leaves; cite `interpreter.cpp:534-537,573-576`; regenerate
   Alive2/SAW evidence and the certificate. Until then, demote to `gap`.
2. **`SCR-074`:** either relabel `partial`, or add boundary-sensitive
   witnesses (`n=k-1` fail / `n=k` success) whose IR is not constant-folded,
   plus a threshold mutant that is actually killed.
3. **Certificates:** regenerate at `805c804` (or commit the build inputs),
   remove absolute producer paths, and re-verify 45/45 from the PR checkout.
4. **Mutations:** repair `run_mutant.py` to snapshot the mutant tail before
   revert, write `outcome`/`observed`/`operator`/`log_hashes` into the JSON,
   and execute the E2/E3/E4 required subsets. Withdraw the current PASS line.
5. **Ledger:** make `update_ledger.py` prefer a `full` both-green cell, not
   `both[0]`; re-derive and re-check `SCR-074`.
6. **Docs:** correct `STATE.md` ("8 runs all killed", "other 17") and the
   `STATUS.md` green-row list.

---

## 7. Exact commands used

```sh
# head / hashes
git rev-parse HEAD
sha256sum spec/db/equiv-cells.yaml
cd spec/equiv
{ cat contract/ABI.md; cat contract/tape.md; cat contract/error_kind.h; \
  cat contract/corpus_schema.md; cat contract/error_enum.md; } | sha256sum

# gates
python3 results/scripts/coverage_report.py --strict
python3 results/scripts/build_matrix.py --check
python3 tools/gate_ir_pin.py
python3 results/scripts/update_ledger.py --check

# certificate audit (head-bound; rewrites absolute producer paths in a temp copy)
cd /tmp/opencode/wave32/32-redteam-integration
pass=0; fail=0
while read -r c; do
  tmp=$(mktemp)
  sed "s#/home/ubuntu/btc-lean-public/#$PWD/#g" "$c" > "$tmp"
  if sha256sum -c "$tmp" >/dev/null 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); fi
  rm -f "$tmp"
done < <(find spec/equiv/cells -name certificate.sha256 | sort)
echo "pass=$pass fail=$fail"

# certificate audit in the producer tree (all pass)
cd /home/ubuntu/btc-lean-public
for c in $(find spec/equiv/cells -name certificate.sha256 | sort); do
  sha256sum -c "$c" >/dev/null 2>&1 && echo PASS || echo FAIL
done | sort | uniq -c

# semantic checks
grep -n "0xb1\|0xb2\|CLTV\|CSV" spec/equiv/cells/_tools/control/{l,c}_leaf.cpp
grep -n "ret i64 72" spec/equiv/cells/stack-ops/C-L-arity/alive2/result.txt
grep -rn "llvm_unsafe_assume_spec" spec/equiv/cells/{control-flow,stack-ops,e1-stack,stack}
```

No cell runner was executed. `result.txt` and `certificate.sha256` are
tracked outputs of those runners; running them in place would have destroyed
the artifacts under audit.

---

## 8. Bottom line

The suite is internally tidy and the tool gates are green, but the published
four-row green claim is not supported end-to-end:

- `SCR-072` is green on a cell that never executes `CLTV`/`CSV`.
- `SCR-074` is called `full` on constant-folded empty-stack witnesses that
  cannot distinguish an off-by-one guard.
- `SCR-069`/`SCR-071` are defensible bounded witnesses, but their
  certificates do not verify at the PR head.
- The mutation PASS line is not supported by the preserved records, and the
  E2/E3/E4 required subsets are largely unexecuted.

**Recommendation: do not accept `32-redteam-integration` as a clean pass.**
Accept `SCR-069`/`SCR-071` as bounded witnesses subject to certificate
regeneration; demote `SCR-072` to gap and `SCR-074` to partial; withdraw the
mutation PASS claim.
