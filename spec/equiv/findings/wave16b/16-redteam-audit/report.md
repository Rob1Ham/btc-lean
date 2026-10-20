# Wave 16b / 16 — independent red-team audit of PR #29

- **Audited head:** `805c804` (`fix(equiv): drop absolute checkout fallback in mk_leaf.py`), branch `equiv/llvm-three-leg`
- **Audit checkout:** `/tmp/opencode/wave16b/16-redteam-audit`
- **Method:** read-only replay of generated artifacts and certificates; controlled destructive probes in a scratch copy
  (`/tmp/opencode/wave16b-scratch/16-redteam-audit/probe-gate`); source inspection of cells, mutation records, and
  run reports. No shared tree, pin, or result file was modified.
- **Scope:** certificate/IR provenance, green-row claims, tool markers, anti-overclaim language, mutation coverage,
  and ledger/status freshness.

## Verdict

**Not a clean pass.** The *arithmetic* of the generated matrix is internally consistent, and several important
anti-overclaim disclosures are present. However, the head does **not** carry replayable certificates or mutation
evidence for the claims it publishes:

- **E1 is marked `PASS (cells + mutations)` in `results/STATUS.md` even though no required E2/E3/E4 mutation set is
  complete and all eight official mutant records remain `applied` / `pending` with no witness or log hashes.**
- **6 of 8 mutation run reports paste green Alive2/SAW tails while asserting `KILLED`.**
- **32 of 45 `certificate.sha256` files fail `sha256sum -c` from a fresh checkout; 30 of them cite a
  `mk_leaf.py` hash (`dafb4080…`) that does not exist at the audited head (`709b50d0…`).**
- The advertised `gate-ir-pin` gate does not verify certificate hashes at all: zeroing a certificate still yields
  `RESULT: PASS`.
- Two of the four green SCR rows are materially overclaimed (`SCR-074` is an empty-stack-only proof labelled
  `full`; `SCR-071/072` NOP4..10 is seven calls to one undifferentiated helper, and OP_RETURN is
  `(syntactically equal)`).
- 159 rows are `gap`, but **none** carries the command/log-sha256/closed-list feature required by
  `PROTOCOL.md` §5.2. Under the protocol's own rules they are effectively `UNJUDGED`, so
  “183/183 adjudicated” and E6 PASS are inflated.

The honest summary is: **some results may be reproducible on the author's machine, but the commit does not bind
them.** Green rows are evidence-tier claims, not certificate-backed facts.

## Findings

