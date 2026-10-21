# REDTEAM adversarial validation protocol

**Status:** design, E0. **Version:** 0.1. **Owner:** REDTEAM.
**Applies to:** every cell, family, certificate, shim, pin, corpus, and
milestone claim in `spec/equiv`.

Normative words: **MUST**, **MUST NOT**, **SHOULD**, **MAY**. A violation of a
MUST blocks sign-off until dispositioned in `findings/redteam/`.

---

## 0. Scope, authority, non-goals

REDTEAM validates the **validation apparatus**, not the engines. Its job is to
answer one question: *if a semantic bug of class X were present, would this
campaign have detected it and would the published claim have been false?*

REDTEAM:

- reads everything in `spec/equiv`;
- writes only `cells/_redteam/` and `findings/redteam/`;
- never edits a cell, shim, twin, patch, corpus, ledger, pin, or result;
- proposes fixes through `findings/redteam/` findings and handoff notes;
- does not sign its own authored cells/shims (see §6.2).

A REDTEAM **pass** is a bounded negative result: the tested failure modes were
not found. It is not a proof that no failure exists. A REDTEAM **fail** is
positive evidence and MUST block or demote a green claim.

Non-goals: proving engine correctness, re-running every proof, auditing the
SMT solver internals, or assigning fault to a role. The target is the claim,
not the people.

---

## 1. Baseline preconditions (B-gate)

No mutation or harness verdict is valid unless all of B0–B8 hold. A failure is
recorded as `INVALID`, never as a kill or a pass.

| ID | Precondition | Evidence |
|---|---|---|
| B0 | The cell is green on **unmutated** sources, with the exact pins in `PINS.lock` | cell record + reproduced run |
| B1 | The cell's spec hash (precondition, postcondition, domain, flags) is recorded before the run and unchanged during it | spec hash in cell record |
| B2 | Every leg fingerprint (commit, compiler, flags, IR sha256) is present and matches `PINS.lock` | leg record |
| B3 | The corpus and each corpus file are content-addressed; the run uses the pinned hash | corpus manifest |
| B4 | The cell record names the tool version, direction(s), certificate/log sha256, and result | cell record |
| B5 | The baseline run is reproduced at least once from a clean build (or a recorded clean rebuild is cited) | second log |
| B6 | The source tree is clean except for declared, tracked patches; no untracked edits | `git status` + patch set |
| B7 | The expected failing cell(s) and a concrete **kill witness** are declared *before* mutation (see §2.6) | mutation plan |
| B8 | The run is deterministic: repeated baseline runs on the same tape agree in verdict and error kind | determinism log |

If B0 fails, the mutation result is `INVALID`; a mutant cannot "fail" a cell
that was never green.

---

## 2. Mutation testing

### 2.1 Terms

- **Mutant:** one minimal, semantic change to one source file, described by a
  stable id from `MUTATIONS.md` and applied by `mutate.py`.
- **Kill:** a named expected cell fails on the mutated build for the declared
  reason (verdict, error kind, or postcondition), with a recorded witness.
- **Survivor:** all named expected cells remain green. A survivor is a
  **finding** against the cells, not a success.
- **Equivalent:** the mutation cannot change any observable in the cell's
  declared domain. This is an exceptional classification with a proof burden;
  it is never the default.
- **Invalid:** build error, harness crash, timeout, baseline failure, stale
  object, or a run that did not actually use the mutated artifact.
- **Control mutant:** a non-semantic edit (comment, local rename) that MUST
  leave the cell green; it detects cells that key on source text or hashes.

### 2.2 Mutant sites and pairing

Every required semantic mutation is run at up to three sites:

| Site | Target | Purpose |
|---|---|---|
| `model` | Lean model input (`spec/core/Bitcoin/Interpreter/Defs.lean`) or the twin generator's imperative IR (`twin/ops_ir.py`) | tests generator faithfulness **and** proof sensitivity |
| `twin` | generated/transliterated twin C++ (`twin/`) | tests proof sensitivity without relying on the generator |
| `core-copy` | patched Core copy (test-only) at the pinned commit | tests C-side sensitivity and both refinement directions |

Rules:

1. At least one **model-site** mutant per milestone family is REQUIRED. A
   model-site mutant must be regenerated into the twin; record both the model
   diff and the generated-twin diff (or prove the regeneration produced no
   relevant change).
2. A `core-copy` mutant is REQUIRED for at least one mutant per milestone
   family. It MUST be a detached, patched Core copy/worktree at the pin, MUST
   NOT be registered in `patches/`, MUST NOT be committed, and MUST be deleted
   or restored after the run. It is a test artifact, not a `patches/` patch.
3. The same semantic mutation SHOULD be run on twin and core-copy as a pair.
   A twin-only kill proves only one direction of refinement; the pair catches
   asymmetric cells and cell specs that quietly compare against the wrong leg.
4. An optional `rust-copy` canary MAY be used in E3/E4 to test R-specific
   blind spots; it does not replace the required twin/Core pair.

