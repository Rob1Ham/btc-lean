# EVALUATOR AUDIT — three-leg LLVM IR equivalence workstream

**Snapshot:** `2026-10-19T22:37:00Z`
**Tree:** `/home/ubuntu/btc-lean-public/spec/equiv/`
**Role:** independent evaluator. This page audits artifacts; it does not
improve them. Every finding names the owner file and what would clear it.
**Snapshot discipline:** the tree moved throughout the audit. Findings are
against the hashes in §9. Re-hash before citing.

---

## 1. Summary

| Severity | Active | Resolved (kept for ID stability) |
|---|---:|---:|
| blocks evaluation | 8 | 2 (B-02, B-07) |
| misleading | 13 | 3 (M-04, M-12, M-13) |
| cosmetic | 9 | 0 |

No finding is a fabricated tool result. The active defects are:

- **missing work**: no engine proof, no R proof lane, no redteam mutants, no
  ledger-green row;
- **one real gate defect**: `make equiv` parses runner stdout while the cell
  runners write `result.txt` (B-10);
- **one contract-binding hole**: `error_enum.md` is versioning but excluded
  from the hash recipe (B-06);
- **provenance/labelling gaps**: `PINS.lock` pins the R `.so` under the source
  key (M-15), the differential hard-codes a false R-block reason (M-16), and
  several role reports are stale;
- **reproducibility gap**: `spec/equiv/` is untracked (B-08).

The honest headline is: **E0 harness/ABI passes, six bounded leaves are
raw-green, the current behavioral differential is clean, and nothing is
engine-proved or ledger-green.**

---

## 2. Blocks evaluation

### B-01 — Zero ledger-green rows; bounded leaves cover only partial SCR rows

**Severity:** blocks evaluation
**Evidence:**

- `make gate-ir-pin` (rc 2): `cell directories: 6; with a record file: 6`,
  `status counts: gap=5, planned=178`,
  `FAIL coverage incomplete: 5/183 SCR rows adjudicated`.
- `python3 results/scripts/coverage_report.py --strict` (rc 1):
  `TOTAL 183 0 178 0 5 0`, `cell records scanned: 6 (malformed: 0)`.
- `python3 results/scripts/update_ledger.py --check` (rc 0):
  `cells scanned: 6 (valid 6, malformed 0)`, `planned=178`, `gap=5`,
  `green rows: 0`, `changes: 0`.
- The six cells are real and their raw markers are green:
  `cells/e1-stack/{swap-order,dup-order,rot-direction,depth-count,pick-depth}`
  and `cells/e1-altstack/roundtrip` each have `alive2/result.txt`
  (`1 correct transformations`, `0 Alive2 errors`), `saw/result.txt`
  (`Proof succeeded!`), and `behavior/result.txt` (`C=(1,0)`, `L=(1,0)`).
  All 18 result/certificate pairs verify by sha256.
- The updater correctly refuses to promote partial coverage: five SCR rows
  carry `status: gap` plus a `gap_note` (e.g. `spec/db/equiv-cells.yaml:867-877`,
  SCR-073: "partial success branch only").
- `results/matrix.md` is current: 0 green, 5 gap, 178 planned.

**Why it blocks:** the central claim has no adjudicated green instance. The
six leaves exercise bounded op slices, not the SCR rows in full; a `gap` is an
honest adjudication but it is not equivalence evidence.

**Owner:** `CELLS` (widen leaves or keep explicit gaps), `LEDGER`
(`spec/db/equiv-cells.yaml`, `results/matrix.md`).

**Would clear it:** either promote at least one row to `both-green` with full
row coverage, or accept the gap-partition as the E1 outcome and make the gate
count filed gaps as adjudicated (while keeping "0 green" explicit).

---

### B-03 — No admissible R proof-lane artifact; the ingestible lane is off-pin

**Severity:** blocks evaluation (as R proof evidence)
**Evidence:**

- The R **behavioral** lane is now real and clean: `shims/rust/build.sh`
  builds from `equiv-work/rbitcoin-clean` at
  `ae47aa98174e04d0d8c493f13041daf65e4ac1d3` (verified clean) with rustc
  1.95.0. The `.so` is `73e3d2d9…` and rebuilds byte-identically. This part is
  resolved and is not the blocker.
- `PINS.lock [rbitcoin] ir_toolchain` says the clean proof lane is rustc
  **1.88.0 / LLVM 20.1.5**, a **NON-PIN front-end**, "required because Alive2
  v20 rejects LLVM 22/23 IR".
- `findings/rust/artifacts.md` records the pinned 1.95 IR failing at
  `dead_on_return`; the LLVM 23 IR also fails. Alive2 cannot ingest the pin.
- SAW 1.6 can ingest rustc 1.95 bitcode (the E0 `add_one` leaf passes), but
  there is no SAW spec for the rbitcoin engine path.
- The differential does not run R: `r_leg.status = blocked`,
  `rows_blocked = 1258`.
- The dirty `equiv-work/rbitcoin` checkout (4 files, +247) is a proposal lane,
  not the source of the official `.so`; it must not be cited.

**Why it blocks:** no R artifact is simultaneously at the pin, engine-level,
and ingestible by the proof tools. The behavioral shim is boundary-limited
(one input, flags 0, narrow error map).

**Owner:** `RUST-IR` (proof artifact or explicit gap filing), `PINS`
(provenance wording), `DIFFERENTIAL` (integrate R or state the omission).

**Would clear it:** an ingestible pinned-rustc proof artifact, or a filed
`unjudged-seam` that names the 1.88/LLVM-20.1.5 concession and is accepted by
the ledger; plus an R row in the differential (or an explicit reason it is out
of scope).

---

### B-04 — No engine proof; only bounded leaves and self-comparisons

**Severity:** blocks evaluation
**Evidence:**