| ID | Sev | Finding | Primary evidence |
|---|---|---|---|
| S1-1 | S1 | E1 “PASS (cells + mutations)” is unsupported; required mutation sets are incomplete and all official mutant records are still pending | `results/STATUS.md:19`; `MUTATIONS.md:189-192`; `cells/_redteam/mutants/*.json` |
| S1-2 | S1 | 6/8 mutation run reports assert `KILLED` while pasting green Alive2/SAW output | `cells/_redteam/runs/*.md` |
| S1-3 | S1 | Certificate provenance is not replayable at the audited head | 32/45 `sha256sum -c` failures; 30 stale `mk_leaf.py` digests |
| S2-1 | S2 | The “core-copy” mutation targets a cell-local leaf that never existed in git, not patched Core at `cce32b168` | `M-E1-001-core-copy-…-5587a89d.json`; `c_leaf.cpp` is `d828dd3a…` |
| S2-2 | S2 | `SCR-074` is labelled `scr_row_coverage: full` but the cell only exercises an empty stack; guard-threshold mutants survive | `cells/stack-ops/C-L-arity/spec.md:22-24`; `cells/_tools/arity/c_leaf.cpp:6-28` |
| S2-3 | S2 | `SCR-071/072` claims NOP1 and NOP4..10 execution, but the cell calls one helper seven times; OP_RETURN Alive2 is a syntactically equal identity | `cells/_tools/control/c_leaf.cpp:44-55`; `alive2/result.txt:10-17` |
| S2-4 | S2 | Gap admissibility is not met: 159 gaps, 0 exact commands, 0 log hashes, 0 closed-list features; yet coverage prints PASS | `spec/db/equiv-cells.yaml`; `PROTOCOL.md:569-591` |
| S3-1 | S3 | `gate_ir_pin.py` advertises “pins + hashes” but implements no certificate/hash check | `tools/gate_ir_pin.py:15-17`; tamper probe below |
| S3-2 | S3 | E5 checksum manifest is stale and incomplete | `cells/e5-whole/SHA256SUMS` rc 1 |
| S3-3 | S3 | Every green SAW proof sets `check_safety=false`; UB/definedness is unchecked and undisclosed | `cells/_tools/gate/run_saw.sh:34-35`; `cells/e2-numeric/within-boundary/src/cell.saw:14-15` |
| S4-1 | S4 | `results/LEDGER-REPORT.md` §5 is a pre-E1 snapshot (0 cells, 183 planned, “tools/ does not exist”) | `results/LEDGER-REPORT.md:108-124` |
| S4-2 | S4 | `docs/TRUST-BASE.md` still says `spec/equiv/` is untracked (P5, P15, table at line 152) | `docs/TRUST-BASE.md:40,50,152,330` |
| S4-3 | S4 | `cells/INDEX.md` claims `stack/C-L-dup-drop-swap` covers `SCR-076`; the cell spec covers `SCR-074/078` | `cells/INDEX.md:17`; `cells/stack/C-L-dup-drop-swap/spec.md:32` |
| S4-4 | S4 | `F-DIV-002` resolution cites a stale twin hash | `findings/differential/F-DIV-002-…md:5` (`d560a5f6…`) vs `b9ed129b…` |

---

## S1 — invalidates a milestone claim or published green result

### S1-1. The E1/E2/E3/E4 mutation requirement is not met, and the records say so

`results/STATUS.md:19` publishes:

> **E1** … **PASS (cells + mutations)** … 8 mutation runs killed (7 distinct IDs)

`findings/redteam/redteam-report.md` (around line 254) repeats:

> **Result:** PASS for the E1/E2/E3/E4 mutation requirement: seven distinct mutant IDs …

But `cells/_redteam/MUTATIONS.md:189-192` defines required sets:

| Family | Required | Executed at this head |
|---|---|---|
| E1 | 3 distinct + model + core-copy | `M-E1-001`, `M-E1-002`, `M-E1-006`, `M-E1-008` (one twin family, one mislabelled “core-copy”) |
| E2 | 4 distinct (`001`, `002`, `005`, plus one of `003/004/008/009`) | **0** |
| E3 | 5 distinct (`001`, `002`, `003`, `008`, plus one of `004-007`) | **1** (`M-E3-008`) |
| E4 | 5 distinct (`001`, `002`, `003`, `004`, `007`) | **1** (`M-E4-004`) |

Seven distinct IDs across all families do not satisfy `4 + 5 + 5` required E2/E3/E4 mutants.

Worse, the official records for every executed run never left the pending state. Example
(`cells/_redteam/mutants/M-E1-001-twin-20261019T224023Z-6f0d5531.json`):

```json
"status": "applied",
"outcome": "pending",
"classification": null,
"observed": null,
"witness": null,
"log_hashes": []
```

The same fields are present in all eight non-revert records, including `M-E3-008` and `M-E4-004`. Only the separate
`.revert.json` files say `status: reverted`. There is no `KILLED` outcome, no witness, no classified reason, and no
log digest in the machine-readable record. A reviewer cannot distinguish a kill from a survivor from these files.

### S1-2. The run reports contradict their own pasted logs

Six of eight run reports claim `KILLED` and paste tool output that says the mutant is green:

| Run report | `Transformation seems to be correct` | `STATUS=saw-green` | Verdict line |
|---|---|---|---|
| `M-E1-001-twin-…md` | 1 | 1 | `KILLED` |
| `M-E1-001-core-copy-…md` | 1 | 1 | `KILLED` |
| `M-E1-002-twin-…md` | 1 | 1 | `KILLED` |
| `M-E1-006-twin-…md` | 1 | 1 | `KILLED` |
| `M-E1-008-twin-…md` | 3 | 1 | `KILLED` |
| `M-E2-010-twin-…md` | 2 | 1 | `KILLED` |

For example, `M-E1-001-twin-…md:14-16` says:

```
- mutant: alive2=`alive2-not-green`, saw=`saw-not-green`
- reverted: `True`; baseline after revert: alive2=`alive2-green`, saw=`saw-green`
- **KILLED**
```

while the pasted mutant tail at lines 43 and 50 says:

```
Transformation seems to be correct!
STATUS=alive2-green
```

Only `M-E3-008` and `M-E4-004` paste genuinely non-green tails. Genuine failing logs do exist elsewhere
(`findings/cells/mutations/raw/M-E1-001-alive2.txt:630`, `Transformation doesn't verify!`), but they are for a
different mutant hash (`54fed644…`) and a disposable copy, not the record’s `e83ec0a2…`.

This is not a cosmetic inconsistency: it means the `KILLED` label was not derived from the log in the report.

### S1-3. Certificates do not bind the audited head

`EVALUATION.md:21` and `Makefile:12` tell reviewers that `gate-ir-pin` enforces “pins + hashes”. The cell notes then
tell reviewers to run `sha256sum -c` from a checkout (e.g. `cells/e3-cms/C-L-cms-1of1/notes.md:23-29`).

From a fresh worktree at `805c804`, **32 of 45 certificates fail**:

```bash
cd /tmp/opencode/wave16b/16-redteam-audit
for c in $(find spec/equiv/cells -name certificate.sha256); do
  sha256sum -c "$c" >/dev/null 2>&1 && echo "OK $c" || echo "FAIL $c"
done | sort | uniq -c
```

Result: **13 OK / 32 FAIL**. The 13 passes are nine `behavior/` transcript certificates plus four certificates
that contain absolute `/home/ubuntu/btc-lean-public/...` entries; the latter only pass because that external
checkout happens to exist and still contains the old `mk_leaf.py`.

Two independent causes:

1. **Stale generator hash.** 30 certificates hash `spec/equiv/cells/_tools/mk_leaf.py` as
   `dafb4080901010e6479e000b5796ab51966c7bea9e70b1a16b6bb35de24b14c5`. At `805c804` the file is
   `709b50d0aefcdbe619341d3ab79fcbf3b02f16f64769a7f4cb60d5e23baf6cc8` (commit `805c804` changed it and did not
   regenerate certificates). 28 fail outright; the 2 arity certificates pass only against the external checkout,
   which still has `dafb4080…`.
2. **Untracked build inputs.** Every `alive2/` and `saw/` certificate lists files under `cells/<...>/build/`.
   `spec/equiv/.gitignore:5` ignores `build/`, so those files cannot exist in a clean checkout. Even the two
   absolute-path arity certificates are only verifiable on the author’s machine.

This is a provenance failure, not proof that the underlying Alive2/SAW runs were false. It does mean the commit
cannot substantiate them.

---

## S2 — invalidates a family/cell or a required mutation

### S2-1. “Core-copy” is not Core

`cells/_redteam/runs/M-E1-001-core-copy-…md:6` names the target:

```
- **target:** `cells/_tools/gate/c_leaf.cpp`
- **target sha256 before:** `5587a89d…`
```

`5587a89d…` does not exist in git history: `git show HEAD:spec/equiv/cells/_tools/gate/c_leaf.cpp` is
`d828dd3a…`. The mutation was applied to a local variant and “restored” to a hash that the repository never had.
`M-E3-008` and `M-E4-004` likewise target `cells/_tools/e3/cellsig/l_cms.cpp` and `cells/_tools/e4/l_cell.cpp`.