### 2.3 Required mutants and scoring

`MUTATIONS.md` is the catalogue. Each milestone has a required subset.

- **E0:** no semantic mutant; two harness canaries are required (§3.1, §3.3).
- **E1:** at least 3 required E1 mutants killed, including `M-E1-001`; at least
  one model-site and one core-copy kill.
- **E2:** at least 4 required E2 mutants killed, covering limits, ScriptNum,
  flow, and numeric semantics; at least one model-site and one core-copy kill.
- **E3:** at least 5 required E3 mutants killed, covering CMS order, NULLDUMMY,
  NULLFAIL, encoding, and error-kind mapping; at least one model-site and one
  core-copy kill.
- **E4:** at least 5 required E4 mutants killed, covering P2SH source, witness
  order, leaf version, program length, and annex/OP_SUCCESSx; at least one
  model-site and one core-copy kill.

Scoring:

```
mutation score = killed required mutants
                 / (required mutants - mutants adjudicated equivalent)
```

Sign-off requires **100%** of the required set killed or adjudicated
equivalent (§2.5). An optional broader score over the full catalogue is
reported but is not a substitute for the required set. A family with a
surviving required mutant is **not green**.

### 2.4 Procedure

1. Freeze the cell spec, corpus hash, pins, and expected-failing list.
2. Record the baseline evidence bundle hash (B-gate).
3. Apply exactly one mutation with `mutate.py`:
   ```sh
   python3 cells/_redteam/mutate.py \
     --target <file> --mutation M-E1-001 --target-kind twin
   ```
   The script records before/after sha256 and a mutant record under
   `cells/_redteam/mutants/`.
4. If the target is `twin/ops_ir.py` (generator site), regenerate with
   `twin/gen.py` and record both the IR diff and the generated
   `build/twin.cpp` diff. If the target is `build/twin.cpp` (generated site),
   record the `gen.py --check` drift. Rebuild the affected leg from the
   mutated source with the pinned toolchain/flags. No incremental objects from
   the baseline build. Record the new IR sha256.
5. Run **all** named expected cells, both tools and both directions, plus the
   baseline cells not expected to fail (to detect over-broad mutations).
6. Record observed result, failing assertion, counterexample/witness, tool
   logs, and exit codes.
7. Classify: `KILLED`, `SURVIVED`, `EQUIVALENT-CANDIDATE`, or `INVALID`.
8. Revert with `mutate.py --revert <record>`; verify the target hash returns to
   `sha256_before`; rebuild and confirm the baseline is green again.
9. File the result in `findings/redteam/` and update the mutant record with the
   outcome, cell ids, log hashes, and operator.
10. A second operator/session MUST reproduce at least one mutant per milestone
    from a clean tree (independence check).

A mutant that is applied but not reverted is a **release blocker**: the tree is
contaminated and no subsequent result is trustworthy.

### 2.5 Kill, survivor, equivalence, invalid

**KILLED** requires all of:

- at least one named expected cell fails;
- the failure is attributable to the mutation (the same witness differs;
  unrelated failures are not accepted);
- the failure is a verdict, error-kind, or postcondition difference — not a
  build error, harness crash, solver timeout, or missing file;
- the witness is concrete and replayable;
- the cell spec and corpus hash are unchanged from baseline.

**SURVIVED** means the expected cells stayed green. Default interpretation:
the cell is too weak, the witness does not reach the mutated branch, or the
cell's postcondition cannot observe the change. The owner MUST strengthen the
cell and re-run the mutant. A survivor is never closed by editing the expected
list after the run, by narrowing the cell precondition, or by declaring the
mutant "unrealistic" without evidence.

**EQUIVALENT-CANDIDATE** is allowed only when the mutation provably cannot
change the cell observable on the declared domain. The adjudication package
MUST contain:

1. the exact mutant diff and target hashes;
2. a written argument that every path affected by the mutation is either
   unreachable on the domain or leaves the observable unchanged;
3. ideally a solver/SAW check of the equivalence claim, or an exhaustive
   bounded check over the cell domain;
4. a second reviewer who is not the mutant author;
5. a recorded residual risk if the argument is informal.

If any part is missing, the classification remains `SURVIVED` and blocks
sign-off. "The mutant is semantically silly" is not an equivalence argument.

**INVALID** runs are retried once after fixing the harness/build. Repeated
invalid runs are a harness finding, not a cell pass.

### 2.6 Kill witness and observability rule

Every required mutant MUST declare, before execution:

- the exact cell(s) expected to fail;
- the input tape/script bytes (or symbolic constraint) that reaches the
  mutated behavior;
- the baseline observable and the expected mutant observable;
- the flag set, amount, input index, and witness shape needed to reach it;
- why the cell's precondition includes that witness.

If no concrete witness can be produced, the mutation is **outside the cell's
domain**. That is a coverage finding: the cell does not exercise the feature it
claims. It is not an equivalent mutant and it must not be scored as a kill.

