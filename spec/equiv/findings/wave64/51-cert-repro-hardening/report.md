# Wave 64 / 51 — fresh-checkout certificate reproducibility hardening

- **Task:** `51-cert-repro-hardening`
- **Branch:** `wave64/51-cert-repro-hardening`
- **Base / audited evidence tree:** `5946c024546e39f55775bfd9a077b042e3feeef4`
  (`5946c02`, "integrate checksig scriptcode, stack-op, pushonly, and 2DIV cells")
- **Date:** 2026-10-20
- **Mode:** read-only on evidence. No existing certificate, result, ledger,
  matrix, pin, or shared tool was modified. The only additions are this
  report and `tools/cert_repro_check.py`.
- **Verdict: FAIL for fresh-checkout replay.**
  - **2 / 295** cell certificates do not replay from a clean checkout.
  - **4 / 6** evidence checksum manifests do not replay from a clean
    checkout.
  - **293 / 295** cell certificates do replay cleanly.
  - No certificate line uses an absolute path or escapes the repository, but
    **145 cell certificates bind transcripts/IR containing machine-local
    paths** (378 hits) and **all 295 cell certificates cross-bind sibling
    leg output**; the one nested `divergence/` bundle leaks in both
    directions.

## 1. Exact checker command

Run from the repository root:

```sh
python3 spec/equiv/findings/wave64/51-cert-repro-hardening/tools/cert_repro_check.py \
  --rev HEAD --fuzz 64
```

Exit code `1` is expected at this commit because of the failures in §3.
The command creates a detached clean worktree at `HEAD`, replays every
certificate there, runs 73 detector mutations in a separate scratch
extraction, and removes both temporary trees.

Useful variants:

```sh
# cell certificates only (no SHA256SUMS / artifacts.sha256 manifests)
python3 spec/equiv/findings/wave64/51-cert-repro-hardening/tools/cert_repro_check.py \
  --cells-only --list-warnings 0

# fail on hygiene warnings as well as replay errors
python3 spec/equiv/findings/wave64/51-cert-repro-hardening/tools/cert_repro_check.py \
  --strict

# machine-readable output for CI
python3 spec/equiv/findings/wave64/51-cert-repro-hardening/tools/cert_repro_check.py \
  --json /tmp/cert-repro.json

# audit an existing clean checkout instead of creating one
python3 .../cert_repro_check.py --mode current --clean-root /path/to/clean/tree
```

`--mode archive` materializes `git archive <rev>` instead of using
`git worktree add`; `--mode current` audits the working tree in place.

## 2. What was audited

The clean worktree is created at the requested revision and therefore
contains **tracked files only**. That is the point of the replay: a
certificate that names a gitignored `build/` output may verify in a warm
working tree and still be unreplayable on a fresh clone.

| Target class | Count | Replayed | Failed |
|---|---:|---:|---:|
| `spec/equiv/cells/**/certificate.sha256` — Alive2 legs | 142 | 141 | 1 |
| `spec/equiv/cells/**/certificate.sha256` — SAW legs | 142 | 141 | 1 |
| `spec/equiv/cells/**/certificate.sha256` — behavior legs | 11 | 11 | 0 |
| **Cell certificates** | **295** | **293** | **2** |
| `SHA256SUMS` evidence manifests | 5 | 2 | 3 |
| `*.sha256` evidence manifests (`artifacts.sha256`) | 1 | 0 | 1 |
| **All targets** | **301** | **295** | **6** |

Replay volume: **5,036 digest lines**, **4,800 resolved file bindings**,
**28,644,756 bytes** hashed.

Checks applied to every target:

1. Parse `<sha256>  <path>` lines; reject malformed lines, absolute paths,
   non-POSIX paths, `..` escapes, and symlinks that escape the repository.
2. Resolve every path; require the file to exist in the clean checkout.
3. Require the path to be **git-tracked** at the audited revision; an
   untracked path matched by `.gitignore` is reported as `build-artifact`.
4. Recompute SHA-256 over the bytes.
5. Require each Alive2/SAW/behavior certificate to cover its own
   `result.txt`, `run.sh`, cell `spec.md`, and `notes.md`.