- Six E1 cells prove bounded C-vs-L op slices with Alive2 and closed-witness
  constants with SAW; two Core leaves (`CastToBool`, `operator|`) are proved.
  None covers `EvalScript` / `VerifyScript`.
- `findings/core/core-ir-report.md` §10 states the engine limit: the erased
  `EvalScript`/`VerifyScript` Alive2 runs are `--skip-smt` self-comparisons of
  the same module ("syntactically equal"), not equivalence to another
  implementation.
- No SAW `EvalScript`/`VerifyScript` spec exists; `saw20-load.log` only loads
  the module.
- Alive2 cannot translate the exception-carrying Core engine; the erased
  transform is domain-restricting.

**Why it blocks:** "three-leg equivalence" is not established at engine level.
The workstream may scope itself to bounded leaves, but then the claim must be
restated.

**Owner:** `CORE-IR` / `TOOLS` (engine spec), `CONTRACT` (claim scoping).

**Would clear it:** a machine-checked engine-level refinement (SAW invariants
or an accepted alternative), or a written scope reduction to bounded leaves
with the three-leg claim withdrawn.

---

### B-05 — Core patches are PROPOSED with no differential; devirt seam missing

**Severity:** blocks evaluation (for any cell citing patched IR)
**Evidence:**

- `patches/core/P-CORE-01`, `-02`, `-03` all apply cleanly
  (`git apply --check` rc 0 for each) against the clean Core pin.
- `patches/core/README.md` and `findings/core/findings-ledger.md` record them
  as PROPOSED; no behavioral differential exists.
- P-CORE-01 changes the non-throwing ScriptNum path; the empty-stack path is
  not equivalent.
- P-CORE-02 devirtualizes six checker call sites but has no linking shim
  (`findings/core/handoff-contract-pcore02.md`, open).
- P-CORE-03 changes static-init behavior; no differential.
- The exception-erasure transform is derived and domain-restricting.

**Why it blocks:** a cell may not cite patched/erased IR as equivalent until
the transform is behaviorally validated and the seam is linked.

**Owner:** `CORE-IR` (`patches/core/`, `findings/core/`).

**Would clear it:** differential runs for each patch, a P-CORE-02 linking
shim, or an explicit decision to keep all cells on unpatched IR.

---

### B-06 — The contract hash does not bind `error_enum.md`

**Severity:** blocks evaluation (contract binding)
**Evidence:**

- `contract/ABI.md` §8 (`:121-123`): "A change to this file, `tape.md`,
  `error_enum.md`, or `error_kind.h` is a new contract version".
- `contract/tape.md` §10 (`:212-215`) recipe:
  `{ cat ABI.md; cat tape.md; cat error_kind.h; cat corpus_schema.md; } | sha256sum`.
- Recomputed recipe: `c2fcc67a…be4ff`. Including `error_enum.md`:
  `9794f28e…eff11d`.
- `PINS.lock [contract] hash` records only the four-file hash.

**Why it blocks:** a cell can cite a contract hash that is unchanged after a
semantic change to the error taxonomy. The hash is not a binding commitment to
the whole normative contract.

**Owner:** `CONTRACT` (`contract/ABI.md` §8 or `contract/tape.md` §10), then
`PINS.lock [contract]`.

**Would clear it:** add `error_enum.md` to the recipe (and re-pin), or remove
it from the versioning list.

---

### B-08 — `spec/equiv/` is untracked; artifacts cannot be fetched from a pin

**Severity:** blocks evaluation (outside reproducibility)
**Evidence:**

- `git -C /home/ubuntu/btc-lean-public status --short`:
  `?? spec/equiv/`; also `M README.md`, `?? spec/db/equiv-cells.yaml`.
- `git -C /home/ubuntu/btc-lean-public rev-parse HEAD` =
  `4d62a97e…`, the `model_rev`. None of the `spec/equiv/` files are in that
  commit.
- Bitcode is excluded and lives under `/tmp/opencode/equiv-work/`.

**Why it blocks:** an outside reviewer cannot `git archive` the claimed
artifacts, pins, cell records, or result hashes. The only copy is a mutable
working tree.

**Owner:** `ORCHESTRATOR` / repo maintainer.

**Would clear it:** commit `spec/equiv/` (and the ledger) at a stated HEAD, or
publish a hash-pinned archive with the same manifest.

---

### B-09 — Redteam has run zero mutants

**Severity:** blocks evaluation (E1 acceptance)
**Evidence:**

- `cells/_redteam/` contains only `PROTOCOL.md`, `MUTATIONS.md`, and
  `mutate.py` (3 files); no mutant result, score, or survivor record.
- `findings/redteam/redteam-report.md` documents a protocol, not runs.
- `README.md:179` calls E1 "mutation test" but no mutation has executed.

**Why it blocks:** E1's acceptance includes a mutation test; without it, the
six leaves have no adversarial check.

**Owner:** `REDTEAM` / `CELLS`.

**Would clear it:** execute the documented mutants against the cell suite and
record kills/survivors with hashes.

---

### B-10 — `make equiv` cannot see green cell results (runner/stdout mismatch)

**Severity:** blocks evaluation (the stated acceptance command is unusable)
**Evidence:**

- `tools/run_equiv.py:79-99` (`run_alive2`) executes `run.sh` and checks the
  **captured stdout** for `Transformation seems to be correct` and
  `0 incorrect transformations`.
- `tools/run_equiv.py:101-120` (`run_saw`) checks stdout for
  `Proof succeeded`.
- The cell runners redirect all tool output into `result.txt`; e.g.
  `cells/_tools/gate/run_alive2.sh` writes the `alive-tv` run to
  `$OUT/result.txt` and only appends `STATUS=alive2-green` there.