**Observability:** a cell whose only postcondition is "did not crash" or "exit
code 0" cannot kill a semantic mutant. Each family MUST contain at least one
cell whose postcondition observes stack/memory/error state, not only the final
pass/fail byte. For entry-level cells, a mutant is only killable if it changes
`verdict` or `error_kind` on some tape; order-only mutations that leave the
final truthiness unchanged require a leaf cell with a stack postcondition.

### 2.7 Anti-gaming rules

A cell or runner is **invalid** if it:

- reads source text, source hashes, file paths, environment variables, or
  mutant metadata to decide a result;
- special-cases a known mutation id, corpus entry, or expected-failing list;
- changes its precondition, postcondition, or corpus after seeing the mutant;
- accepts a timeout, crash, or build failure as a kill;
- compares only a hash of the output without checking the contract fields;
- runs a stale object/binary not rebuilt from the mutated source;
- disables optimization or changes flags relative to the baseline;
- mutates a shim, test driver, or corpus instead of the declared engine source
  (except the explicit harness canaries in §3);
- applies more than one semantic mutation at a time.

Control mutants (comment-only or local rename) MUST survive. If a control
mutant kills a cell, the cell is source-text-sensitive and is invalid until
fixed.

### 2.8 Mutant record schema

`mutate.py` writes one JSON record per application:

```json
{
  "schema": "redteam-mutant-v1",
  "mutant_id": "M-E1-001",
  "target_kind": "twin",
  "family": "e1-stack",
  "description": "OP_SWAP becomes a no-op",
  "target": {"path": "...", "sha256_before": "...", "sha256_after": "..."},
  "diff": "--- a/... +++ b/...",
  "expected_failing_cells": ["cells/e1-stack/swap-order"],
  "catchers": ["alive2", "saw"],
  "pins_sha256": "...",
  "catalogue_version": "0.1-planned",
  "applied_at_utc": "...",
  "status": "applied",
  "outcome": "pending"
}
```

The outcome fields (`classification`, `observed`, `witness`, `log_hashes`,
`operator`, `reverted_at_utc`) are appended by REDTEAM after the run. Records
are append-only; corrections are new records/receipts.

### 2.9 Cleanliness and reversion

- Revert before running any other mutant.
- Verify `sha256(target) == sha256_before` after revert.
- Rebuild and re-run the baseline cell; it MUST be green.
- If revert fails, stop the campaign and file an S1 finding; do not hand-edit
  the file back without recording the repair.

---

## 3. Harness attacks

### 3.1 Shim smuggling engine logic

**Attack:** a shim decides something the engine should decide — a fast path for
known scripts, flag clamping, witness reordering, exception-to-pass, amount
adjustment, script pre-validation, caching, or "helpful" normalization.

**Detection:**

- Line review against `contract/ABI.md` §6: marshalling only, no engine logic.
- Static checks: allowed includes/symbols only; no `EvalScript`,
  `VerifyScript`, `CastToBool`, `CheckLockTime`, `CheckSequence`, opcode
  switch, or script-byte comparison beyond length checks; no loop over script
  bytes.
- Byte-preservation test: instrument the engine boundary and prove the shim
  passes exactly the caller's bytes and lengths (including zero-length and
  malformed tapes).
- Bypass-shim differential on a sample: call the engine entry directly with
  the same tape and compare result/error.
- Two-shim rule: at least one leg has a second, independently written shim (or
  a generated IDL shim) used on a sample; disagreement is a finding.
- Exception path: force an engine exception/panic and confirm result `3`, not
  `0`/`1`; force malformed input and confirm `2` where the contract requires
  it.

**Pass condition:** review signed, static check clean, byte-preservation and
bypass differential clean, exception/malformed paths correct.

**E0 canary:** in a throwaway copy, add a one-line fast path that returns `1`
for a known script; the review/static check MUST catch it. Record the canary.

### 3.2 Corpus poisoning

**Attack:** the corpus avoids the mutant, duplicates easy cases, encodes the
bug in expected verdicts, is filtered by the runner, or is changed after cells
were selected.

**Detection:**

- Content-addressed manifest (per file + total), provenance (generator, commit,
  external vector source), and pinned hash in every cell record.
- Corpus frozen before cell selection; a hash change starts a new baseline.
- Runner reports count and hash actually consumed; hidden filtering is a
  finding.
- Stratification report: opcode families, flag sets, script types, error kinds,
  boundary lengths, malformed tapes.
- Independent holdout (at least 20%) not used to select or tune cells; REDTEAM
  uses it at sign-off.
- Expected verdicts spot-checked against an independent oracle (Core test
  vectors, hand computation, unpatched binary) — never only the leg under test.
- Duplicate/near-duplicate detection; a corpus of 10k clones of one script is
  not coverage.

**Corpus canary:** in a copy, flip one expected verdict or delete one boundary
vector. The runner/coverage gate MUST fail or report the hole. Record it.