`PROTOCOL.md` §2.2 defines `core-copy` as “patched Core copy (test-only) at the pinned commit”. A cell-local
line-cited leaf is not that. The report’s own “Residual” paragraph admits the application is a source excerpt, but
the milestone table still counts it as the required core-copy. The result is that the C-side sensitivity claim is
tested against a file that is neither Core nor reproducible.

### S2-2. `SCR-074` `full` coverage is empty-stack-only

`cells/stack-ops/C-L-arity/spec.md:22-24` says:

```
scr_row_coverage: full — every opcode in the 2DROP..TUCK arity set is
  exercised at an empty stack (n=0) against its per-case Core guard ...
```

But `cells/_tools/arity/c_leaf.cpp` implements every cell as:

```c
BINLINE uint32_t g2(const BStack& s) { return s.n < 2 ? 18 : 0; }
BINLINE uint32_t g6(const BStack& s) { return s.n < 6 ? 18 : 0; }
#define CELL(name, guard) \
  extern "C" uint64_t name() { BStack s; b_clear(s); return b_pack(0, guard(s), s); }
CELL(cell_2rot, g6)
```

Every guard returns `18` at `n = 0`. A mutant changing `g6` to `g2` (2ROT threshold 6→2), or `g2` to `g1`, is
observationally identical in this cell. The proof therefore cannot detect a wrong arity threshold, which is the
only thing `SCR-074` is about. The success branches for 2DROP/2DUP/3DUP/2OVER/2ROT/2SWAP/IFDUP/NIP/OVER/PICK/ROLL/TUCK
are not covered by any cell, and the spec’s disclaimer that they are “covered by the other E1 cells” is not backed by
a row→cell mapping.

### S2-3. `SCR-071/072` NOP coverage is one helper called seven times

`cells/_tools/control/c_leaf.cpp:44-55`:

```c
extern "C" uint64_t cell_nop4_to_10() {
  BStack s; b_init(s);
  e = core_nop_upgradable(s); ...
  e = core_nop_upgradable(s); ...   // seven identical calls
}
```

There is no per-opcode dispatch (`OP_NOP4` … `OP_NOP10`). The cell proves that seven calls to the same function
return the same packed value; it does not distinguish the opcodes, and a mutation in the dispatch table or in one
opcode’s handler would not be observed. Meanwhile `cells/control-flow/C-L-nop-return/alive2/result.txt:10-17`
records OP_RETURN as:

```
  ret i64 12
  ret i64 12
Transformation seems to be correct! (syntactically equal)
```

Both sides of the OP_RETURN leg are the same literal `ret i64 12`; the Alive2 run says nothing about the error
mapping claimed by `SCR-069`. This is the reason `SCR-069` should not be green on the strength of this cell.

### S2-4. The 159 gaps are not admissible, so “183/183 adjudicated” is inflated

`coverage_report.py --strict` prints PASS and `results/STATUS.md`/docs describe 183/183 adjudicated. But
`PROTOCOL.md` §5.2 requires each gap to carry:

- tool(s) attempted, exact command, log sha256, exit status;
- the exact blocking IR feature from the closed list;
- evidence for why a smaller cell cannot express it;
- mitigation, residual risk, owner, review date, second reviewer.

Measurement over `spec/db/equiv-cells.yaml`:

| Check | Count |
|---|---|
| `status: gap` rows | 159 |
| gap notes containing a 64-hex digest | **0** |
| gap notes containing a log filename (`.txt`/`.log`) | **0** |
| gap notes containing a command-like token | **0** |
| gap notes citing a finding | 20 |
| generic “no bounded … cell covers this row” | 125 |
| “whole VerifyScript/EvalScript path is the E5 scoped residual” | 17 |
| auto-generated “partial row coverage” | 17 |

No gap names a closed-list feature. Under §5.1/§5.2 these are `UNJUDGED`, not `GAP`, and `E6` requires zero
`UNJUDGED`. The generated PASS is measuring “a non-empty string exists”, not admissibility.

---

## S3 — localized apparatus defect with a workaround

