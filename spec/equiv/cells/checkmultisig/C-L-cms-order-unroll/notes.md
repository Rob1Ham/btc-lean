# Notes — `checkmultisig/C-L-cms-order-unroll`

- **repo_head:** `805c8042f92d3bed909ca40219a4d21fc9150cc1`
- **Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **contract:** v3 `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- **row:** SCR-116, `scr_row_coverage: partial` (nKeys <= 4 unroll)
- **patches:** none
- **status:** Alive2 green (1/1, bidirectional, checker uninterpreted);
  SAW green (10/10 proofs, 5 cases).

## Reproduce

From the repository root:

```bash
bash spec/equiv/cells/checkmultisig/C-L-cms-order-unroll/alive2/run.sh
bash spec/equiv/cells/checkmultisig/C-L-cms-order-unroll/saw/run.sh
sha256sum -c spec/equiv/cells/checkmultisig/C-L-cms-order-unroll/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/checkmultisig/C-L-cms-order-unroll/saw/certificate.sha256
```

## Toolchain

| Tool | Version |
|---|---|
| clang/clang++ | Ubuntu clang 20.1.2 (0ubuntu1~24.04.3) |
| LLVM | Ubuntu LLVM 20.1.2 |
| alive-tv | Alive2 v20.0 (Ubuntu LLVM 20.1.2) |
| SAW | 1.6 (`68eed5f release-1.6`) |

## Design

- `cell_cms_order(nkeys, nsigs)` unrolls four bodies of Core's loop
  (1163-1189) / Lean `cmsLoop` (Defs.lean:672-700), with the initial cursors
  `isig = nKeys+3`, `ikey = 2`.
- The observable is the *trace*: keys examined, matched-key mask, the
  "more signatures than keys remain" early exit, and fSuccess.  A leg that
  checks the right pairs in the wrong order, or keeps going after the early
  exit, cannot agree with the oracle even when fSuccess happens to coincide.
- Element convention: signature k (bottom-up) is `(len 1, 0x40+k)`, key j
  (top-down) is `(len 1, 0x40+j)`.  Out-of-domain inputs (nKeys > 4,
  nSigs > nKeys) return 0xFFFF in both legs.
- SAW cases: 0 checker always false, 1 always true, 2 diagonal, 3 shifted +1,
  4 shifted +2; `saw/model.cry` takes the match relation as a parameter and
  provides the five instances.  Alive2 quantifies over the checker instead
  (bare declaration in both legs; `noundef` added by the harness).
- A native driver cross-checked C, L and the model on all in-domain pairs
  x 5 stub instances with 0 mismatches before the tool runs.

## Why partial

`MAX_PUBKEYS_PER_MULTISIG = 20`; the loop can run up to 20 bodies and this
cell unrolls 4.  A complete row needs the remaining 16 unrolled bodies or a
SAW loop spec with an invariant.  The guard rejects nKeys > 4, so no
out-of-unroll body is silently skipped.

## Result detail

Alive2: `Transformation seems to be correct!`, 1 correct transformation,
0 errors.  SAW: 5 cases x 2 legs = 10 `Proof succeeded!` lines, `STATUS=saw-green
(10 proofs, 5 cases)`.

## Limits

- nKeys <= 4, nSigs <= nKeys.
- Encoding gates (SCR-117) are off; FindAndDelete (SCR-115) is a separate
  cell.
- The checker is abstract (same-crypto premise); the cell does not prove
  ECDSA/secp256k1 agreement.
