# Pre-execution mutant plan M-E4-003-e4-cell

- time: 20261020T221027Z
- mutation: `M-E4-003` / `e4-cell`
- target: `spec/equiv/cells/tapscript/C-L-taproot-scriptpath-dispatch/l_leg.cpp`
- target sha256 before: `27f8ab24ac699e1b85d315d7c2bf892ba436de1601838979c64243f901d97bd2`
- expected cell: `cells/tapscript/C-L-taproot-scriptpath-dispatch`
- cell spec sha256 before: `cbc1f5035dfbb08c0bb8750eef6c575e946382c1ffeceab267f866de2a7d43cd`
- baseline before: alive2=`alive2-green`, saw=`saw-green (6/6 proofs)`

## Declared witness (written before mutation)

cell_leaf_version: control0=0xc1, discourage_taproot=0. Baseline: 0xc1 & 0xfe = 0xc0 = TAPROOT_LEAF_TAPSCRIPT, so both legs return result 2 (tapscript arm). Mutant (wrong leaf mask: 0xff instead of 0xfe): leaf=0xc1 != 0xc0, discourage=0, so the L leg returns result 1 (OK). Expected: cell_leaf_version non-green on both tools; cell_control_size and cell_tail stay green.

## Declared mutation diff (mutate.py --dry-run)

```diff
DRY RUN — no write, no record
mutation:    M-E4-003 (e4-taproot)
target:      /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/tapscript/C-L-taproot-scriptpath-dispatch/l_leg.cpp
target kind: e4-cell
sha256 before: 27f8ab24ac699e1b85d315d7c2bf892ba436de1601838979c64243f901d97bd2
sha256 after:  58e11a9f9b3d916c85ec760cf5b2d6d34c272da615e657928452da288578df99
expected failing cells: cells/tapscript/C-L-taproot-scriptpath-dispatch
catchers: alive2, saw

--- a/spec/equiv/cells/tapscript/C-L-taproot-scriptpath-dispatch/l_leg.cpp
+++ b/spec/equiv/cells/tapscript/C-L-taproot-scriptpath-dispatch/l_leg.cpp
@@ -47,7 +47,7 @@
 // LeafVersion.lean:36-40, 62-70 (the masked test)
 TAP_INLINE uint64_t l_leaf_version(uint64_t control0,
                                    uint64_t discourage_taproot) {
-  const uint64_t leaf = (control0 & 0xffu) & TAP_LEAF_MASK;  // leafVersionOf
+  const uint64_t leaf = (control0 & 0xffu) & 0xffu;  // M-E4-003 mutant: wrong leaf mask
   if (leaf == TAP_LEAF_TAPSCRIPT) return tap_pack(TAP_TAPSCRIPT, 0u);
   if (discourage_taproot != 0u) {
     return tap_pack(TAP_FAIL, TAP_ERR_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION);
```