### S3-1. The hash gate does not check hashes

`tools/gate_ir_pin.py:15-17` says so itself:

```
Known TODOs (not implemented): certificate hash verification, cross-checking
record leg fingerprints against PINS.lock, and per-cell Alive2/SAW result
parsing.
```

Probe (scratch copy, approved): zero the first two digests in
`cells/e1-stack/swap-order/alive2/certificate.sha256`, then run the advertised gate:

```bash
python3 tools/gate_ir_pin.py
# ...
# RESULT: PASS
# gate_rc=0
```

`results/scripts/update_ledger.py --check` and `results/scripts/coverage_report.py --strict` both catch the tamper
(rc 1, `digest does not match result.txt`). So the defect is gate wiring: the gate that `EVALUATION.md:21` and
`Makefile:12` advertise as “pins + hashes” is not the gate that checks hashes. A reviewer trusting `make gate-ir-pin`
would sign off a tampered certificate.

### S3-2. E5 checksums are stale and incomplete

```bash
cd spec/equiv/cells/e5-whole
sha256sum -c SHA256SUMS
# ../../findings/e5/E5-RESIDUAL.md: FAILED
# sha256sum: WARNING: 2 listed files could not be read
# rc=1
```

Recorded `03bcd8ca34f57d97a5b451be95851a33422c6c2640ac79b33cdc3a9d0be9a2ae`; actual
`04a3d91a9c0feeeab35eef5d5a3f20e7d1e01d11fe8eb6bde822dea34c704b3c`. `./build/abi-stub.ll` and
`./build/build-module.sh` are also listed but absent (ignored `build/`). The E5 residual disclosure is thus not
checksum-bound either.

### S3-3. SAW proofs disable safety checking, and this is not disclosed

`cells/_tools/gate/run_saw.sh:34-35` generates:

```saw
llvm_verify mC "$FN" [] false spec abc;
llvm_verify mL "$FN" [] false spec abc;
```

The fourth argument `false` is `check_safety`; the empty override list is not a safety specification. The same
pattern appears in hand-written specs (`cells/e2-numeric/within-boundary/src/cell.saw:14-15`,
`cells/e2-hash/hash160-vector/src/cell.saw:21-24`). So SAW proves the postcondition only on defined executions; UB
in the harness or in a branch outside the postcondition is not excluded. No cell spec or trust-base entry mentions
this. Also, Alive2 logs record only `alive-tv: Ubuntu LLVM version 20.1.2`; the pinned Alive2 tag/commit
(`v20.0`, `c0f5434f…`) is in `PINS.lock` but not in the per-cell transcript.

---

## S4 — documentation/process

- **S4-1:** `results/LEDGER-REPORT.md:108-124` still says “No LLVM cells yet … all 183 rows are planned”,
  “`spec/equiv/tools/` does not exist”, and “Pins incomplete … TODO”. All are false at `805c804`. A reader who opens
  the ledger report instead of `STATUS.md` gets the pre-E1 state.
- **S4-2:** `docs/TRUST-BASE.md:40,50,152,330` still says `spec/equiv/` is untracked at the model revision. It is
  tracked on this branch, and the PR head is a commit. P15 (“Results are reproducible from the tree”) should be
  downgraded anyway because of S1-3.
- **S4-3:** `cells/INDEX.md:17` says `stack/C-L-dup-drop-swap` covers `SCR-074/076/078`; the cell’s own
  `spec.md:32` says `SCR-074, SCR-078`. `SCR-076` is actually covered by `e1-stack/depth-count`. The index row is
  wrong and could double-count.
- **S4-4:** `findings/differential/F-DIV-002-twin-equal-false-encoding.md:5` says the bug is “no longer reproducible
  against `d560a5f6…`”, but the current tracked twin is `b9ed129b9a0bd719da789c7accab7e522f436b08eb33e8cd18874659edeea72b`
  (line 18). The resolution hash is stale.

---

## What is actually clean / verified

These checks passed and are worth keeping:

