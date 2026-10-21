# Admissible mutant run M-E4-007-e4-cell

- **time:** 20261020T221110Z
- **mutation:** `M-E4-007` / `e4-cell`
- **expected cell:** `cells/tapscript/C-L-tapscript-isopsuccess`
- **target:** `spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/l_leg.cpp`
- **operator:** wave64/48-mutations-e3e4 (subagent)
- **git head:** `5946c024546e39f55775bfd9a077b042e3feeef4`
- **classification:** **KILLED**

## B-gate (before)

- target sha256: `387da37e4cd894e468007de249941906be9d91534d1d581ac8f9213a9c303840`
- cell spec sha256: `054d1a42aa584cb64397ec8d2c8dd71467a2ea2e4eb4a5f1c4b1f8ea3ae272f6`
- alive2: `alive2-green` (exit 0)
- saw: `saw-green (2/2 proofs)` (exit 0)

## Declared witness (before execution)

cell_is_op_success: opcode w=80 (0x50, OP_SUCCESS80). Baseline: both legs classify 80 as an OP_SUCCESS byte and return 1. Mutant drops the w==80 and w==98 arms, so w=80 returns 0 (the byte would be treated as a non-success/BAD_OPCODE). Expected: cell_is_op_success non-green on both tools.

## Exact commands

```sh
bash spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/alive2/run.sh   # baseline/mutant/post
bash spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/saw/run.sh
python3 spec/equiv/cells/_redteam/mutate.py --target spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/l_leg.cpp --mutation M-E4-007 --target-kind e4-cell
python3 spec/equiv/cells/_redteam/mutate.py --revert spec/equiv/cells/_redteam/mutants/M-E4-007-e4-cell-20261020T221114Z-387da37e.json
```

## Mutation diff

```diff
DRY RUN — no write, no record
mutation:    M-E4-007 (e4-taproot)
target:      /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/l_leg.cpp
target kind: e4-cell
sha256 before: 387da37e4cd894e468007de249941906be9d91534d1d581ac8f9213a9c303840
sha256 after:  48bcbc2d010f8be3c36ddf80111896bea0fd4b5e69c3da481df3634f08208b01
expected failing cells: cells/tapscript/C-L-tapscript-isopsuccess
catchers: alive2, saw

--- a/spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/l_leg.cpp
+++ b/spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/l_leg.cpp
@@ -13,7 +13,7 @@
 //
 // The Nat domain is total, matching the C leg's total 64-bit input.
 TAP_INLINE uint64_t l_is_op_success(uint64_t w) {
-  const bool r = w == 80u || w == 98u || (126u <= w && w <= 129u) ||
+  const bool r = (126u <= w && w <= 129u) ||  // M-E4-007 mutant: drop OP_SUCCESS 80/98
                  (131u <= w && w <= 134u) || (137u <= w && w <= 138u) ||
                  (141u <= w && w <= 142u) || (149u <= w && w <= 153u) ||
                  (187u <= w && w <= 254u);
```

## Mutant result

- target sha256 mutant: `48bcbc2d010f8be3c36ddf80111896bea0fd4b5e69c3da481df3634f08208b01`
- alive2: `alive2-not-green` (exit 1)
- saw: `saw-not-green (1/2 proofs)` (exit 1)

### Concrete witness

```
alive2:
=====
Source value: #x0000000000000001 (1)
Target value: #x0000000000000000 (0)
saw:
w: 98
```

### Raw logs

- `spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/mutant-alive2-result.txt`
- `spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/mutant-alive2.log`
- `spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/mutant-saw-result.txt`
- `spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/mutant-saw.log`

## Revert and post-revert baseline

- reverted: `True`
- target sha256 after revert: `387da37e4cd894e468007de249941906be9d91534d1d581ac8f9213a9c303840`
- alive2: `alive2-green` (exit 0)
- saw: `saw-green (2/2 proofs)` (exit 0)
- cell spec sha256 after: `054d1a42aa584cb64397ec8d2c8dd71467a2ea2e4eb4a5f1c4b1f8ea3ae272f6`

```text
REVERTED M-E4-007 (e4-cell)
target:      /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/l_leg.cpp
sha256 now:  387da37e4cd894e468007de249941906be9d91534d1d581ac8f9213a9c303840
receipt:     /tmp/opencode/wave64/48-mutations-e3e4/spec/equiv/cells/_redteam/mutants/M-E4-007-e4-cell-20261020T221114Z-387da37e.json.revert.json
Next: rebuild and confirm the baseline cell is green again.
```

## Log hashes

```text
d836ecf4e98469a6ca35adafbdb2c98995be0043be9848d01f11dabee0eef65a  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/apply.log
1a74b2ee5771dfc4ac7b9a8a9470fdc2b1b21db4720f2b3519763c9fa55e8d42  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/baseline-after-alive2-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/baseline-after-alive2.log
24cb85de649e0c414a22f8f6c2aea45409251637fcc1b04b1d0e134d786f0cc1  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/baseline-after-saw-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/baseline-after-saw.log
1a74b2ee5771dfc4ac7b9a8a9470fdc2b1b21db4720f2b3519763c9fa55e8d42  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/baseline-before-alive2-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/baseline-before-alive2.log
24cb85de649e0c414a22f8f6c2aea45409251637fcc1b04b1d0e134d786f0cc1  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/baseline-before-saw-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/baseline-before-saw.log
9834f9c2f021417f952af2e7b9c2134413cbfcf37382cfdf42db3e350c64f8b2  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/dry-run.log
dfe3ec988a256a4ae2b894bcb0c1d8c6a71a4eb59aa61e2c533ad7f80b72cce4  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/mutant-alive2-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/mutant-alive2.log
7b5cb4d7853f9af033e9a76203cd63a848aa90005bf4b1345da17ad6173c895f  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/mutant-saw-result.txt
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/mutant-saw.log
46f3838fec4fad245b9f12c132c116953fdd4473e355abb14e53d7c2be476469  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/plan.md
071fdc181d1c6680aae9236c6eb44043660d8c32b75a96a73dc210f22b18d2af  spec/equiv/cells/_redteam/runs/M-E4-007-e4-cell-20261020T221110Z/revert.log
```

## Scope

This is an L-leg (transliteration) proof-sensitivity kill on the named
bounded cell. It is not a model-site or core-copy kill, does not promote
any SCR row, and does not turn the partial cell into a row-green claim.

