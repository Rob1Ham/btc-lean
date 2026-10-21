# Admissible mutant run M-E4-004-e4-cell

- **time:** 20261020T221054Z
- **mutation:** `M-E4-004` / `e4-cell`
- **expected cell:** `cells/e4-witness/C-L-witness-v0-dispatch`
- **target:** `spec/equiv/cells/_tools/e4/l_cell.cpp`
- **operator:** wave64/48-mutations-e3e4 (subagent)
- **git head:** `5946c024546e39f55775bfd9a077b042e3feeef4`
- **classification:** **KILLED**

## B-gate (before)

- target sha256: `5d97ae96c2447459c0a66c6d156289ff57033c8f3013acb7cd81c28d6d723a2b`
- cell spec sha256: `d1595ab67ea1e18ea4beb01504b5dff9c223761dc047b09fcd91771e03169975`
- alive2: `alive2-green` (exit 0)
- saw: `saw-green` (exit 0)

## Declared witness (before execution)

cell_v0_dispatch: program_len=20, witness_n=3. Baseline: the P2WPKH arm requires exactly 2 witness elements, so it returns (result 0, error 40 = WITNESS_PROGRAM_MISMATCH), packed 160. Mutant (witness_n != 2 -> witness_n < 2): 3 is accepted and the cell returns success (1,0), packed 1. Expected: cell_v0_dispatch non-green on both tools.

## Exact commands

```sh
bash spec/equiv/cells/e4-witness/C-L-witness-v0-dispatch/alive2/run.sh   # baseline/mutant/post
bash spec/equiv/cells/e4-witness/C-L-witness-v0-dispatch/saw/run.sh
python3 spec/equiv/cells/_redteam/mutate.py --target spec/equiv/cells/_tools/e4/l_cell.cpp --mutation M-E4-004 --target-kind e4-cell
python3 spec/equiv/cells/_redteam/mutate.py --revert spec/equiv/cells/_redteam/mutants/M-E4-004-e4-cell-20261020T221058Z-5d97ae96.json
```

## Mutation diff

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

## Mutant result

- target sha256 mutant: `3db906555567f62a90bbe6ee17c4d4c16f9ea715ef85a07249eefcc63488f672`
- alive2: `alive2-not-green` (exit 1)
- saw: `saw-not-green` (exit 1)

### Concrete witness

```
alive2:
Source value: #x00000000000000a0 (160)
Target value: #x0000000000000001 (1)
saw:
plen: 20
  wn: 3
```

### Raw logs

- `spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/mutant-alive2-result.txt`
- `spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/mutant-alive2.log`
- `spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/mutant-saw-result.txt`
- `spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/mutant-saw.log`

## Revert and post-revert baseline

- reverted: `True`
- target sha256 after revert: `5d97ae96c2447459c0a66c6d156289ff57033c8f3013acb7cd81c28d6d723a2b`
- alive2: `alive2-green` (exit 0)
- saw: `saw-green` (exit 0)
- cell spec sha256 after: `d1595ab67ea1e18ea4beb01504b5dff9c223761dc047b09fcd91771e03169975`

```text
REVERTED M-E4-004 (e4-cell)
target:      /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/_tools/e4/l_cell.cpp
sha256 now:  5d97ae96c2447459c0a66c6d156289ff57033c8f3013acb7cd81c28d6d723a2b
receipt:     /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/_redteam/mutants/M-E4-004-e4-cell-20261020T221058Z-5d97ae96.json.revert.json
Next: rebuild and confirm the baseline cell is green again.
```

## Log hashes

```text
2136295624496030869d901318214bd931867ad34a1a4b7647a24b987e1864a6  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/apply.log
5ffcadb416067ce69736781dd7fc5414855af410ef5696a31db7d90125751ddf  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/baseline-after-alive2-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/baseline-after-alive2.log
701a7663b3508f468075b863ec3e25d1861ec97e4ddff95230af650045e2fb4e  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/baseline-after-saw-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/baseline-after-saw.log
5ffcadb416067ce69736781dd7fc5414855af410ef5696a31db7d90125751ddf  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/baseline-before-alive2-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/baseline-before-alive2.log
701a7663b3508f468075b863ec3e25d1861ec97e4ddff95230af650045e2fb4e  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/baseline-before-saw-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/baseline-before-saw.log
9baf8d44698daedb6d84c0c143d9cf22d1e67896092372eeb39fc8f8ecb73677  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/dry-run.log
d1ca307b4b86d7a2df3950b74938542e59a265a6b8c54f7857b812254585979e  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/mutant-alive2-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/mutant-alive2.log
fd198d3fe3b2d19bf1dbf10401ae0118a9f688cebb1851c0f90b7365fa233e97  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/mutant-saw-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/mutant-saw.log
6a15c52598c20fc5177eecaf28eb3336bb40682543bfd6ad48fc1cac984b2336  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/plan.md
704947cbf750196439de8fe3ce851089c607fa3c34f8292ac836bfe9df3aeb73  spec/equiv/cells/_redteam/runs/M-E4-004-e4-cell-20261020T221054Z/revert.log
```

## Scope

This is an L-leg (transliteration) proof-sensitivity kill on the named
bounded cell. It is not a model-site or core-copy kill, does not promote
any SCR row, and does not turn the partial cell into a row-green claim.