- Consequently `make equiv` reports `0 cell(s) with >=1 green tool, 6 red,
  3 TODO` (rc 2), while the same cells' `result.txt` files contain the success
  markers and `update_ledger.py --check` validates all six.

**Why it blocks:** the documented way to confirm cells reports red for green
evidence. A reviewer following `EVALUATION.md` gets the opposite answer from
the ledger.

**Owner:** `TOOLS` (`tools/run_equiv.py`) or `CELLS`
(`cells/_tools/gate/run_*.sh`).

**Would clear it:** either `tee` tool output to stdout in the runners, or make
`run_equiv.py` read `result.txt` when present; then `make equiv` should report
the six leaves as green (still not ledger-green; see B-01).

---

## 3. Misleading

### M-01 — The C "green" library is GCC 13.3 + test stubs, not pinned clang

**Severity:** misleading
**Evidence:** `/tmp/opencode/cbuild/libequiv-core.so` `.comment` says
`GCC: (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0`; it contains test-only
`FileCommit`/`TruncateFile` stubs; sha256 `5fef1df0…57fbb5`.
`results/e0/README.md` discloses this, so the defect is any downstream claim
that treats "C green" as IR evidence.
**Owner:** `CORE-IR` / `TOOLS` (or the citing report).
**Would clear it:** link the real Core objects with pinned clang and re-run, or
keep the "behavioral only" label on every citation.

### M-02 — `EVALUATION.md` says the gate checks "hashes"; it does not

**Severity:** misleading
**Evidence:** `EVALUATION.md:21`:
`make gate-ir-pin # pins + hashes + SCR coverage + no unfiled gaps`.
`tools/gate_ir_pin.py` §1 calls `check_pins` (version/presence) and §2 only
tests that a record file exists; it does not recompute contract/IR hashes.
`tools/check_pins.py` does not verify IR hashes either.
**Owner:** `TOOLS` (`EVALUATION.md`, `tools/gate_ir_pin.py`).
**Would clear it:** either implement hash recomputation in the gate, or change
the comment to "pins + records + coverage".

### M-03 — `check_pins.py` does not require the `[contract]` section

**Severity:** misleading
**Evidence:** `tools/check_pins.py:25-32` `REQUIRED` lists `core`, `rbitcoin`,
`lean`, `llvm`, `tools`; `contract` is absent. A `PINS.lock` with no
`[contract]` section would still pass the pin check.
**Owner:** `TOOLS` (`tools/check_pins.py`).
**Would clear it:** add `"contract": ["hash", "recipe"]` and verify the hash
against the recipe.

### M-05 — `LEDGER-REPORT.md` §5 is stale and one test claim is unlogged

**Severity:** misleading
**Evidence:**

- `results/LEDGER-REPORT.md:118-119`: "`PINS.lock` still has `TODO` for clang,
  LLVM version, Alive2, SAW, solvers, rbitcoin commit, and builds" — at
  snapshot there are no TODO pins and `make pins` rc 0.
- `:161-162`: "one `PINS.lock` build TODO (`[rbitcoin] build`), L/R E0 stubs,
  and the absence of cell records" — all three are false now (build filled, R
  behavioral shim live, six records).
- `:102-103` describes promoting `SCR-001`, but the E1 report describes
  `SCR-073`; no transcript for the `SCR-001` claim is in the tree.

**Owner:** `LEDGER` (`results/LEDGER-REPORT.md`).
**Would clear it:** mark §5 historical and rewrite the "still open" list.

### M-06 — `tooling-report.md` quotes stale pin/cell/gate details

**Severity:** misleading
**Evidence:** `findings/tools/tooling-report.md:91-96`:

- `python3 tools/run_e0.py` → `RESULT: PASS` is now true (E0 passes), but the
  note that it "deliberately does not execute" the shims is outdated: the
  strict triple now executes all three.
- `python3 tools/run_equiv.py` → `SKIP: no cells` is false: six cells exist
  and the runner reports 6 red/3 TODO.
- `check_pins.py --allow-todo` → "2 TODO pins" is false: 0 TODO.
- `gate_ir_pin.py --allow-todo` → "0 cell records, 0 adjudicated" is false:
  6 records, 5 gap + 178 planned.

**Owner:** `TOOLS` (`findings/tools/tooling-report.md`).
**Would clear it:** re-run the block and paste the current outputs.

### M-07 — `shims/README.md` still calls the R shim a stub at rustc 1.99

**Severity:** misleading
**Evidence:** `shims/README.md:153-154`: "Status: **stub** (returns 3 ...).
Verified to compile ... with rustc 1.99.0". The current `entry.rs` is a live
public-API shim (`1fd706b8…`) built with rustc 1.95.0; the `.so` is
`73e3d2d9…`. The L section (`:140`) correctly describes `shims/twin/entry.cpp`
as a stub, but readers conflate the two.
**Owner:** `SHIMS` / `RUST-IR` (`shims/README.md`).
**Would clear it:** update the R section to the 1.95 build and state that the
L stub is bypassed by the generated twin.

### M-08 — `differential/results/LEG-IDENTITY.md` quotes the old run

**Severity:** misleading
**Evidence:** `differential/results/LEG-IDENTITY.md` says the current recorded
run is `C~L_twin 854 agree / 0 disagree / 404 blocked` against `d560a5f6…`.
The current summary and re-run are `922 / 0 / 336` at `libtwin b9ed129b…`
/ IR `e5fbe727…`.
**Owner:** `DIFFERENTIAL` (`differential/results/LEG-IDENTITY.md`).
**Would clear it:** regenerate or update the recorded-run paragraph from
`summary.json`.

### M-09 — `orchestrator-crosschecks.md` still says L/R are stubs and E0 is pending

