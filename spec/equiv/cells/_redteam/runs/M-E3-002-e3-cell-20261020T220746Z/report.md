# Admissible mutant run M-E3-002-e3-cell

- **time:** 20261020T220746Z
- **mutation:** `M-E3-002` / `e3-cell`
- **expected cell:** `cells/e3-cms/C-L-cms-1of1`
- **target:** `spec/equiv/cells/_tools/e3/cellsig/l_cms.cpp`
- **operator:** wave64/48-mutations-e3e4 (subagent)
- **git head:** `5946c024546e39f55775bfd9a077b042e3feeef4`
- **classification:** **KILLED**

## B-gate (before)

- target sha256: `f775117e523eed92cb5ffb91c598e468505667c2c272b24624eacbd7ab89fb41`
- cell spec sha256: `bce767c76e7474ec3993742424ca471be0e5b9ca387f01f49bc90d476ebef8ba`
- alive2: `alive2-green` (exit 0)
- saw: `saw-green (16/16 proofs)` (exit 0)

## Declared witness (before execution)

cell_cms_nulldummy: closed 1-of-1 CHECKMULTISIG, null_dummy=true, dummy element <0x55> (non-empty). Baseline: NULLDUMMY gate returns EQUIV_ERR_SIG_NULLDUMMY=28 with result 0. Mutant (gate dropped): dummy is popped, checker-true verdict pushes vchTrue, cell returns result 1 / error 0. Expected: cell_cms_nulldummy non-green on both tools; cell_cms, cell_cmsverify, cell_cms_empty stay green.

## Exact commands

```sh
bash spec/equiv/cells/e3-cms/C-L-cms-1of1/alive2/run.sh   # baseline/mutant/post
bash spec/equiv/cells/e3-cms/C-L-cms-1of1/saw/run.sh
python3 spec/equiv/cells/_redteam/mutate.py --target spec/equiv/cells/_tools/e3/cellsig/l_cms.cpp --mutation M-E3-002 --target-kind e3-cell
python3 spec/equiv/cells/_redteam/mutate.py --revert spec/equiv/cells/_redteam/mutants/M-E3-002-e3-cell-20261020T220759Z-f775117e.json
```

## Mutation diff

```diff
DRY RUN — no write, no record
mutation:    M-E3-002 (e3-cms)
target:      /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/_tools/e3/cellsig/l_cms.cpp
target kind: e3-cell
sha256 before: f775117e523eed92cb5ffb91c598e468505667c2c272b24624eacbd7ab89fb41
sha256 after:  153279894bf80e4f7cd217357a6b46513cfe0bb7ec1b8dacd6c36e93ba46d716
expected failing cells: cells/e3-cms/C-L-cms-1of1
catchers: alive2, saw, error-enum

--- a/spec/equiv/cells/_tools/e3/cellsig/l_cms.cpp
+++ b/spec/equiv/cells/_tools/e3/cellsig/l_cms.cpp
@@ -58,7 +58,7 @@
   st.stack.n -= 4;
   if (st.stack.n < 1) return TWIN_INVALID_STACK_OPERATION;
   // SWT-064 / Defs.lean:1119-1121: NULLDUMMY gate.
-  if (null_dummy && st.stack.len[st.stack.n - 1] != 0) return TWIN_SIG_NULLDUMMY;
+  // M-E3-002 mutant: NULLDUMMY gate dropped
   st.stack.n -= 1;                                   // pop dummy
   uint8_t one = 1;
   const TwinErr pe = st_push(st.stack, fSuccess ? &one : nullptr,
```

## Mutant result

- target sha256 mutant: `153279894bf80e4f7cd217357a6b46513cfe0bb7ec1b8dacd6c36e93ba46d716`
- alive2: `alive2-not-green` (exit 1)
- saw: `saw-not-green (10/16 proofs)` (exit 1)

### Concrete witness

```
alive2:
=====
Source value: #x0000000000000070 (112)
Target value: #x0000000000000108 (264)
saw:
<<All settings of the symbolic variables constitute a counterexample>>
```

### Raw logs

- `spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/mutant-alive2-result.txt`
- `spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/mutant-alive2.log`
- `spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/mutant-saw-result.txt`
- `spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/mutant-saw.log`

## Revert and post-revert baseline

- reverted: `True`
- target sha256 after revert: `f775117e523eed92cb5ffb91c598e468505667c2c272b24624eacbd7ab89fb41`
- alive2: `alive2-green` (exit 0)
- saw: `saw-green (16/16 proofs)` (exit 0)
- cell spec sha256 after: `bce767c76e7474ec3993742424ca471be0e5b9ca387f01f49bc90d476ebef8ba`

```text
REVERTED M-E3-002 (e3-cell)
target:      /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/_tools/e3/cellsig/l_cms.cpp
sha256 now:  f775117e523eed92cb5ffb91c598e468505667c2c272b24624eacbd7ab89fb41
receipt:     /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/_redteam/mutants/M-E3-002-e3-cell-20261020T220759Z-f775117e.json.revert.json
Next: rebuild and confirm the baseline cell is green again.
```

## Log hashes

```text
aad9064577312f5c1efb8af1bd35677388166b1ef99b0a2a2115cdeb2691bca2  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/apply.log
031a9f8b2694376a8606e2cfa63953371dcbd76a200db31572e581a67a8df7be  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/baseline-after-alive2-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/baseline-after-alive2.log
44820114496acc7e615265564de7106bc350e8168adb2a3035221bb7292e7689  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/baseline-after-saw-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/baseline-after-saw.log
031a9f8b2694376a8606e2cfa63953371dcbd76a200db31572e581a67a8df7be  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/baseline-before-alive2-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/baseline-before-alive2.log
44820114496acc7e615265564de7106bc350e8168adb2a3035221bb7292e7689  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/baseline-before-saw-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/baseline-before-saw.log
0230595a068e585ffd06a321a70283d9a1baadcf1d7143f5bbaeda3de7c47537  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/dry-run.log
e38f0919dcfa300232fbfd809e5bc5fa4298f97c88c91aedc7d9e85dcb649289  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/mutant-alive2-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/mutant-alive2.log
370bb7b0c69101c2a6186daa26d1809ce13ffc784940371b3d224365dd82d84e  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/mutant-saw-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/mutant-saw.log
f4eba651a443b5b735eda113a5ab59a6a020cd5f693a7a98ab9c8f34bb2d0f02  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/plan.md
9300a2f78546f5832e79e608aec311e7585ec992e2058fa8316e483f23adc72e  spec/equiv/cells/_redteam/runs/M-E3-002-e3-cell-20261020T220746Z/revert.log
```

## Scope

This is an L-leg (transliteration) proof-sensitivity kill on the named
bounded cell. It is not a model-site or core-copy kill, does not promote
any SCR row, and does not turn the partial cell into a row-green claim.