### 3.3 Pin drift

**Attack:** a result is produced with a different compiler, LLVM, SAW, solver,
Core commit, rbitcoin commit, dependency, or flag than `PINS.lock` says, or the
IR is rebuilt after the certificate.

**Detection:**

- `PINS.lock` completeness: Core commit, clang build/version, rustc, LLVM IR
  version, SAW, Alive2, Z3/CVC5, flags, triple, twin generator revision,
  rbitcoin commit and crypto mode.
- Transitive pins: `Cargo.lock`, `lake-manifest.json`, compiler build ids,
  solver versions, submodules/deps, checksums of downloaded artifacts.
- Hermetic build: no network, fixed environment, fixed `SOURCE_DATE_EPOCH`,
  no system headers beyond the pinned sysroot.
- `gate-ir-pin` checks every cell's recorded tool versions and IR hashes.
- Rebuild from source+flags and compare IR sha256; a mismatch fails.
- Record the LLVM producer string / module flags in the cell record.
- Re-pinning is a new result: old results remain but are marked superseded and
  cannot be cited in the new milestone.

**Pin canary:** in a copy of `PINS.lock`, change one tool version; `gate-ir-pin`
MUST fail. In a throwaway build, use a different clang and confirm the IR hash
and gate reject it. Record both.

### 3.4 Certificate and log replay

**Attack:** a certificate/log from another cell, another run, or before a
mutation is copied into a green record; a hash is cited but the artifact is
missing; the log is truncated; the certificate is not bound to the spec.

**Detection:**

A certificate MUST bind, at minimum:

- cell id and spec hash (pre/post/domain/flags);
- contract hash;
- every leg fingerprint (commit + compiler + flags + IR sha256);
- tool and solver versions;
- direction(s);
- corpus/domain hash;
- command line, exit code, stdout/stderr log sha256;
- certificate/log content hash and, where applicable, proof object hash;
- run manifest hash (source tree + pins + patches).

Verification:

- Re-hash every cited artifact on disk; missing/mismatched = invalid.
- Reject a certificate whose any binding differs from the cell record.
- Copy a certificate to another cell id (in a test harness) and confirm
  rejection.
- Change one byte of the spec or IR in a copy and confirm rejection.
- Sample replay from a clean checkout: re-run the command and compare result,
  verdict, error kind, and proof object hash (or a documented deterministic
  difference).
- A deterministic proof has no nonce; binding plus clean replay is the
  substitute. The trust boundary is stated: write access to records is assumed
  not to be adversarial, but accidental replay is tested.

**Pass condition:** all sampled certificates verify; replay matches; no
orphan hashes; no cross-cell reuse.

### 3.5 Contract ambiguity and conformance

**Attack:** a leg or shim interprets the contract differently from the
normative text; a cell precondition quietly excludes the hard case.

The contract is now versioned in `contract/ABI.md`, `contract/tape.md`,
`contract/error_kind.h`, and `contract/corpus_schema.md`; `tape.md` §7 defines
the domain and the result for out-of-domain input. The probes below are
therefore **conformance tests**, not invitations to reinterpret the contract.

Required probes (each leg, compared on `(result, error_kind)`):

- `input_index` ≥ number of inputs; zero inputs; huge input count.
- `amount` negative, zero, > `MAX_MONEY`, ignored paths.
- unknown flag bits; `WITNESS`/`CLEANSTACK` implication violations; policy vs
  consensus flags.
- zero-length tx/spk with null or non-null pointers; `spk_len > 0` + NULL.
- trailing bytes after a valid tx; truncated tx; non-canonical CompactSize.
- witness present for a non-witness program; missing witness for v0/v1.
- `scriptSig`/witness element count mismatches.
- behavior on `2` vs `3` (bad input vs internal), especially panics/exceptions.
- 32-bit vs 64-bit length truncation; integer overflow in length arithmetic.
- multi-input taproot: the synthetic spent-output convention (`tape.md` §6) is
  a harness tape, not consensus sighash behavior. Cells that need genuine
  multi-input taproot semantics are out of contract and must be filed as a gap.

**Known model divergence — F-DIV-001:** Lean/twin eagerly parse the whole
script before execution; Core decodes per iteration. On malformed tails this
changes **which error wins** (`EQUIV_ERR_BAD_OPCODE` vs the earlier opcode's
error) while both reject. Cells whose input can contain a malformed tail MUST
either restrict the precondition to scripts whose full parse succeeds, or be
recorded `unjudged-seam` citing F-DIV-001. Do not patch the twin to hide it.

**Error precedence is defined:** `contract/error_enum.md` says Core returns the
first failing check; cells assert the exact value, never "any plausible error".
The two-violations canary below tests this.

**Resolution rule:** an ambiguity is a finding, never a silent cell
precondition. Either the contract is amended (new contract hash, all affected
cells re-run) or a filed gap names the unspecified behavior. A cell may
restrict its domain only with an explicit precondition that is itself in the
contract or approved as a domain restriction with a residual-risk note.