6. Require every tracked file belonging to the leg/cell record to be
   covered (build outputs excluded).
7. Detect machine-local checkout paths (`/tmp/opencode/...`, `/home/...`,
   `/workspace/...`, Windows drive paths, `file://`) inside certificate
   lines and inside certificate-bound files.
8. Detect cross-leg references and nested `divergence/` leakage relative to
   the cell root.
9. For non-`SHA256SUMS` checksum files, infer the base directory by which
   ancestor resolves the most entries (needed for
   `wave16b/08-r-harness/logs/artifacts.sha256`).

## 3. Replay failures (hard)

### F1 — `stack-ops/C-L-pick` certificates name gitignored builds

Both leg certificates are 135-line certificates; **112 lines each** name
files under `build-alive2/` or `build-saw/`:

- `spec/equiv/cells/stack-ops/C-L-pick/alive2/certificate.sha256`
  (lines 5–116): 55 `build-alive2/` + 57 `build-saw/` entries.
- `spec/equiv/cells/stack-ops/C-L-pick/saw/certificate.sha256`
  (lines 5–116): the same 112 entries.

Evidence:

```sh
git check-ignore -v \
  spec/equiv/cells/stack-ops/C-L-pick/build-alive2/build.txt
# .gitignore:4:build-alive2/  .../build-alive2/build.txt

grep -c 'build-alive2/\|build-saw/' \
  spec/equiv/cells/stack-ops/C-L-pick/alive2/certificate.sha256
# 112
```

The cell's own `.gitignore` explicitly lists `build-alive2/` and
`build-saw/` as regenerable and “not committed; the certificates name their
exact files”. That is exactly the unreplayable pattern: a fresh checkout has
none of those files. The certificates do correctly cover the 23 tracked
inputs (`spec.md`, `notes.md`, both `result.txt`/`run.sh`, `src/*`), so the
failure is additive, not a missing-result problem.

The existing gate also catches this failure **if the build directories are
absent**: `python3 spec/equiv/tools/gate_ir_pin.py` exits 1 at this commit
with `224 certificate issue(s)` (the same 224 lines). It does not catch the
untracked-but-present case, because it tests `p.is_file()` in the current
tree rather than git membership.

### F2 — `e5-whole/SHA256SUMS` has a stale digest

Line 22:

```text
04a3d91a9c0feeeab35eef5d5a3f20e7d1e01d11fe8eb6bde822dea34c704b3c  ../../findings/e5/E5-RESIDUAL.md
```

Actual digest at `5946c02`:

```text
18190ac4ee996afb1fa0e8c3d37434d118474b62dfd3561fc9b648af46618fe2
```

`E5-RESIDUAL.md` changed after the manifest was written (commit `befee3f`
touched the residual; `SHA256SUMS` was last updated in `16e6b86`). Every
other entry in this manifest verifies.

### F3 — `wave16b/03-e5-heap/SHA256SUMS` names a gitignored build script

Line 11:

```text
011754b402bb21d896473963518175c0ac4e0c2c4c0db5155903cdcf3f718817  build/build-heap-probe.sh
```

`build/` is ignored and absent from a clean checkout. The other 21 entries
verify.

### F4 — `wave16b/08-r-harness/logs/artifacts.sha256` uses absolute paths

The manifest is relative to `spec/equiv/findings/wave16b/08-r-harness/`
(the checker infers this base), not to `logs/`. Nine relative entries verify.
Lines 10–12 are absolute host paths and cannot exist on a fresh checkout:

```text
94a60b...  /tmp/opencode/wave16b-scratch/08-r-harness/libequiv-rust-r3.so
73e3d2...  /tmp/opencode/wave16b-scratch/08-r-harness/libequiv-rust-e0-baseline.so
5fef1d...  /tmp/opencode/cbuild/libequiv-core.so
```

The three files exist on the build host, which is why a local
`sha256sum -c` from the harness root appears to pass. They are not
reproducible inputs.

### F5 — `wave16b/11-patch-evalstep/SHA256SUMS` names 11 absent files

Lines 18–28 reference:

```text
spec/equiv/patches/proposals/wave16b/11-patch-evalstep/{README.md,
P-CORE-04-evalstep-proposal.patch, P-CORE-05-span-leaves-proposal.patch,
harness/build.sh, harness/driver.cpp, harness/erase_exceptions.py,
harness/gen_corpus.py, harness/ir_metrics.py, harness/leaf-experiment.cpp,
harness/mk_evalstep.py, harness/verify_move.py}
```

None is tracked at `5946c02`; the proposal directory does not exist. The
other 17 entries verify.

## 4. Hardening findings that do not break digest replay

These are reported as `warning` (or `info` where the dependency is an
expected shared input). `--strict` promotes warnings to a failure.

### W1 — Machine-local paths inside certificate-bound evidence

**145 cell certificates** bind **139 unique files** containing **378**
machine-local path hits. Because those files are tracked and
content-addressed, the digest replay succeeds; a *re-run* on another host
cannot regenerate the same bytes.

| Kind | Files | Hits | Example |
|---|---:|---:|---|
| Tracked `.ll` IR | 66 | 132 | `policy-flags/C-L-minimaldata-push/ir/c_cell_minimaldata_push.ll:1` — `ModuleID = '/tmp/opencode/equiv-pr/.../build/...bc'` |
| `result.txt` transcripts | 40 | 202 | `e1-stack/dup-order/behavior/result.txt:10` — `l_lib=/home/ubuntu/.../twin/build/libtwin.so` |
| `notes.md` / `spec.md` | 31 | 42 | `e4-witness/.../notes.md` — `/tmp/opencode/w32-probe`, `/tmp/opencode/core-pin` |
| Shared `.sh` tools | 2 | 2 | `cells/_tools/gate/run_behavior.sh:13` and `run_behavior_multi.sh:15` default `CELLS_CORE_LIB` to `/tmp/opencode/cbuild/libequiv-core.so` |

The 5 evidence manifests add one more target
(`artifacts.sha256`, 3 absolute lines), for 151 warning targets in total.

### W2 — Cross-leg and nested-`divergence` leakage

The normalizer
(`spec/equiv/tools/normalize_certificates.py`, `cell.rglob("*")`) makes each
certificate bind the **whole cell subtree**, not just its own leg. For a
certificate under `divergence/`, it additionally rewrites `cell` to the
parent, so divergence evidence and green evidence bind each other.

| Pattern | Certificates | Refs | Meaning |
|---|---:|---:|---|
| Alive2/SAW/behavior cert binds a sibling leg | 295 | 756 | Every cell certificate includes other legs' `result.txt`/specs. |
| Green cert binds `divergence/` | 2 | 16 | `exec-verify/C-L-w32-cleanstack/{alive2,saw}` each bind 8 divergence refs (the counterexample transcript). |
| Divergence cert binds outer leg | 2 | 12 | `.../divergence/{alive2,saw}` each bind 6 outer `alive2/`/`saw/` results. |
| Divergence cert binds the other divergence leg | 2 | 12 | `.../divergence/alive2` binds `divergence/saw/*`, and vice versa. |

This is not a digest failure, but it is a scope failure: a divergence
certificate cannot be read as standalone counterexample evidence, and a
green certificate's validity is coupled to unrelated leg/divergence output.
It also explains why the two `C-L-pick` failures appear in both leg
certificates with identical 112-line sets.

### W3 — Build paths inside certificate-bound IR/specs

**33 cell certificates** bind `.ll`/`.saw`/`.cry` files whose text names
`build/` artifacts (66 unique IR files). This is informational for replay
but prevents byte-identical regeneration at a different checkout path.

### W4 — Expected shared-input dependencies (info)

**251 cell certificates** bind **1,327** files outside their own cell. These
are expected shared inputs, not defects: `cells/_tools` (518),
`findings/wave16` (192), `contract/error_kind.h` (188), `twin/ops_ir.py`
(90), `twin/gen.py` (80), `twin/runtime.inc` (42), family `_shared` /
`_harness` tools, and `spec/core/Bitcoin/Interpreter/Defs.lean`.

## 5. Detector fuzz

`--fuzz 64` runs a **fixed 9-case battery plus 64 deterministic random
mutations**, seed `20261020`, in a scratch `git archive` extraction of the
same revision. Each mutation is applied, audited, and restored; the audited
worktree is never written.