**Severity:** misleading
**Evidence:** `findings/verifications/orchestrator-crosschecks.md:189-192`:
"L and R are `(3, UNKNOWN)` stubs. `make e0` exits 2 with
`E0_TRIPLE_PENDING`." `:209-210` repeats the stub claim. Current: `make e0`
rc 0 / `RESULT: PASS`; R is a live 1.95 shim; L is the generated twin.
**Owner:** `ORCHESTRATOR` / `VERIFICATIONS`.
**Would clear it:** mark the section historical and add the current E0 result.

### M-10 — `make equiv` counts tool/scratch directories as cells

**Severity:** misleading
**Evidence:** `make equiv` scans nine directories: the six real cells plus
`cells/_redteam/mutants`, `cells/_tools/__pycache__`, and `cells/_tools/gate`,
and reports the latter three as `TODO: no alive2/ or saw/ runner present`.
`tools/gate_ir_pin.py` correctly skips underscore directories and sees six.
**Owner:** `TOOLS` (`tools/run_equiv.py`).
**Would clear it:** skip directories whose first path component starts with
`_`.

### M-11 — The documented R fallback ("Alive2-only") is backwards

**Severity:** misleading
**Evidence:** `README.md:89`: "if [LLVM skew] cannot be reconciled, the R leg
runs Alive2-only and the gap is filed." Alive2 is the tool that **cannot**
ingest the pinned Rust IR (`dead_on_return` / metadata kind 8); SAW is the tool
that can ingest 1.95 bitcode. The fallback as written selects the failing tool.
**Owner:** `README.md` (claim/plan), `RUST-IR`.
**Would clear it:** state the actual fallback (SAW with an engine spec, or a
filed gap), and keep Alive2 out of the pinned-Rust path.

### M-14 — `results/STATUS.md` still reports a build-pin TODO and an R stub

**Severity:** misleading
**Evidence:** `results/STATUS.md:81-83`: "fill the remaining `[rbitcoin] build`
pin TODO"; "replace the R stub so `make e0` prints `E0_TRIPLE_OK`". Both are
done: `make pins` rc 0, `make e0` rc 0 / `E0_TRIPLE_OK`, R `.so` `73e3d2d9…`.
The top paragraph (`:4-6`) correctly says E0 PASS and pins filled, so the page
contradicts itself.
**Owner:** `STATUS` / `TOOLS`.
**Would clear it:** replace the next-actions list with the current blockers
(ledger green, runner mismatch, contract binding, R proof lane, engine proof).

### M-15 — `PINS.lock abi_shim_sha256` labels the built `.so` hash under the source path

**Severity:** misleading (provenance)
**Evidence:** `PINS.lock`:

```
abi_shim = shims/rust/entry.rs
abi_shim_sha256 = 73e3d2d96de864e11e7cfb7cc5cc9fbba5d0dad1dc5de08b4cad6114ad1dffde
```

`sha256sum shims/rust/entry.rs` = `1fd706b8…5daa8837`, not `73e3d2d9…`;
`73e3d2d9…` is `shims/rust/build/libequiv-rust.so`. A reviewer hashing the
named source file gets a mismatch.
**Owner:** `PINS` / `RUST-IR`.
**Would clear it:** rename the key to `abi_shim_so_sha256`, add
`abi_shim_source_sha256 = 1fd706b8…`, or point `abi_shim` at the `.so`.

### M-16 — Differential `r_leg.reason` asserts a false R state

**Severity:** misleading
**Evidence:** `differential/run.py:97-102` hard-codes:
"R leg not run: no clean R shim exists (spec/equiv/shims/rust/entry.rs is a
STUB) and the rbitcoin worktree at ae47aa98 carries an unregistered FFI
patch." `differential/results/summary.json` reproduces it. Current: the clean
`rbitcoin-clean` checkout is clean, `entry.rs` is live, and the official `.so`
is built from it. The R leg is genuinely unrun, so `rows_blocked = 1258` is
correct; the reason is not.
**Owner:** `DIFFERENTIAL` (`differential/run.py`, `results/summary.json`).
**Would clear it:** replace the reason with "R leg not integrated in this
harness; behavioral shim exists at 73e3d2d9…" and record the real scope
decision.

---

## 4. Cosmetic

### C-01 — Wrong sentinel name in crosschecks

**Severity:** cosmetic
**Evidence:** `findings/verifications/orchestrator-crosschecks.md:27` says
`EQUIV_ERR_ERROR_COUNT = 55`; the header defines `EQUIV_ERR_COUNT = 55`.
**Owner:** `VERIFICATIONS`.
**Would clear it:** fix the name.

### C-02 — Stale open handoff for a resolved ABI issue

**Severity:** cosmetic
**Evidence:**
`findings/handoffs/orchestrator-to-CONTRACT-001-abi-signature.md:3`
says `status: open`; the ABI is now consistently 8-argument v2 in all three
shims and the contract.
**Owner:** `ORCHESTRATOR` / `CONTRACT`.
**Would clear it:** mark the handoff resolved with a pointer to the current
ABI text.

### C-03 — Capability matrix cites a 180 s timeout that is not in the log

**Severity:** cosmetic
**Evidence:** `tools/capability-matrix.md:19` says `saw-loop.out`: "180 s
timeout". `findings/tools/probes/saw-loop.out` is 65 bytes:
`Loading file "loop.saw"`, `Verifying sum_to...`, `Simulating sum_to...`; it
contains no timeout line.
**Owner:** `TOOLS`.
**Would clear it:** cite the actual timeout log or remove the duration.

### C-04 — `commands.md` duplicate `-fno-exceptions` line

**Severity:** cosmetic
**Evidence:** `findings/core/commands.md:89-90` contains:
`-DABORT_ON_FAILED_ASSUME` do not change the O0 hash. `-fno-exceptions`
`-fno-exceptions` emits 20 errors ...
**Owner:** `CORE-IR`.
**Would clear it:** delete the duplicated fragment.