**Canary:** construct a tape with two violations (e.g. `OP_VERIFY` followed by
a truncated push) and check all three legs agree on `error_kind`; disagreement
is a finding, not a tie to be averaged.

### 3.6 Error-enum mismatches

**Attack:** multiple Core errors collapse to `UNKNOWN`; mapping is by string or
enum order; policy errors are dropped; twin/Rust names are used raw; exception
maps to fail; an unreachable code is assumed unreachable without evidence.

**Detection:**

- Use the generated, normative `contract/error_kind.h` and
  `contract/error_enum.md`; re-run `contract/extract_error_enum.py` at the pin
  and verify the extracted table hash. Do not hand-maintain the Core side.
- Static/generated maps for all three legs; compile-time checks for missing or
  duplicate mappings. An unmapped failure is `EQUIV_ERR_UNKNOWN_ERROR` **plus
  a finding**; it is never silently renamed.
- Exhaustive reachable-error tests: for every enum value, a tape that produces
  it, or a filed gap naming why it is unreachable.
- Compare `error_kind` separately from `verdict` in every cell; "both fail" is
  not equality.
- Report aliases/collisions and unmapped values; zero unmapped at E3.
- Test error precedence (§3.5) because different precedence produces different
  enums.
- Values absent at the pin (`SCRIPTNUM_OVERFLOW`, `SCRIPTNUM_MINENCODE`,
  `DIV_BY_ZERO`, `MOD_BY_ZERO`, `SIG_BADLENGTH`, `CONST_SCRIPTCODE`) must not
  appear in expectations; `error_enum.md` gives their dispositions.

**Canary:** in a copy, change one mapping (e.g. `EQUIV_ERR_SIG_NULLDUMMY` →
`EQUIV_ERR_UNKNOWN_ERROR`); the E3 error-equality suite MUST fail.

### 3.7 Environment, UB, panic, and crypto-override attacks

| Attack | Detection |
|---|---|
| Time/locale/env-dependent result | run under varied TZ/locale/env; contract purity test (§ABI 7) |
| Allocator/ASLR-dependent behavior | repeat runs with allocator perturbation; compare |
| UB in C/C++/Rust | Alive2 UB reports; UBSan build; Miri on Rust; preserve reproducer |
| Rust panic abort vs unwind | force panic; verify result `3` and no process abort in the harness |
| Crypto override mismatch | shared checker contract; canary checker that returns wrong result; differential catches |
| Integer overflow in shim/tape lengths | boundary tests; UBSan; no `size_t`→`int` truncation |
| Exception swallowed as pass | forced-throw test; result MUST be `3` |

Any Core UB blocks the affected cell until disposition (fix upstream, restrict
domain, or file a gap) and is drafted as an upstream issue per `findings/`.

---

## 4. Differential-oracle abuse

The three-leg differential (C vs L vs R on corpora + fuzz) is a **test**, not a
proof. Three legs can agree because they share a bug, a shim, a corpus, an
expected-verdict table, or a crypto library. Unanimity is not evidence of
correctness.

### 4.1 Independence requirements

| ID | Requirement |
|---|---|
| I1 | Each leg's marshalling is implemented independently; at least one leg's shim does not share helper code with another |
| I2 | The corpus is generated independently of cell selection; at least 20% holdout |
| I3 | Expected verdicts are checked against an independent oracle on a sample (Core test vectors, hand computation, unpatched binary) |
| I4 | The crypto seam is a named shared premise; a checker canary proves the oracle is sensitive to crypto-visible differences |
| I5 | Comparison includes verdict **and** error kind, in both directions; not just pass/fail |
| I6 | Behavior-preservation checks use the **unpatched** Core binary as oracle, not the patched IR |
| I7 | At least one external vector set or second implementation is used where available; its absence is filed |

A differential run MAY demote a green cell (counterexample) but MUST NOT
promote one to green. Promotion requires a proof-tool result.

At the current pin, `PINS.lock` records that Alive2 cannot ingest rbitcoin's
IR (`F-TOOL-001`); R cells are SAW/differential-only. They cannot be
`GREEN-BOTH`, and the named feature plus substitute evidence must be filed.

### 4.2 Sensitivity canaries

For every family and milestone, inject a known bug into one leg (or a checker)
in a throwaway copy and confirm the differential catches it. If it does not,
the oracle is blind for that class; file a finding and do not cite differential
coverage for the family.

The canary MUST be distinct from the required mutation set (or explicitly
counted as both, never double-counted silently).

### 4.3 Reporting

Report pairwise confusion matrices and the corpus composition. A 100% three-way
agreement on a corpus that contains no boundary cases is suspicious, not
strong. List:

- disagreements and their triage (real divergence / harness / contract
  ambiguity / UB / crypto seam);
- agreement rate with corpus size and composition;
- which classes are untested because no witness exists;
- the exact corpus and pins used.

