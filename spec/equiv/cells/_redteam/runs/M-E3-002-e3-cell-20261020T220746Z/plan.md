# Pre-execution mutant plan M-E3-002-e3-cell

- time: 20261020T220746Z
- mutation: `M-E3-002` / `e3-cell`
- target: `spec/equiv/cells/_tools/e3/cellsig/l_cms.cpp`
- target sha256 before: `f775117e523eed92cb5ffb91c598e468505667c2c272b24624eacbd7ab89fb41`
- expected cell: `cells/e3-cms/C-L-cms-1of1`
- cell spec sha256 before: `bce767c76e7474ec3993742424ca471be0e5b9ca387f01f49bc90d476ebef8ba`
- baseline before: alive2=`alive2-green`, saw=`saw-green (16/16 proofs)`

## Declared witness (written before mutation)

cell_cms_nulldummy: closed 1-of-1 CHECKMULTISIG, null_dummy=true, dummy element <0x55> (non-empty). Baseline: NULLDUMMY gate returns EQUIV_ERR_SIG_NULLDUMMY=28 with result 0. Mutant (gate dropped): dummy is popped, checker-true verdict pushes vchTrue, cell returns result 1 / error 0. Expected: cell_cms_nulldummy non-green on both tools; cell_cms, cell_cmsverify, cell_cms_empty stay green.

## Declared mutation diff (mutate.py --dry-run)

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