1. **Generated artifacts are self-consistent.** From `spec/equiv`:
   - `python3 results/scripts/build_matrix.py --check` → rc 0
   - `python3 results/scripts/coverage_report.py --strict` → rc 0, `strict: PASS — all 183 SCR rows adjudicated`
   - `python3 results/scripts/update_ledger.py --check` → rc 0, `changes: 0`
   - `python3 tools/gate_ir_pin.py` → rc 0, `failures: 0`
   - `python3 tools/check_pins.py` → rc 0
   - `spec/db/equiv-cells.yaml` is `62d8b6f4…`, matching the hash printed in `results/matrix.md:3`.
2. **Contract and IR manifest.** The v3 recipe recomputes the recorded contract
   `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`; `ir/manifest.json` is
   `bef064dbca8c9884906ad8eec8922ca8ae369fb0479db7c0659c30ca7ad8808e`, and the eight recorded artifact hashes
   under `/tmp/opencode/ir-pipeline/artifacts` match.
3. **Tool pins are real.** `/usr/local/bin/alive-tv` resolves to `/opt/equiv-tools/alive-tv-v20.0`; both hash
   `91d9c14af27444c5248b948437b64e9dc7b0ed63d1bf478305a1e9cef2ed50ff`. The SAW path in `PINS.lock` exists.
4. **No fabricated green markers.** All 17 cell result files carry green markers; there are no negative
   Alive2/SAW markers hidden in green cells. `unsafe_assume` appears only in `cells/e2-hash/hash160-vector/src/cell.saw`,
   which is a `partial`/gap row and is disclosed.
5. **No whole-engine equivalence overclaim.** The prose explicitly discloses the R proof absence, the crypto seam,
   and the E5 whole-engine residual. The matrix has only 4 green rows, 20 seam rows, and 159 gaps, not 183 greens.
6. **Wave 16b cells are not evidence.** The 17 wave16b worktrees contain new cells that are untracked
   (`?? spec/equiv/cells/...`) and uncommitted. Sampled cells (`limits/C-L-opcount`,
   `hash-ops/C-L-hash-compose`, `tapscript/C-L-taproot-annex`, `policy-flags/C-L-nullfail`) are internally
   consistent, but they are not merged and must not be cited as proof. The hash-compose cell uses `unsafe_assume`
   and is explicitly `partial`.

## Remediation (minimum for sign-off)

1. **Regenerate certificates at the audited commit.** Make all paths repo-relative; remove the absolute
   `/home/ubuntu/...` entries; either commit the build inputs or define certificates over tracked inputs plus a
   transcript hash. Update every `mk_leaf.py` digest to `709b50d0…` and rerun `sha256sum -c` for all 45.
2. **Re-run the required mutation sets from a committed tree.** Populate `outcome`, `classification`, `observed`,
   `witness`, and `log_hashes` in each mutant record; do not leave `status: applied` after revert. Fix the six run
   reports whose pasted tails contradict `KILLED`. Report E2 0/4, E3 1/5, E4 1/5 honestly until complete.
3. **Make `core-copy` actually Core.** Point it at the patched Core copy at `cce32b168`, record the commit and
   target hash, and re-run. Delete the `5587a89d…` claim, which has no git provenance.
4. **Fix or stop advertising the gate.** Implement certificate/hash verification in `gate_ir_pin.py`, or have
   `make gate-ir-pin` invoke `update_ledger.py --check` and `coverage_report.py --strict`. The tampered-certificate
   probe must fail the gate.
5. **Downgrade or extend the two overclaimed rows.**
   - `SCR-074`: add boundary cases at `n = 1..6` per opcode (or at least one below/at/above each threshold), or set
     `scr_row_coverage: partial` and file the uncoved branches as gaps.
   - `SCR-069/071/072`: add per-opcode dispatch witnesses; for OP_RETURN, mutate the error mapping (not the return
     constant) so Alive2 is not `(syntactically equal)`.