### 4.4 Shared-bug hypotheses

The recurring correlations to test explicitly:

- twin hand-transliterated from Core shares a misreading of Core;
- all shims share a tape parser that drops witness/trailing bytes;
- all legs share libsecp or a hash library;
- the corpus was generated by the twin or by the same author as the cells;
- expected verdicts were copied from one leg's output;
- all legs use the same optimizer/LLVM version and the same UB.

Each hypothesis needs a named test or a filed residual. "The three agree" does
not close any of them.

---

## 5. Unjudged-cell inflation

### 5.1 Cell states

| State | Counts as judged? | Counts as coverage? |
|---|---|---|
| `GREEN-BOTH` | yes | yes |
| `GREEN-ONE` (other tool inapplicable, named feature) | yes | yes |
| `GAP` (neither; named blocking feature + logs) | no | filed only, not green |
| `UNJUDGED` (not attempted / no result / generic reason) | no | no |
| `BLOCKED` (external dependency) | no | no |
| `INVALID` (harness/build failure) | no | no |

Only `GREEN-BOTH` and `GREEN-ONE` may be counted in the milestone matrix.
`GAP` is a filed residual, not a green cell. `UNJUDGED` is never counted.

### 5.2 Gap admissibility

A gap record MUST contain:

- cell id, family, and claimed SCR rows;
- tool(s) attempted, exact command, log sha256, exit status;
- the **exact blocking IR feature** from the closed list below, with the
  function/instruction evidence;
- why a smaller cell/decomposition or a different tool cannot express it;
- mitigation: differential coverage, bounded domain, or a scoped residual;
- residual risk and owner;
- review date and second reviewer.

**Closed list of blocking features:** `invoke`/C++ exceptions, function
pointers/indirect calls, `ptrtoint`/`inttoptr`, unknown/unbounded loop trip
count, unsupported LLVM intrinsic, inline asm, atomics/thread-local, complex
memory model (`prevector`/aliasing), LLVM version skew, Rust panic/unwind,
crypto seam (external checker), symbolic pointer aliasing, unsupported type
layout.

**Not admissible as a blocking feature:** "SAW is slow", "solver timed out",
"cell too big", "we ran out of time", "hard", "probably equivalent". A timeout
requires a documented decomposition/resource-budget attempt first; if that
fails, the residual is `UNJUDGED` or a named resource finding, not a feature
gap.

### 5.3 Anti-inflation controls

- Every cell must have a spec with pre/post and at least one tool attempt; an
  empty cell directory is `UNJUDGED`.
- A cell claiming multiple SCR rows must include a row→assertion mapping; no
  bulk "covers 30 rows" without witnesses.
- `GREEN-ONE` requires a tool log showing the actual ingestion failure for the
  named feature; a generic inapplicability note is `UNJUDGED`.
- Differential runs never convert `UNJUDGED` to `GREEN`.
- Freeze the gap ledger at the start of sign-off; additions during sign-off are
  reviewed, not silently counted.
- Report gap density per family and the absolute gap count. A family above 20%
  gaps is a **review trigger** requiring human sign-off, not an automatic pass.
- E1/E2: zero unjudged; gaps only if a named feature exists and the cell is
  still covered by a smaller cell or a differential witness.
- E3: zero error-enum gaps; crypto-seam cells may be `GAP` with the seam named.
- E4: seam-unjudged cells must be enumerated by id, feature, and residual risk;
  a generic "taproot is hard" bucket is invalid.
- E6: zero `UNJUDGED`; every gap dispositioned; every SCR row green or filed.

### 5.4 Audit sample

At each milestone, REDTEAM re-runs a random sample of ≥20% of green cells
(minimum 5) from a clean checkout, including at least one `GREEN-ONE` and one
cell with an error-kind postcondition. Any sample failure freezes sign-off
until resolved.

---

## 6. Milestone sign-off (E0–E6)

### 6.1 Sign-off record

Each sign-off is a file `findings/redteam/signoffs/E<n>-<YYYYMMDD>.md` plus a
JSON manifest with hashes. Required fields:

```
milestone: E<n>
commit: <repo commit>
pins_sha256: <sha256(PINS.lock)>
contract_sha256: <sha256(contract/ABI.md)>
evidence_bundle_sha256: <manifest of cell records, certificates, logs>
cells_audited: <ids / sample seed>
mutants_run: <ids + records>
gaps_reviewed: <ids>
findings_open: <RT ids>
verdict: SIGNED | SIGNED-WITH-RESIDUALS | REFUSED
conditions: <none or explicit residual>
signer: <REDTEAM operator>
independence: <statement + second reviewer>
```

`SIGNED-WITH-RESIDUALS` is allowed only for named, accepted gaps or risks; it
is never a substitute for a missing required mutation.

### 6.2 Independence

- REDTEAM must not be the sole author of the cells/shims it signs. If it
  authored any, a second reviewer signs those items.