| Measure | Result |
|---|---:|
| Mutations run | 73 |
| Caught | **73 / 73** |
| Missed | 0 |
| Positive controls (known-clean certs) | **2 / 2 clean** |

Mutation classes exercised:

- flip a byte in a referenced file → `digest-mismatch`;
- delete a referenced file → `missing-file`;
- append `/home/...` or `/tmp/opencode/...` to a bound transcript →
  `machine-path-in-content`;
- append an absolute certificate line → `absolute-path`;
- append `../` escape → `path-escape`;
- append an ignored `build/...` line → `build-artifact`;
- append a bad line digest → `digest-mismatch`;
- remove the `result.txt` line → `result-uncovered`;
- inject a valid `divergence/` line into a green cert →
  `nested-divergence`.

The positive controls guard against over-reporting: known-clean certificates
must produce zero errors.

## 6. What passes

- All 295 cell certificates parse; no malformed lines, no duplicate entries,
  no `# outside-root` lines, no absolute certificate paths, no `..` escapes,
  no escaping symlinks.
- Every leg certificate covers its own `result.txt` and `run.sh`; every cell
  certificate covers `spec.md` and `notes.md`.
- Every tracked file belonging to a cell/leg is covered by that leg's
  certificate (0 uncovered cell inputs).
- 293/295 cell certificates replay exactly from a clean worktree.
- Two evidence manifests replay cleanly:
  `findings/wave16b/05-e5-ptrtoint-stl/SHA256SUMS` and
  `findings/wave16b/12-witness-exec/pin-probe/SHA256SUMS`.

## 7. Why the existing checks did not close this

- `spec/equiv/tools/gate_ir_pin.py` verifies certificates **in place**. It
  checks `Path.is_file()` and recomputes the digest, but does not require the
  path to be git-tracked. A warm tree with `build/` present passes; a fresh
  checkout does not. At this commit its certificate section already fails
  with the same 224 `C-L-pick` lines.
- It only discovers `certificate.sha256`, so the five `SHA256SUMS` bundles
  and `artifacts.sha256` are invisible to it.
- `spec/scripts/check_reproducibility.py` scans tracked `.py`/`.sh` for the
  literal `/home/` but does not inspect certificate contents, `.ll`
  metadata, `result.txt` transcripts, or git membership.
- `normalize_certificates.py` solved the original build-path problem by
  hashing every file under the cell; this creates the cross-leg and nested
  divergence coupling reported in W2.

## 8. Smallest next actions (owner: CELLS / LEDGER, not this task)

1. Re-run `stack-ops/C-L-pick/alive2/run.sh` and `saw/run.sh`, then
   normalize that cell so both certificates cover tracked inputs only. Do not
   hand-edit the 112 lines.
2. Refresh `e5-whole/SHA256SUMS` line 22, or restore the residual content
   that the digest commits to. Pick one; do not silently accept either.
3. Drop `build/build-heap-probe.sh` from
   `wave16b/03-e5-heap/SHA256SUMS` or commit the script.
4. Replace the three absolute `.so` entries in
   `wave16b/08-r-harness/logs/artifacts.sha256` with tracked/relocatable
   references, or move them to a separately named external-artifact list.
5. Restore the 11 proposal files for
   `wave16b/11-patch-evalstep/SHA256SUMS`, or regenerate the manifest from
   what is actually tracked.
6. Make `normalize_certificates.py` leg-scoped (own leg + shared inputs) and
   keep `divergence/` certificates scoped to `divergence/`; then regenerate.
   This is the structural fix for W2.
7. For new runs, strip checkout roots from transcripts and IR module IDs
   before hashing (`-fdebug-compilation-dir`, `-ffile-prefix-map`, or a
   transcript sanitizer). This is the structural fix for W1/W3.

## 9. Files added

```text
spec/equiv/findings/wave64/51-cert-repro-hardening/tools/cert_repro_check.py
spec/equiv/findings/wave64/51-cert-repro-hardening/report.md
```

No result, certificate, ledger, matrix, pin, or shared tool changed.
`git diff --stat` for tracked files is empty; the additions are untracked
until the commit that follows this report.