6. **Make the gap ledger admissible.** Either supply the §5.2 fields (command, log sha256, closed-list feature,
   decomposition rationale, owner/reviewer) for all 159 gaps, or reclassify them as `UNJUDGED` and recompute E6.
   The current “183/183 adjudicated” line must not survive.
7. **Refresh E5 checksums and documentation.** Regenerate `cells/e5-whole/SHA256SUMS`; update
   `LEDGER-REPORT.md` §5, `TRUST-BASE.md` P5/P15, `cells/INDEX.md`, and `F-DIV-002` to the current tree.
8. **Disclose SAW `check_safety=false`** in each green cell’s `trust_note` and in `TRUST-BASE.md`, and record the
   Alive2 tag/commit (not just the LLVM version) in per-cell transcripts.

## Reproduction appendix

```bash
# 1. Certificate replay from the audited worktree
cd /tmp/opencode/wave16b/16-redteam-audit
fail=0; ok=0
for c in $(find spec/equiv/cells -name certificate.sha256); do
  if sha256sum -c "$c" >/dev/null 2>&1; then ok=$((ok+1)); else fail=$((fail+1)); fi
done
echo "ok=$ok fail=$fail"          # ok=13 fail=32

# 2. Stale generator digest
sha256sum spec/equiv/cells/_tools/mk_leaf.py
# 709b50d0… ; 30 certificates cite dafb4080…

# 3. E5 manifest
cd spec/equiv/cells/e5-whole && sha256sum -c SHA256SUMS; echo rc=$?   # rc=1

# 4. Gate tamper probe (scratch copy only)
rm -rf /tmp/opencode/wave16b-scratch/16-redteam-audit/probe-gate
mkdir -p /tmp/opencode/wave16b-scratch/16-redteam-audit/probe-gate
cp -a /tmp/opencode/wave16b/16-redteam-audit/spec \
      /tmp/opencode/wave16b-scratch/16-redteam-audit/probe-gate/spec
C=/tmp/opencode/wave16b-scratch/16-redteam-audit/probe-gate/spec/equiv/cells/e1-stack/swap-order/alive2/certificate.sha256
sed -i 's/^[0-9a-f]\{64\}/0000000000000000000000000000000000000000000000000000000000000000/' "$C"
cd /tmp/opencode/wave16b-scratch/16-redteam-audit/probe-gate/spec/equiv
python3 tools/gate_ir_pin.py; echo gate_rc=$?          # PASS, rc=0
python3 results/scripts/update_ledger.py --check; echo ledger_rc=$?   # rc=1
python3 results/scripts/coverage_report.py --strict; echo cov_rc=$?   # rc=1

# 5. Mutation record state
python3 - <<'PY'
import glob, json
for f in sorted(glob.glob("spec/equiv/cells/_redteam/mutants/*.json")):
    if f.endswith(".revert.json"):
        continue
    d = json.load(open(f))
    print(f.split("/")[-1], d["status"], d["outcome"], d["witness"], d["log_hashes"])
PY

# 6. Run-report contradiction count
for f in spec/equiv/cells/_redteam/runs/*.md; do
  printf '%s correct=%s sawgreen=%s killed=%s\n' "$(basename "$f")" \
    "$(grep -c 'Transformation seems to be correct' "$f")" \
    "$(grep -c 'STATUS=saw-green' "$f")" \
    "$(grep -c 'KILLED' "$f")"
done
```

## Limitations

- This audit did not attempt to rebuild the cells or rerun Alive2/SAW from scratch; it audited the binding between
  claims, records, certificates, and logs. A certificate failure here is a provenance finding, not a disproof of the
  underlying result.
- Severity follows `cells/_redteam/PROTOCOL.md:803-806` (S1 invalidates a milestone claim; S2 invalidates a
  family/cell or required mutation; S3 localized apparatus defect with a workaround; S4 process/documentation).
- All destructive probes were confined to `/tmp/opencode/wave16b-scratch/16-redteam-audit/probe-gate`; no shared
  result, pin, or other worktree was modified.
