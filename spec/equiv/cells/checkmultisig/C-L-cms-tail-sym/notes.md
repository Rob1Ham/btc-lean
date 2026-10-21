# Notes — `checkmultisig/C-L-cms-tail-sym`

- **repo_head:** `805c8042f92d3bed909ca40219a4d21fc9150cc1`
- **Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **contract:** v3 `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- **rows:** SCR-118, SCR-119, SCR-120; `scr_row_coverage: full`
- **patches:** none
- **status:** Alive2 green (1/1, bidirectional, 8 symbolic arguments);
  SAW green (2/2 proofs, 1 case).

## Reproduce

From the repository root:

```bash
bash spec/equiv/cells/checkmultisig/C-L-cms-tail-sym/alive2/run.sh
bash spec/equiv/cells/checkmultisig/C-L-cms-tail-sym/saw/run.sh
sha256sum -c spec/equiv/cells/checkmultisig/C-L-cms-tail-sym/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/checkmultisig/C-L-cms-tail-sym/saw/certificate.sha256
```

## Toolchain

| Tool | Version |
|---|---|
| clang/clang++ | Ubuntu clang 20.1.2 (0ubuntu1~24.04.3) |
| LLVM | Ubuntu LLVM 20.1.2 |
| alive-tv | Alive2 v20.0 (Ubuntu LLVM 20.1.2) |
| SAW | 1.6 (`68eed5f release-1.6`) |

## Design

`cell_cms_tail(nkeys, nsigs, extra, fsuccess, nulldummy, wire, dummyLen,
dummyBytes)` starts at the state after the verification loop.  `fSuccess` is an
input, so the tail is proved for both loop outcomes without re-proving the
loop (SCR-116's cell).

- Cleanup is `i-1` pops with `i = nKeys+nSigs+3` (Core 1194-1205, Lean
  `cmsCleanup`); the slice computes the resulting depth arithmetically instead
  of running a symbolic-trip-count loop.
- `dummyBytes` is a symbolic input that appears in **no** right-hand side:
  the only use of the extra item's content is `stacktop(-1).size()` at the
  NULLDUMMY gate (line 1212).  This is the machine-checked form of SCR-118
  ("contents unchecked") and SCR-119 ("only size matters").
- The canonical test stack lays `extra` items of length 1 and value i+2 below
  the arguments, so a surviving prefix is visible and the pushed boolean
  cannot alias an element.
- Packing (`cms_pack_tail`) exposes result, error ordinal, depth, and the top
  three (len, value) pairs.

## Anomaly fixed during development

The first draft packed `err << 2` in the failure helper, but the tail layout
puts the ordinal at bits 1..6 (`err << 1`).  Alive2 caught the mismatch
between the C and L packers; the fix is `cms_fail_tail`.  A native driver then
cross-checked C, L and the Cryptol oracle on 237,276 combinations
(nKeys, nSigs, extra, fsuccess, nulldummy, wire, dummyLen) with 0 mismatches
before the final tool runs.

## Result detail

Alive2 reports one correct transformation and 0 errors.  SAW reports one
`Proof succeeded!` per leg and `CASE_0_OK`.  The checker stub is linked but
never called.

## Limits

- fSuccess is an input: the loop is not re-proved here.
- NULLFAIL (SCR-110) is off by domain; `pol.nullFail = false`.
- The depth field is six bits wide (harness packing), wrapping at 64
  identically in both legs.
- `INVALID_STACK_OPERATION` at 1209-1210 is unreachable on this domain (the
  front matter guarantees depth >= i); both legs still compute it.
