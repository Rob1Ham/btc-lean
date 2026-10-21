# Pre-execution mutant plan M-E3-008-e3-cell

- time: 20261020T220846Z
- mutation: `M-E3-008` / `e3-cell`
- target: `spec/equiv/cells/_tools/e3/cellsig/l_cms.cpp`
- target sha256 before: `f775117e523eed92cb5ffb91c598e468505667c2c272b24624eacbd7ab89fb41`
- expected cell: `cells/e3-cms/C-L-cms-1of1`
- cell spec sha256 before: `bce767c76e7474ec3993742424ca471be0e5b9ca387f01f49bc90d476ebef8ba`
- baseline before: alive2=`alive2-green`, saw=`saw-green (16/16 proofs)`

## Declared witness (written before mutation)

cell_cmsverify: closed 1-of-1 CHECKMULTISIGVERIFY (wire 0xaf) with the shared checker returning false. Baseline: the verify arm returns EQUIV_ERR_CHECKMULTISIGVERIFY=13 with result 0. Mutant: returns EVAL_FALSE=2, so the verdict stays fail but the error kind changes. Expected: cell_cmsverify non-green on at least one tool; cell_cms, cell_cms_nulldummy, cell_cms_empty stay green.

## Declared mutation diff (mutate.py --dry-run)

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