- At least one required mutant per milestone is reproduced from a clean tree by
  a different operator/session.
- The signer confirms the baseline was green before every kill and that every
  mutation was reverted.
- A sign-off is void if the pins, contract hash, corpus hash, or cell spec
  changes afterward; re-sign is required.

### 6.3 Milestone checklist

| Milestone | REDTEAM MUST observe | Required mutation/canary | Gap rule |
|---|---|---|---|
| **E0** | hello-world triple green; shims marshalling-only; ABI result/error tests; pins complete; capability matrix with real logs; determinism | shim-smuggle canary + pin-drift canary | no unjudged in E0 harness; every TODO in `PINS.lock` filled or named blocker |
| **E1** | stack/push family; both tools attempted per cell; both directions; stack-observing postcondition; holdout differential | ≥3 E1 mutants incl. `M-E1-001`; model + core-copy kill | zero unjudged |
| **E2** | flow/numeric/hash; boundary corpus; error-kind cells; hash-tool applicability recorded | ≥4 E2 mutants; model + core-copy kill | zero unjudged; named gaps only |
| **E3** | CHECKSIG/CMS; symbolic checker contract; NULLDUMMY/NULLFAIL/DER/high-S; error-enum equality | ≥5 E3 mutants incl. CMS order and error-kind; model + core-copy kill; checker canary | zero error-enum gaps; crypto seam named |
| **E4** | witness v0/taproot dispatch; P2SH/P2WSH nesting; annex/OP_SUCCESSx; dispatch matrix | ≥5 E4 mutants; model + core-copy kill | seam-unjudged enumerated; no generic bucket |
| **E5** | whole-function `VerifyScript` or scoped residual with one named feature; SAW invariants; exception path; patch preservation | ≥1 whole-function/dispatch mutant; unpatched-Core differential | residual named; no hidden path |
| **E6** | 183 SCR rows green or filed; certificate replay; matrix; pins; trust base | full required set killed/equiv; sample re-run | zero `UNJUDGED`; every gap dispositioned |

### 6.4 E0 detail

E0 is a harness milestone, so its mutants are canaries:

1. **Shim smuggle canary:** one-line fast path in a copy; review/static check
   must catch.
2. **Pin drift canary:** altered `PINS.lock` in a copy; `gate-ir-pin` must fail.
3. **Contract conformance:** result `0/1/2/3` and error kind on malformed,
   zero-length, out-of-range, and exception tapes.
4. **Determinism:** two clean builds → identical IR hashes; two runs → same
   verdict/error.
5. **Capability matrix:** Alive2/SAW logs for hello-world and documented limits
   (invoke, indirect call, ptrtoint, loops, LLVM version), including
   `F-TOOL-001` (R/Alive2 inapplicable at the current pin).
6. **No fabricated runs:** every claimed tool invocation has a log hash.
7. **Pins:** `[core] build` and `[rbitcoin] build` are filled or carry a named
   blocker; every cell record matches `PINS.lock`.

### 6.5 E1 detail (first semantic gate)

- `M-E1-001` (`OP_SWAP` no-op) is the first required kill; it is
  verdict-observable, flag-free, and cheap to reproduce.
- The first buildable gate batch is `cells/e1-stack/swap-order` and
  `cells/e1-stack/dup-order` (twin skeleton: push/NOP/VERIFY/DROP/DUP/SWAP).
  Other E1 gate cells are planned; they do not count until green. The required
  third E1 mutant blocks sign-off until a third gate cell lands; it is not
  replaced by a weaker test.
- The `swap-order` cell MUST use a script whose final truthiness changes when
  the swap is removed (see `MUTATIONS.md`), not a script that merely leaves the
  same truthy stack.
- At least one cell MUST expose internal stack state (leaf postcondition), so
  order mutants that preserve final truthiness are still killable.
- Both Alive2 and SAW are attempted on every E1 cell even if one is expected to
  carry the kill; the other result or its named inapplicability is recorded.
- A holdout differential and a corpus canary are required.

### 6.6 E2–E6 details

E2:

- Boundaries: 4/5-byte ScriptNum, negative zero, 201/202 ops, 520/521 push,
  1000/1001 stack, CLTV equality, MINIMALDATA, div/mod negative.
- Hash cells: if Alive2 cannot model hash externals, record the named feature;
  SAW overrides or differential must carry the mutation.
- Error-kind postconditions for `UNBALANCED_CONDITIONAL`, `OP_COUNT`,
  `SCRIPTNUM*`, `STACK_SIZE`.

E3:

- Symbolic checker is a shared abstraction on both sides; the certificate names
  it. A checker canary (wrong result for a known pair) must be caught.
- CMS order, NULLDUMMY, NULLFAIL, HIGH_S, count bounds, FindAndDelete,
  CODESEPARATOR, CHECKMULTISIGVERIFY error kind.
- Error enum: mechanical map, zero unmapped/aliases, reachable-error witness or
  gap for every value.
