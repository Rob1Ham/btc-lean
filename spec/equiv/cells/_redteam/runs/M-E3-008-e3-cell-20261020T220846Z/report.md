# Admissible mutant run M-E3-008-e3-cell

- **time:** 20261020T220846Z
- **mutation:** `M-E3-008` / `e3-cell`
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

cell_cmsverify: closed 1-of-1 CHECKMULTISIGVERIFY (wire 0xaf) with the shared checker returning false. Baseline: the verify arm returns EQUIV_ERR_CHECKMULTISIGVERIFY=13 with result 0. Mutant: returns EVAL_FALSE=2, so the verdict stays fail but the error kind changes. Expected: cell_cmsverify non-green on at least one tool; cell_cms, cell_cms_nulldummy, cell_cms_empty stay green.

## Exact commands

```sh
bash spec/equiv/cells/e3-cms/C-L-cms-1of1/alive2/run.sh   # baseline/mutant/post
bash spec/equiv/cells/e3-cms/C-L-cms-1of1/saw/run.sh
python3 spec/equiv/cells/_redteam/mutate.py --target spec/equiv/cells/_tools/e3/cellsig/l_cms.cpp --mutation M-E3-008 --target-kind e3-cell
python3 spec/equiv/cells/_redteam/mutate.py --revert spec/equiv/cells/_redteam/mutants/M-E3-008-e3-cell-20261020T220904Z-f775117e.json
```

## Mutation diff

```diff
DRY RUN — no write, no record
mutation:    M-E3-008 (e3-cms)
target:      /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/_tools/e3/cellsig/l_cms.cpp
target kind: e3-cell
sha256 before: f775117e523eed92cb5ffb91c598e468505667c2c272b24624eacbd7ab89fb41
sha256 after:  7aefca80f280dcaf92c15af22fd375365e3ba2fe8cb96bd25e7b4af6d7be1434
expected failing cells: cells/e3-cms/C-L-cms-1of1
catchers: alive2, saw, error-enum

--- a/spec/equiv/cells/_tools/e3/cellsig/l_cms.cpp
+++ b/spec/equiv/cells/_tools/e3/cellsig/l_cms.cpp
@@ -66,7 +66,7 @@
   if (pe != TWIN_OK) return pe;
   if (wire == 0xaf) {
     if (fSuccess) { st.stack.n -= 1; return TWIN_OK; }
-    return TWIN_CHECKMULTISIGVERIFY;
+    return (TwinErr)2; // M-E3-008 mutant: CHECKMULTISIGVERIFY -> EVAL_FALSE
   }
   return TWIN_OK;
 }
```

## Mutant result

- target sha256 mutant: `7aefca80f280dcaf92c15af22fd375365e3ba2fe8cb96bd25e7b4af6d7be1434`
- alive2: `alive2-not-green` (exit 1)
- saw: `saw-not-green (11/16 proofs)` (exit 1)

### Concrete witness

```
alive2:
=====
Source value: #x0000000000000034 (52)
Target value: #x0000000000000018 (24)
saw:
<<All settings of the symbolic variables constitute a counterexample>>
```

### Raw logs

- `spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/mutant-alive2-result.txt`
- `spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/mutant-alive2.log`
- `spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/mutant-saw-result.txt`
- `spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/mutant-saw.log`

## Revert and post-revert baseline

- reverted: `True`
- target sha256 after revert: `f775117e523eed92cb5ffb91c598e468505667c2c272b24624eacbd7ab89fb41`
- alive2: `alive2-green` (exit 0)
- saw: `saw-green (16/16 proofs)` (exit 0)
- cell spec sha256 after: `bce767c76e7474ec3993742424ca471be0e5b9ca387f01f49bc90d476ebef8ba`

```text
REVERTED M-E3-008 (e3-cell)
target:      /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/_tools/e3/cellsig/l_cms.cpp
sha256 now:  f775117e523eed92cb5ffb91c598e468505667c2c272b24624eacbd7ab89fb41
receipt:     /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/_redteam/mutants/M-E3-008-e3-cell-20261020T220904Z-f775117e.json.revert.json
Next: rebuild and confirm the baseline cell is green again.
```

## Log hashes

```text
2b8a31f718a5c29c0275a30cb324616c515f086c7d54da299b7d483b4debe5ff  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/apply.log
031a9f8b2694376a8606e2cfa63953371dcbd76a200db31572e581a67a8df7be  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/baseline-after-alive2-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/baseline-after-alive2.log
44820114496acc7e615265564de7106bc350e8168adb2a3035221bb7292e7689  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/baseline-after-saw-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/baseline-after-saw.log
031a9f8b2694376a8606e2cfa63953371dcbd76a200db31572e581a67a8df7be  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/baseline-before-alive2-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/baseline-before-alive2.log
44820114496acc7e615265564de7106bc350e8168adb2a3035221bb7292e7689  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/baseline-before-saw-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/baseline-before-saw.log
049b26066032348f94b2a1134771cc14dcefd0cec84c05d52c735b3e19a79c0d  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/dry-run.log
c9505936ac7b0d3f579fa1c1db9a1662b5f50fd8c191dd99686a9cc3dbdfefb0  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/mutant-alive2-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/mutant-alive2.log
7a9000177835573a20728bf58a464cc5c9c36cb7a108285cd55e124855b1d748  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/mutant-saw-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/mutant-saw.log
48ef5d0c4946b631de03e90bc8a4fad992e57b7adc2212f6b38a329bae7a3769  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/plan.md
8b5da17709022c1d0be639db7a1f75fc2d98920039e110b38ebc4d6d84f230e7  spec/equiv/cells/_redteam/runs/M-E3-008-e3-cell-20261020T220846Z/revert.log
```

## Scope

This is an L-leg (transliteration) proof-sensitivity kill on the named
bounded cell. It is not a model-site or core-copy kill, does not promote
any SCR row, and does not turn the partial cell into a row-green claim.