### C-05 — SAW bitcode-ceiling statements disagree

**Severity:** cosmetic
**Evidence:** `findings/tools/tooling-report.md:83-84` says SAW's maximum
bitcode version "was only verified for LLVM 20.1.2"; the same report's
capability matrix (`tools/capability-matrix.md:51-56`) says the ceiling is at
least LLVM 22.1.2 (rustc 1.95 loaded and proved) and 23.1.1 fails.
**Owner:** `TOOLS`.
**Would clear it:** make the report and matrix state the same measured ceiling.

### C-06 — `patches/core/README.md` calls the patched IR a "reproduced artifact"

**Severity:** cosmetic
**Evidence:** `patches/core/README.md:20`: "Apply order used for the reproduced
artifact: 01, 02, 03." "Reproduced" can be read as behaviorally validated; the
report itself says reproducibility, not equivalence.
**Owner:** `CORE-IR`.
**Would clear it:** say "byte-reproducible artifact; not an equivalence
claim".

### C-07 — Twin report mixes 146/147 and mapping-coverage counts

**Severity:** cosmetic
**Evidence:** `findings/twin/twin-report.md:20` says "146 cases + 58/58 mapping
coverage, 0 failures"; `:77-79` says `mapping_coverage PASS (58/58)` and
`cases=147 failures=0`; `:95` repeats 147. The script-case count and total-case
count are interleaved.
**Owner:** `TWIN`.
**Would clear it:** state one convention, e.g. "147 total = 146 script + 1
mapping-coverage case".

### C-08 — README names mutation IDs as "gate cells"

**Severity:** cosmetic
**Evidence:** `README.md:179`: "gate cells M-E1-001/002 being built".
`M-E1-001/002` are mutation IDs in `cells/_redteam/MUTATIONS.md`, not cell
directories.
**Owner:** `README.md` / `REDTEAM`.
**Would clear it:** say "mutation tests M-E1-001/002".

### C-09 — Cell IDs and family directories do not match the documented naming

**Severity:** cosmetic
**Evidence:** `update_ledger.py --check` warns for all six cells:
"cell id does not match the documented `C-L-*` / `C-R-*` / `L-R-*` naming
pattern" and "family directory 'e1-stack' is not in `cells/README.md` or the
ledger family list". The updater accepts them, but the schema documentation
and the records disagree.
**Owner:** `CELLS` / `LEDGER`.
**Would clear it:** either rename the cells/families or update the documented
naming and family list.

---

## 5. Resolved findings (kept for ID stability)

### B-02 — RESOLVED: E0 is now a three-leg pass

`make e0` rc 0, `RESULT: PASS`, `E0_TRIPLE_OK`; R `.so` `73e3d2d9…` built from
the clean rbitcoin pin at rustc 1.95.0 and reproducible byte-for-byte. The C
leg remains a behavioral g++/stub build (M-01) and the L shim entry is still a
stub (bypassed by `libtwin.so`), but the E0 acceptance gate is genuinely green.
**Evidence:** `results/e0/README.md`; `tools/tests/e0-triple.sh`;
`make e0` at `22:33Z`.

### B-07 — RESOLVED: the differential is current and has no disagreement

`differential/run.py` was re-run at `22:36Z` against `libtwin b9ed129b…`
/ IR `e5fbe727…`: **922 agree / 0 disagree / 336 blocked**; Lean model
1251/0/7; C vs expected 1258/1258; determinism `identical`. The former
`sc-0365` disagreement is not reproduced; `disagreements.md` is empty.
**Residual:** behavioral only; R absent (B-03); `LEG-IDENTITY.md` stale (M-08);
`r_leg.reason` false (M-16).

### M-04 — RESOLVED: E1 cells are built

Six valid bounded-leaf cells exist with results and certificates.
**Residual:** they are not ledger-green (B-01) and `make equiv` cannot see them
(B-10).

### M-12 — RESOLVED: the E0 L binary is the generated twin

`tools/tests/e0-triple.sh` defaults `TWIN_SO` to `twin/build/libtwin.so`, and
`results/e0/README.md` cites `b9ed129b…`, matching `make e0`'s build. The old
`/tmp/opencode/shim-build/libequiv-twin.so` ambiguity is gone.
**Residual:** `shims/twin/entry.cpp` is still a stub, so a reader may think the
L leg uses it; it does not.

### M-13 — RESOLVED: the six cell specs are backed by results

All six `spec.md` files now have `---` YAML front matter and all six have
`alive2/result.txt`, `saw/result.txt`, `behavior/result.txt`, and
`certificate.sha256` files; all 18 result/certificate pairs verify.
**Residual:** the cells are partial (`gap`), not green (B-01).

---

## 6. Verified-clean items (do not re-litigate without new evidence)

### 6.1 PINS vs reality

`make pins` rc 0, 0 TODO keys. Verified: clang/LLVM 20.1.2; Alive2 LLVM
20.1.2; SAW 1.6 (68eed5f); system z3 4.8.12; bundle z3 4.8.14; cvc5 1.3.1;
Python 3.12.3; cmake 3.28.3; Lake 5.0.0-src+5045d00 (Lean 4.34.1); rustc
1.95.0 present; host 1.99.0. Core HEAD `cce32b168…` clean; `rbitcoin-clean`
`ae47aa98…` clean; Lean HEAD `4d62a97e…`.

### 6.2 Contract hash

The four-file recipe recomputes to `c2fcc67a…be4ff`, matching
`PINS.lock [contract]`. The `error_enum.md` omission is B-06, not a hash
miscalculation.

### 6.3 ABI v2

8-argument `equiv_entry` (7 inputs + `error_kind*`) and 7-argument wrapper
verified across `ABI.md`, `tape.md`, `shims/README.md`, and all three shims.

