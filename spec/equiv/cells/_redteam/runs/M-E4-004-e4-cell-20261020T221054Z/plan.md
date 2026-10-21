# Pre-execution mutant plan M-E4-004-e4-cell

- time: 20261020T221054Z
- mutation: `M-E4-004` / `e4-cell`
- target: `spec/equiv/cells/_tools/e4/l_cell.cpp`
- target sha256 before: `5d97ae96c2447459c0a66c6d156289ff57033c8f3013acb7cd81c28d6d723a2b`
- expected cell: `cells/e4-witness/C-L-witness-v0-dispatch`
- cell spec sha256 before: `d1595ab67ea1e18ea4beb01504b5dff9c223761dc047b09fcd91771e03169975`
- baseline before: alive2=`alive2-green`, saw=`saw-green`

## Declared witness (written before mutation)

cell_v0_dispatch: program_len=20, witness_n=3. Baseline: the P2WPKH arm requires exactly 2 witness elements, so it returns (result 0, error 40 = WITNESS_PROGRAM_MISMATCH), packed 160. Mutant (witness_n != 2 -> witness_n < 2): 3 is accepted and the cell returns success (1,0), packed 1. Expected: cell_v0_dispatch non-green on both tools.

## Declared mutation diff (mutate.py --dry-run)

```diff
DRY RUN — no write, no record
mutation:    M-E4-004 (e4-witness)
target:      /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/_tools/e4/l_cell.cpp
target kind: e4-cell
sha256 before: 5d97ae96c2447459c0a66c6d156289ff57033c8f3013acb7cd81c28d6d723a2b
sha256 after:  3db906555567f62a90bbe6ee17c4d4c16f9ea715ef85a07249eefcc63488f672
expected failing cells: cells/e4-witness/C-L-witness-v0-dispatch
catchers: alive2, saw

--- a/spec/equiv/cells/_tools/e4/l_cell.cpp
+++ b/spec/equiv/cells/_tools/e4/l_cell.cpp
@@ -33,7 +33,7 @@
         // hashSha256 script == program and executeWitnessScript abstracted .ok
         return {L_OK, 0};
     } else if (program_len == 20) {
-        if (witness_n != 2) return {L_FAIL, 40};
+        if (witness_n < 2) return {L_FAIL, 40}; // M-E4-004 mutant
         // implied P2WPKH script executeWitnessScript abstracted .ok
         return {L_OK, 0};
     }
```

