# Admissible mutant run M-E4-003-e4-cell

- **time:** 20261020T221027Z
- **mutation:** `M-E4-003` / `e4-cell`
- **expected cell:** `cells/tapscript/C-L-taproot-scriptpath-dispatch`
- **target:** `spec/equiv/cells/tapscript/C-L-taproot-scriptpath-dispatch/l_leg.cpp`
- **operator:** wave64/48-mutations-e3e4 (subagent)
- **git head:** `5946c024546e39f55775bfd9a077b042e3feeef4`
- **classification:** **KILLED**

## B-gate (before)

- target sha256: `27f8ab24ac699e1b85d315d7c2bf892ba436de1601838979c64243f901d97bd2`
- cell spec sha256: `cbc1f5035dfbb08c0bb8750eef6c575e946382c1ffeceab267f866de2a7d43cd`
- alive2: `alive2-green` (exit 0)
- saw: `saw-green (6/6 proofs)` (exit 0)

## Declared witness (before execution)

cell_leaf_version: control0=0xc1, discourage_taproot=0. Baseline: 0xc1 & 0xfe = 0xc0 = TAPROOT_LEAF_TAPSCRIPT, so both legs return result 2 (tapscript arm). Mutant (wrong leaf mask: 0xff instead of 0xfe): leaf=0xc1 != 0xc0, discourage=0, so the L leg returns result 1 (OK). Expected: cell_leaf_version non-green on both tools; cell_control_size and cell_tail stay green.

## Exact commands

```sh
bash spec/equiv/cells/tapscript/C-L-taproot-scriptpath-dispatch/alive2/run.sh   # baseline/mutant/post
bash spec/equiv/cells/tapscript/C-L-taproot-scriptpath-dispatch/saw/run.sh
python3 spec/equiv/cells/_redteam/mutate.py --target spec/equiv/cells/tapscript/C-L-taproot-scriptpath-dispatch/l_leg.cpp --mutation M-E4-003 --target-kind e4-cell
python3 spec/equiv/cells/_redteam/mutate.py --revert spec/equiv/cells/_redteam/mutants/M-E4-003-e4-cell-20261020T221035Z-27f8ab24.json
```

## Mutation diff

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

## Mutant result

- target sha256 mutant: `58e11a9f9b3d916c85ec760cf5b2d6d34c272da615e657928452da288578df99`
- alive2: `alive2-not-green` (exit 1)
- saw: `saw-not-green (3/6 proofs)` (exit 1)

### Concrete witness

```
alive2:
=====
Source value: #x0000000000000002 (2)
Target value: #x0000000000000001 (1)
saw:
c: 18446744073709551553
  d: 0
```

### Raw logs

- `spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/mutant-alive2-result.txt`
- `spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/mutant-alive2.log`
- `spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/mutant-saw-result.txt`
- `spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/mutant-saw.log`

## Revert and post-revert baseline

- reverted: `True`
- target sha256 after revert: `27f8ab24ac699e1b85d315d7c2bf892ba436de1601838979c64243f901d97bd2`
- alive2: `alive2-green` (exit 0)
- saw: `saw-green (6/6 proofs)` (exit 0)
- cell spec sha256 after: `cbc1f5035dfbb08c0bb8750eef6c575e946382c1ffeceab267f866de2a7d43cd`

```text
REVERTED M-E4-003 (e4-cell)
target:      /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/tapscript/C-L-taproot-scriptpath-dispatch/l_leg.cpp
sha256 now:  27f8ab24ac699e1b85d315d7c2bf892ba436de1601838979c64243f901d97bd2
receipt:     /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/_redteam/mutants/M-E4-003-e4-cell-20261020T221035Z-27f8ab24.json.revert.json
Next: rebuild and confirm the baseline cell is green again.
```

## Log hashes

```text
bdd635a8e96b2dfc9fcb77e3e885d5254ad1c29edc0b56fca6c64ba46de1b101  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/apply.log
9e613651a4cfb2623886b17a28c01f74fb27db9e50ddb16e9207c2b1212f7f19  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/baseline-after-alive2-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/baseline-after-alive2.log
4df7fcab4099baa5592463bd422ec515a199305cf9e7ddd0eed428c41da9c389  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/baseline-after-saw-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/baseline-after-saw.log
9e613651a4cfb2623886b17a28c01f74fb27db9e50ddb16e9207c2b1212f7f19  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/baseline-before-alive2-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/baseline-before-alive2.log
4df7fcab4099baa5592463bd422ec515a199305cf9e7ddd0eed428c41da9c389  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/baseline-before-saw-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/baseline-before-saw.log
9a4686ce91f11f814d8ce5cdfcb2a9823e90f91cd0835934dca9006d7bc7bd14  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/dry-run.log
3c5cf6f34ef3530b2013c5594644118f9236b86ba71016ffcb7d799c75a1dc3d  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/mutant-alive2-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/mutant-alive2.log
cd1b9402f43a87dff74e38307d4322d554c746349e33cbf1f5a844a428185da6  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/mutant-saw-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/mutant-saw.log
da73b2c9f998ed3368757b651e8c297a86db0b955152a7e116c2b7d372ca4ed2  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/plan.md
66b40df880bd6c9331d0d3addd2555f87907b31d78b20834d558ba10800bf17e  spec/equiv/cells/_redteam/runs/M-E4-003-e4-cell-20261020T221027Z/revert.log
```

## Scope

This is an L-leg (transliteration) proof-sensitivity kill on the named
bounded cell. It is not a model-site or core-copy kill, does not promote
any SCR row, and does not turn the partial cell into a row-green claim.

