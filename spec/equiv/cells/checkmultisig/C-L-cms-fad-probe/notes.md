# Notes — `checkmultisig/C-L-cms-fad-probe`

- **repo_head:** `805c8042f92d3bed909ca40219a4d21fc9150cc1`
- **Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **contract:** v3 `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- **row:** SCR-115, `scr_row_coverage: partial` (FindAndDelete abstract;
  nSigs <= 2)
- **patches:** none
- **status:** Alive2 green (1/1, bidirectional, checker + FindAndDelete
  uninterpreted); SAW green (4/4 proofs, 2 cases).

## Reproduce

From the repository root:

```bash
bash spec/equiv/cells/checkmultisig/C-L-cms-fad-probe/alive2/run.sh
bash spec/equiv/cells/checkmultisig/C-L-cms-fad-probe/saw/run.sh
sha256sum -c spec/equiv/cells/checkmultisig/C-L-cms-fad-probe/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/checkmultisig/C-L-cms-fad-probe/saw/certificate.sha256
```

## Toolchain

| Tool | Version |
|---|---|
| clang/clang++ | Ubuntu clang 20.1.2 (0ubuntu1~24.04.3) |
| LLVM | Ubuntu LLVM 20.1.2 |
| alive-tv | Alive2 v20.0 (Ubuntu LLVM 20.1.2) |
| SAW | 1.6 (`68eed5f release-1.6`) |

## Design and the scope decision

`cell_cms_fad(nsigs, sigversion, constflag, script)`:

1. copies `scriptCode` (a 32-bit seam identity here),
2. runs Core's `for k in 0..nSigs-1` FindAndDelete fold in BASE only, latching
   SIG_FINDANDDELETE (54) when `found > 0 && CONST_SCRIPTCODE`,
3. runs the verification loop as a *probe*, recording the scriptCode handed
   to each checker call.

The row's Lean targets (`cms_fad_before_check_row`,
`cms_fad_all_sigs_before_check`, `cmsFadFold_succ`, `cmsFadFold_error_of_step`)
are statements about this fold and its position, with `findAndDelete` taken as
a function.  The cell therefore models `findAndDelete` as an **abstract seam
symbol shared by both legs** (`btc_equiv_find_and_delete`, returning
`(new_script << 32) | found`), exactly like the crypto checker:

- Alive2 ingests a bare declaration in both modules and quantifies over all
  behaviours of the symbol.
- SAW links one concrete instance (`_shared/checker_stub.cpp`), used only to
  produce a point-check of the fold.

The byte-walking deletion algorithm itself (interpreter.cpp:239-265,
Defs.lean:545-590) is **not** proved here.  That is SCR-098/INV-056, and it is
the precise missing piece recorded for this row.  The probe flags
(`call0 saw post-fold script`, `call1 saw call0`) are computed from the same
live `cur` variable the fold mutates, so a lazy or interleaved deletion would
change the packed trace.

## SAW cases

| Case | Checker stub | Path exercised |
|---|---|---|
| 0 | always false | one body then early exit; fold still applied twice |
| 1 | always true | two bodies; both checks see the post-fold script |

The FindAndDelete stub matches the model: `found = ((sc & 0xffff) == (push &
0xffff))`, `next = found ? sc + 0x100 : sc`.

## Anomaly fixed during development

- The oracle initially left `cur` unchanged on the CONST_SCRIPTCODE error
  path.  Core's `FindAndDelete(scriptCode, ...)` has already mutated the local
  before the error is raised, and the C leg exposes that value, so SAW found
  the mismatch at `ns=1, sv=0, cf=1, sc=0x111`.  The model now applies the
  returned script on that path too.
- The oracle initially ran the probe even when the fold latched an error
  (calls=1 vs 0).  `effPs` now resets the probe state when the fold is
  `done`, matching both legs (`errored` suppresses every checker call).

## Result detail

Alive2: `Transformation seems to be correct!`, 1 correct transformation,
0 errors.  SAW: 2 cases x 2 legs = 4 `Proof succeeded!` lines,
`STATUS=saw-green (4 proofs, 2 cases)`.

## Why partial

- FindAndDelete is abstract (algorithm = SCR-098/INV-056).
- The fold and probe loop are unrolled to nSigs = nKeys <= 2; the row allows
  20.  Larger counts are rejected by the guard.

## Limits

- Script content is a seam identity, not a byte array; the concrete GetOp walk
  is deliberately out of scope.
- nKeys = nSigs by construction; loop matching policy is SCR-116.
- Same-crypto premise for the checker.
