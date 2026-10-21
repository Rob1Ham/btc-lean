# M-E2-001-core-slice — M-E2-001 (core-slice)

- Cell: `cells/control-flow/C-L-casttobool` (catalogue cell `cells/e2-flow/negzero-if`)
- Target: `spec/equiv/cells/control-flow/C-L-casttobool/src/c_leaf.cpp`
- HEAD: `5946c024546e39f55775bfd9a077b042e3feeef4`
- Execution root: byte-identical `git archive HEAD spec/equiv` copy under `.work/spec/equiv` (target hash verified against HEAD before mutation).
- Classification: **KILLED**
- Caught: `True` by `alive2, saw`

## Mutation

```diff
--- a/spec/equiv/cells/control-flow/C-L-casttobool/src/c_leaf.cpp
+++ b/spec/equiv/cells/control-flow/C-L-casttobool/src/c_leaf.cpp
@@ -25,8 +25,7 @@
 BINLINE bool core_cast_to_bool(const uint8_t* vch, unsigned int n) {
   for (unsigned int i = 0; i < n; i++) {
     if (vch[i] != 0) {
-      if (i == n - 1 && vch[i] == 0x80)
-        return false;
+      // M-E2-001 mutant: negative zero is treated as true
       return true;
     }
   }
```

- sha256 before: `f8f2393b7e1efd4dff404840386cb19733f651a5f36ac35164db5f51c860021d`
- sha256 after: `044034a53806e64d35509de6eb08464eeaf38115054a094b4d42ea2555294060`

## Command

```sh
cd spec/equiv && bash cells/control-flow/C-L-casttobool/alive2/run.sh
cd spec/equiv && bash cells/control-flow/C-L-casttobool/saw/run.sh
```

## Expected detection

Alive2 C-vs-L must report a value mismatch for cell_cast_len1 at b0=0x80; SAW must fail the C cell_cast_len1 proof against the independent cast1 predicate (0x80 => false). Witness: element length 1, byte 0x80; baseline C returns 0, mutant returns 1.

Witness input: `len=1, b0=0x80`

## Actual output

| leg | baseline | mutant | post-revert |
|---|---|---|---|
| alive2 | alive2-green | alive2-not-green | alive2-green |
| saw | saw-green | saw-not-green | saw-green |

Alive2 per-function result:

| function | correct | mismatch |
|---|---|---|
| `cell_cast_empty` | True | False |
| `cell_cast_len1` | False | True |
| `cell_cast_len2` | True | False |

Alive2 failure excerpt:

```text
  ret i32 %#range_0_%cond
}
Transformation doesn't verify!

ERROR: Value mismatch

Example:
i8 noundef zeroext %b0 = #x80 (128, -128)

Source:
i1 %cmp1.not.i = #x0 (0)
  >> Jump to %for.cond.i
i1 %i.0.i = #x1 (1)
i1 %or.cond = #x0 (0)
  >> Jump to %_ZL17core_cast_to_boolPKhj.exit
i32 %cond = #x00000001 (1)
i32 %#range_0_%cond = #x00000001 (1)

Target:
i8 %#0 = #x00 (0)
```

SAW: 2 succeeded, 1 failed.

```text
Simulating cell_cast_empty...
Checking proof obligations cell_cast_empty...
Proof succeeded! cell_cast_empty
Verifying cell_cast_empty...
Simulating cell_cast_empty...
Checking proof obligations cell_cast_empty...
Proof succeeded! cell_cast_empty
Verifying cell_cast_len1...
Simulating cell_cast_len1...
Checking proof obligations cell_cast_len1...
Subgoal failed: cell_cast_len1 cell.saw:25:1: error: in _SAW_LLVM_withMethodSpec
Literal equality postcondition
Expected term: 
cast1 b0
Actual term:
bvUExt 31 1
  (ite (Vec 1 Bool) (bvEq 8 (bvNat 8 0) b0) (bvNat 1 0)
     (bvNat 1 1))

Goal size 59. Provers used: abc_verilog
----------Counterexample----------
  b0: 128
----------------------------------
Stack trace:
   (builtin) in abc
   cell.saw:25:46-25:49 in (callback)
   (builtin) in llvm_verify
   cell.saw:25:1-25:49 (at top level)
Proof failed.
```

## Revert

- Revert hash matches before: `True`
- Post-revert baseline green: `True`

Raw logs and result files are in this directory. The working tree's cells were never edited; only the archive copy was.