### 6.4 Error enum

`header 56 markdown 56 match True`, `dense True`,
`last ('EQUIV_ERR_COUNT', 55)`. The old `EQUIV_ERR_ERROR_COUNT` name is absent
from the header.

### 6.5 Core patches

`git apply --check` rc 0 for P-CORE-01/02/03 against the clean Core pin. All
remain PROPOSED (B-05).

### 6.6 Leaf proofs

`CastToBool` (Alive2/SMT: 1 correct, 0 errors) and `operator|` (SAW: `Proof
succeeded!`) are genuine leaf proofs. The six E1 leaves are genuine bounded
Alive2/SAW/behavior results with verifying certificates. None is engine-level.

### 6.7 Twin

`twin/smoke.sh` rc 0 at `22:37Z`: `cases=147 failures=0`,
`RESULT[pinned-clang]: PASS`; `twin.cpp 39ab7c66…`, IR `e5fbe727…`,
`libtwin.so b9ed129b…`; `gen.py --check` OK.

### 6.8 Differential

Re-run at `22:36Z`: 922/0/336; Lean 1251/0/7; C vs expected 1258/1258;
determinism identical. `L_twin` and `lean_model` are correctly separated in
identity fields.

### 6.9 Ledger

`update_ledger.py --check` rc 0, `valid 6, malformed 0`, `changes: 0`;
`coverage_report.py --strict` rc 1 only for 178 planned rows.

---

## 7. Claim-form audit (README claim vs evidence tier)

| Claim form in the tree | What the evidence supports | Verdict |
|---|---|---|
| "three-leg equivalence" | E0 agrees on four hello tapes; six bounded leaves; no engine cell | **not established** |
| "E0 passes" | `make e0` rc 0, four tapes, harness/ABI only | **true, narrowly** |
| "R is at the 1.95 pin" | behavioral shim yes; proof artifact no | **half-true; must say which** |
| "six E1 cells are both-green" | raw Alive2/SAW/behavior green; ledger 0 green, 5 gap | **true only at raw-tool level** |
| "`make equiv` confirms green" | it reports 6 red (B-10) | **false** |
| "C and twin agree 922/1258" | current run, behavioral, 336 blocked | **true for behavior** |
| "C and twin are IR-equivalent" | no IR comparison of the engines | **false** |
| "Core patches are reproduced" | apply cleanly and are byte-reproducible; no differential | **reproducibility, not equivalence** |
| "contract hash binds the contract" | excludes `error_enum.md` | **false** |
| "the tree is reproducible from the pin" | `spec/equiv/` untracked | **false** |
| "mutation-tested E1" | zero mutants run | **false** |

---

## 8. Contradiction register (pairs that cannot both be current)

1. `results/STATUS.md:4-6` says E0 PASS / pins filled; `:81-83` says fill the
   build pin and replace the R stub (M-14).
2. `differential/results/summary.json` says 922/0/336 at `b9ed129b…`;
   `differential/results/LEG-IDENTITY.md` says 854/0/404 at `d560a5f6…` (M-08).
3. `differential/run.py:97-102` says `entry.rs` is a STUB and the worktree is
   dirty; `shims/rust/entry.rs` is live and `rbitcoin-clean` is clean (M-16).
4. `shims/README.md:153-154` says R is a stub at rustc 1.99; the current R
   `.so` is 1.95 and live (M-07).
5. `orchestrator-crosschecks.md:189-192` says E0 is pending with L/R stubs;
   `make e0` rc 0 (M-09).
6. `tooling-report.md:91-96` says `run_equiv` sees no cells, 2 TODO pins, 0
   records; current: 6 cells, 0 TODO, 6 records (M-06).
7. `PINS.lock abi_shim = entry.rs` vs `abi_shim_sha256` = the `.so` hash
   (M-15).
8. Six cells' `result.txt` say green; `make equiv` says 6 red (B-10).
9. `gate-ir-pin` says `5/183 SCR rows adjudicated`; `coverage_report.py` says
   `0 green, 178 planned` — both are true because "adjudicated" includes filed
   gaps, but the summary line invites misreading.
10. `results/STATUS.md` says "Proof-cell directories: 0"; six cell directories
    exist (they are bounded-leaf, not engine, cells).
11. `README.md:89` says the R fallback runs Alive2-only; Alive2 cannot ingest
    the pinned R IR (M-11).

---

## 9. Command log (actual runs at snapshot)

| Command | rc | Key output |
|---|---:|---|
| `make pins` | 0 | `Unfilled TODO keys: 0`; `RESULT: OK` |
| `make e0` | 0 | `triple script: GREEN`; `RESULT: PASS` |
| `make gate-ir-pin` | 2 | `6` dirs / `6` records; `gap=5, planned=178`; `5/183` |
| `make equiv` | 2 | `0` green, `6` red, `3` TODO; scans 9 dirs |
| `coverage_report.py --strict` | 1 | `TOTAL 183 0 178 0 5 0`; `malformed: 0` |
| `update_ledger.py --check` | 0 | `valid 6, malformed 0`; `changes: 0` |
| `twin/smoke.sh` | 0 | `cases=147 failures=0`; pinned-clang PASS |
| `differential/run.py --out-dir …` | 0 | `922/0/336`; `1251/0/7`; `1258/1258` |
| `shims/rust/build.sh` (rebuild) | 0 | byte-identical `73e3d2d9…` |
| `git apply --check` × 3 | 0 | P-CORE-01/02/03 ok |
| contract recipe | — | `c2fcc67a…`; with `error_enum.md`: `9794f28e…` |
| enum script | 0 | `header 56 markdown 56 match True`; dense; sentinel 55 |

---

## 10. Hash manifest (snapshot `2026-10-19T22:37:00Z`)