- Patch behavior preservation: unpatched vs patched binary on the full corpus;
  zero verdict/error divergences.

E4:

- Dispatch matrix: base, P2SH, P2WSH, P2SH-P2WSH, P2WPKH, taproot key path,
  taproot script path, unknown witness version.
- Witness stack order, P2SH redeem source, P2WSH hash, program length, leaf
  version, annex, OP_SUCCESSx, control block bounds.
- Seam-unjudged: enumerate every cell, name the feature (Schnorr/EC seam,
  etc.), and give residual risk; do not count them as green.

E5:

- One whole-function proof or a scoped residual naming one blocking feature and
  the exact paths excluded.
- SAW loop invariants and exception edges recorded; proof object hash.
- Unpatched Core differential over the full corpus; any patch must be
  behavior-preserving.
- A dispatch-level mutant killed at whole-function scope where expressible.

E6:

- 183 SCR rows: green cell or filed gap; `gate-ir-pin` and `make equiv` pass.
- Certificate replay sample; matrix published; trust base and same-crypto
  premise stated.
- All required E1–E4 mutants killed or equivalent-adjudicated; no surviving
  semantic mutant.
- No open S1/S2 findings; all gaps dispositioned; no `UNJUDGED`.

### 6.7 Refusal triggers

REDTEAM MUST refuse sign-off if any of the following holds:

- a required mutation survived, is invalid, or lacks a witness;
- a mutant is still applied, or a revert hash does not match;
- baseline was not green before the mutant run;
- a cell was strengthened/narrowed after seeing the mutant without re-running
  the full baseline and mutant set;
- a shim contains engine logic or a byte-preservation test fails;
- a pin, contract, corpus, or spec hash is missing, stale, or unverifiable;
- a certificate/log is missing, replayed, or unbound;
- an error enum value is unmapped or aliased without disposition;
- an `UNJUDGED` cell is counted as judged/coverage;
- a gap lacks a named blocking feature or a tool log;
- an open S1/S2 finding blocks an affected cell;
- the sample replay fails or the tree is dirty outside declared patches.

---

## 7. Findings and dispositions

Every REDTEAM result is an `RT-<nnn>` finding in `findings/redteam/`. A finding
that affects a cell ledger entry is promoted by the owning role to an
`F-<area>-<nnn>` finding; the RT id is cited.

Dispositions:

| Disposition | Meaning | Required evidence |
|---|---|---|
| `fixed` | apparatus/source corrected | new run + hashes; re-test |
| `accepted-risk` | residual accepted with named scope | written rationale + human sign-off |
| `rejected` | false positive | counter-evidence + second reviewer |
| `open` | unresolved | blocks affected green claims |

Rules:

- No green claim may hide an open S1/S2 finding.
- Counterexamples are preserved verbatim (tape bytes + expected/actual).
- A finding is never closed by deleting the cell, renaming the status, or
  narrowing the domain without a contract/ledger change.
- Findings are append-only; corrections are new entries.

Severity:

- **S1:** invalidates a milestone claim or a published green result.
- **S2:** invalidates a family/cell or a required mutation.
- **S3:** localized apparatus defect with a workaround.
- **S4:** process/documentation issue.

---

## 8. Cadence and handoffs

- **Before a milestone:** freeze corpus/pins, run the B-gate, record the
  baseline bundle.
- **During the milestone:** apply required mutants as cells land; run harness
  canaries; keep mutant records current.
- **At sign-off:** full required set, holdout differential, sample replay,
  gap audit, sign-off record.
- **After a re-pin:** all prior sign-offs are void for the new pin; re-run the
  affected cells and at least one mutant per family.

Handoffs follow `GOAL.md`: `findings/handoffs/<from>-to-<to>-<topic>.md`.
REDTEAM proposes fixes; it does not write outside its scope.

---

## 9. Open calibration items

These are design questions, not waivers:

1. **Generated twin mutability:** if the twin is generated, model-site
   mutation is preferred; generated-C++ mutation is still required to test the
   proof. The mapping between the two must be recorded.
2. **Core-copy mechanics:** detached worktree vs copied tree; both must be at
   the pin, rebuilt from scratch, and never registered as a patch.
3. **External/hash semantics in Alive2:** whether a hash/crypto mutant can be
   proven non-equivalent with uninterpreted externals; SAW overrides or
   differential may be the only catchers.
4. **Error precedence:** the contract does not yet define which error wins when
   multiple violations exist; this is a §3.5 finding until resolved.
5. **Unjudged budget:** the 20% review trigger is a policy proposal; human
   sign-off is still required.
6. **Certificate authenticity:** deterministic proofs have no nonce; binding
   plus replay is the current substitute. Record the trust boundary.
7. **R canary:** optional `rust-copy` mutants may be added in E3/E4 if R-specific
   blind spots are suspected.

Until these are resolved, the affected results are `SIGNED-WITH-RESIDUALS` at
best, never unconditional.