| File | SHA-256 |
|---|---|
| `PINS.lock` | `055e7c5867c8e08d572fadb3c31d980fe42e19356d86db79fe31392eb093e535` |
| `contract/ABI.md` | `3c28f66665d033d317de208abeb628a44e6ed0cf0b4be78e9069c687bd2671a5` |
| `contract/tape.md` | `7aadcda0620df1c5f6b0469dc844658b72f0c9d753d968012452345ad30ed15f` |
| `contract/error_kind.h` | `7a5f778f4aed8947a7768da3d3856c99eec2715f5502cb8f59af576c72dca170` |
| `contract/error_enum.md` | `3a840d954bf497183f053652384a3850e21aca96a8faea9889363a126eae5dd5` |
| `shims/rust/entry.rs` | `1fd706b8b27486e2d1897dd65792acc0c6887b2bcc3723468d3b07af5daa8837` |
| `shims/rust/build/libequiv-rust.so` | `73e3d2d96de864e11e7cfb7cc5cc9fbba5d0dad1dc5de08b4cad6114ad1dffde` |
| `shims/twin/entry.cpp` | `b54d9b09ca60f3fff47c7946a93909db30b06c5f4fe762be9005abaaca236c60` |
| `results/STATUS.md` | `ce52c1ff7b039b9e96c806d53f95c1b1696681f9f1449fecb9b1398daf85068f` |
| `results/e0/README.md` | `09c84edd7add2901fb34a5d52b67a3e6c1983c2f2abf594646413a95219515ea` |
| `findings/twin/twin-report.md` | `430b9bd79aeae7191f66d88345f47458a26c9046a769802427f27ce848108d47` |
| `differential/results/summary.json` | `64e4abfbd49574fe6e42b4b1412f049845b547f96184f3252d2117a34e72ea97` |
| `differential/results/LEG-IDENTITY.md` | `df0bff3e0d689ae7358698167ef37c02a6ec14f8ed6062e971dfc1f7bd84a717` |
| `twin/build/twin.cpp` | `39ab7c66ea112ea0108e6f2b93c6bbb8ad0b8261f3230310c989cb8d0af2478f` |
| `twin/build/twin.ir.json` | `e5fbe72707a43bfc950ad67e4a86eff3c4c3c4314aa17323c2a23b9f3cfd6413` |
| `twin/build/libtwin.so` | `b9ed129b9a0bd719da789c7accab7e522f436b08eb33e8cd18874659edeea72b` |
| `tools/run_equiv.py` | `2aa340ca8fcf30faa76ceb90d765b802a3cb87c9b928a05b0b0707cf614f1758` |
| `tools/gate_ir_pin.py` | `a2002e0ba666c6ef8f58c5dabedd8d570d8efccfe281e7543b5fe00b96f7bf6f` |
| `tools/check_pins.py` | `0ec2d7ec34e514d9db74aa84cae27d816e445bf09a5b09ce0f4bfd1df076e99f` |
| `results/scripts/update_ledger.py` | `b19bc96260872724e35f4a43f9f7e9602105b567071c7c6a3e02ed749ee573b1` |
| `results/scripts/coverage_report.py` | `e0af3033593525bcdf48896f5dd58ea6d3a62f467b2c8f56cc7763557a0cf94e` |
| `spec/db/equiv-cells.yaml` | `537f06a87a0990728e4024c525051943c7bfa2fa23b7e5908e98f10e7dea8c49` |
| `/tmp/opencode/cbuild/libequiv-core.so` | `5fef1df004adae637ffd7d3d7bf7dc96700c552dc2c22729d0de06d81457fbb5` |

Derived: contract `c2fcc67a…be4ff`; + `error_enum.md` `9794f28e…eff11d`;
Core HEAD `cce32b168…`; rbitcoin `ae47aa98…` (clean lane); Lean
`4d62a97e…`.

**Post-freeze movement:** `findings/twin/twin-report.md` was rewritten at
`22:39:01Z`; its current hash is
`9417edc722e929dc5b05a35869ca5e723a7c128a2de29cfb1dbbe15e24c57c5c`. The
content checked after the rewrite still says `cases=147 failures=0`,
`146 cases + 58/58 mapping`, and cites `twin.cpp 39ab7c66…` /
`e5fbe727…`. Finding C-07 therefore still applies. All other manifest
hashes matched at the last check.

---

## 11. What the evaluator did not do

- Did not edit any file outside `docs/` and `findings/evaluator/`.
- Did not commit anything; `spec/equiv/` remains untracked.
- Did not run the redteam mutants.
- Did not build an engine-level SAW/Alive2 proof.
- Did not run R in the differential.
- Did not re-verify the SAW tarball checksum (tarball absent).
- Did not attempt P-CORE differential behavior runs.

---

## 12. Disposition priority

1. **Fix `make equiv`** to read `result.txt` (or `tee` in the runners). It is
   the acceptance command and currently returns the opposite of the evidence
   (B-10).
2. **Fix the contract recipe** and re-pin before any cell cites the hash
   (B-06).
3. **Adjudicate the E1 outcome**: either widen leaves or accept filed gaps,
   and make the gate report green/gap/planned unambiguously (B-01).
4. **Decide the R proof scope**: pinned 1.95 proof artifact or explicit
   off-pin gap filing; integrate R into the differential or state the omission
   (B-03).
5. **Scope the engine claim**: specify `EvalScript`/`VerifyScript` for SAW, or
   withdraw "three-leg engine equivalence" (B-04).
6. **Track `spec/equiv/`** at a commit or publish a hash-pinned archive
   (B-08).
7. **Run the mutation tests** before calling E1 complete (B-09).
8. **Refresh the stale secondary reports** (M-05…M-09, M-14…M-16) so a reader
   does not get two answers.

---

## 13. Post-snapshot addendum — `2026-10-19T23:10:00Z` (post-E6 integration)

This addendum supersedes the *current-state* statements in §§1–12 above; the
original audit is retained unchanged as history. It was written by the
orchestrator, not by the independent evaluator. Re-run the commands in §7 of
`docs/STATE.md` before citing either snapshot.

### 13.1 Current commands

| Command | rc | Key output |
|---|---:|---|
| `make pins` | 0 | all required pins filled; tool probes pass |
| `make e0` | 0 | `E0_TRIPLE_OK`; 4/4 tapes |
| `make gate-ir-pin` | 0 | 17 cell dirs / 17 records; 183/183 adjudicated; 0 failures, 0 warnings |
| `make equiv` | 0 | 17 cells with >=1 green tool, 0 red, 0 TODO |
| `coverage_report.py --strict` | 0 | 183 rows: 4 green, 20 seam, 159 gap, 0 planned |
| `update_ledger.py --check` | 0 | valid 17, malformed 0; changes 0 |
| `build_matrix.py --check` | 0 | `results/matrix.md` current |

### 13.2 Ledger current state

- **Green:** 4 — SCR-069, SCR-071, SCR-072 (`control-flow/C-L-nop-return`),
  SCR-074 (`stack-ops/C-L-arity` plus E1 stack corroboration).
- **Unjudged seam:** 20 (E4 hash/EC/dispatch/sighash/clean-stack seams plus
  SCR-045 F-DIV-001).
- **Filed gap:** 159, each with a row-specific `gap_note`; see
  `findings/coverage/F-E6-GAPS.md`.
- **Planned:** 0.
- **Cell directories:** 17, all with both Alive2 and SAW success markers;
  E2/E3/E4 cells are partial and do **not** promote their SCR rows.

### 13.3 Dispositions of the original findings

| Finding | Disposition |
|---|---|
| **B-01** many `planned` rows / few green | **Resolved for the evidence tier.** 183/183 adjudicated: 4 green, 20 seam, 159 gap, 0 planned. The low green count is honest, not hidden. |
| **B-03** no admissible R proof artifact | **Open, filed.** Pinned rustc 1.95/LLVM-22 IR is rejected by Alive2 (`F-TOOL-001`); the 1.88/LLVM-20 lane is non-pin. R behavioral E0 is green; no R proof cell is claimed. |
| **B-04** engine claim unscoped | **Resolved as scoped residual.** `findings/e5/E5-RESIDUAL.md` names `GetScriptOp`, `_Znwm`/heap, the `EvalScript` loop, exceptions, and `ptrtoint`. No whole-function proof is claimed. |
| **B-05** Core patches PROPOSED | **Open, filed.** P-CORE-01/02/03 remain PROPOSED, have no differential, and are used by no green cell. |
| **B-06** contract recipe omitted `error_enum.md` | **Resolved.** Contract v3 `f1841e36…` includes it; recipe recomputed exact match. v2 `c2fcc67a…` summaries remain historical (`contract/CHANGELOG.md`). |
| **B-07** seam validator / differential currency | **Resolved in the validator and note.** `adjudicate.py` accepts named finding ids and distinguishes `gap` from `unjudged-seam`; `differential/results/CONTRACT-NOTE.md` marks v2 summaries. |
| **B-08** `spec/equiv/` untracked | **Open by instruction.** No commit/push was performed; all changes remain uncommitted. |
| **B-09** no mutation execution | **Resolved.** 8 runs / 7 distinct ids killed by both tools: M-E1-001 (twin and core-slice), M-E1-002, M-E1-006, M-E1-008, M-E2-010, M-E3-008, M-E4-004; clean reverts and green baselines. |
| **B-10** `make equiv` runner mismatch | **Resolved.** It reads `result.txt`, ignores runner `#` annotations, skips aux dirs, and reports 17/0/0. |
| **M-15** R shim source hash not pinned | **Resolved.** `PINS.lock [rbitcoin] abi_shim_source_sha256 = 1fd706b8…`; binary hash remains separate. |
| **M-16** stale R blocker/contract wording | **Resolved.** `[rbitcoin] build`/`toolchain_note` and `CONTRACT-NOTE.md` distinguish the pinned behavioral lane, rejected proof lane, and historical v2 summaries. |

### 13.4 Remaining honest limits

- **E2:** one-byte symbolic WITHIN and one concrete HASH160 plumbing vector;
  both tools green, rows partial/gap. Wider ScriptNum widths, edge cases, and
  the hash transform are not proved.
- **E3:** bounded checksig/1-of-1 CMS with a shared abstract checker; exact
  error ordinals 2/13/14/18/28. DER/LOW_S/STRICTENC/NULLFAIL, general
  nKeys/nSigs, ordering, FindAndDelete, and tapscript are not covered.
- **E4:** v0 dispatch length/arity predicates only; SHA256 and
  `ExecuteWitnessScript` abstracted; 38-row seam/gap inventory.
- **E5:** scoped residual; no whole-function proof. The one green empty-script
  line is concolic/non-pin and not a ledger row.
- **R:** no proof lane at the pin; behavioral E0 only.
- **Crypto:** same-crypto premise; no libsecp256k1 proof.
- **C/L provenance:** E1 uses generated twin handlers; E3 uses reviewed
  transliterations of the Lean equations, not generated twin output.

### 13.5 Evidence index

`results/STATUS.md`, `docs/STATE.md`, `docs/TRUST-BASE.md`,
`results/matrix.md`, `findings/coverage/F-E6-GAPS.md`,
`findings/e2/report.md`, `findings/e3/report.md`, `findings/e4/report.md`,
`findings/e5/E5-RESIDUAL.md`, `findings/e5/F-TOOL-001.md`,
`findings/redteam/redteam-report.md`, `cells/_redteam/MUTATIONS.md`, and
`cells/_redteam/runs/`.
