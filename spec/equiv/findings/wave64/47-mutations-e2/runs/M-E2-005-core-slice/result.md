# M-E2-005-core-slice — M-E2-005 (core-slice)

- Cell: `cells/limits/C-L-opcount` (catalogue cell `cells/e2-flow/opcount-201`)
- Target: `spec/equiv/cells/limits/C-L-opcount/src/c_leaf.cpp`
- HEAD: `5946c024546e39f55775bfd9a077b042e3feeef4`
- Execution root: byte-identical `git archive HEAD spec/equiv` copy under `.work/spec/equiv` (target hash verified against HEAD before mutation).
- Classification: **KILLED**
- Caught: `True` by `alive2, saw`

## Mutation

```diff
--- a/spec/equiv/cells/limits/C-L-opcount/src/c_leaf.cpp
+++ b/spec/equiv/cells/limits/C-L-opcount/src/c_leaf.cpp
@@ -45,7 +45,7 @@
   if (sv == LIM_SV_BASE || sv == LIM_SV_WITNESS_V0) {
     if (wire > 0x60) {
       ++nOpCount;
-      if (nOpCount > LIM_MAX_OPS_PER_SCRIPT) {
+      if (nOpCount >= LIM_MAX_OPS_PER_SCRIPT) {  // M-E2-005 mutant: threshold 200
         return lim_pack(0, EQUIV_ERR_OP_COUNT, 0);
       }
     }
```

- sha256 before: `8222580d12a65dcda9f306dcfdcd257f6bc5a5bc99e579d7d31f21ca81c77955`
- sha256 after: `90d70d4196510028d46c2924bc9f85b7bd8b16cf727703df02c0f80d366aab2b`

## Command

```sh
cd spec/equiv && bash cells/limits/C-L-opcount/alive2/run.sh
cd spec/equiv && bash cells/limits/C-L-opcount/saw/run.sh
```

## Expected detection

Alive2 C-vs-L must report a value mismatch at a charged count of 201; SAW must fail the C proof against the independent 201 budget. Witness: incoming opCount=200, wire=0x8e, sv=BASE, fExec=0; baseline DISABLED_OPCODE (budget admits 201), mutant OP_COUNT.

Witness input: `opCount=200, wire=0x8e, fExec=0, sv=BASE`

## Actual output

| leg | baseline | mutant | post-revert |
|---|---|---|---|
| alive2 | alive2-green | alive2-not-green | alive2-green |
| saw | saw-green | saw-not-green | saw-green |

Alive2 per-function result:

| function | correct | mismatch |
|---|---|---|
| `cell_opcount` | False | True |

Alive2 failure excerpt:

```text
  ret i64 %#range_0_%retval.1
}
Transformation doesn't verify!

ERROR: Value mismatch

Example:
i32 noundef %opCount = #x000000c8 (200)
i8 noundef zeroext %wire = #x8e (142, -114)
i8 noundef zeroext %fExec = #x00 (0)
i8 noundef zeroext %sv = #x00 (0)

Source:
i1 %spec.select.i = #x0 (0)
i32 %conv = #x00000000 (0)
i1 %cmp = #x0 (0)
i1 %or.cond = #x0 (0)
i1 %cmp2 = #x0 (0)
i1 %or.cond25 = #x0 (0)
  >> Jump to %if.end
```

SAW: 0 succeeded, 1 failed.

```text
         (ite _x`1 (bvslt 32 (bvNat 32 199) opc) (bvNat 64 28)
            (ite _x`1 _x`6 _x`7
               (ite _x`1 _x`8 _x`7
                  (ite _x`1 _x`9 _x`7
                     (ite _x`1 _x`10 _x`7
                        (ite _x`1 _x`11 _x`7
                           (ite _x`1 _x`12 _x`7
                              (ite _x`1 _x`13 _x`7
                                 (ite _x`1 _x`14 _x`7
                                    (ite _x`1 _x`15 _x`7
                                       (ite _x`1 _x`16 _x`7
                                          (ite _x`1 _x`17 _x`7
                                             (... ... _x`18 _x`7
                                                (... ... _x`7 (... ... (... ...)))))))))))))))))
      (bvNat 64 6)

Goal size 334. Provers used: abc_verilog
----------Counterexample----------
  opc: 200
  wire: 192
  fexec: 0
  sv: 0
----------------------------------
Stack trace:
   (builtin) in abc
   cell.saw:17:45-17:48 in (callback)
   (builtin) in llvm_verify
   cell.saw:17:1-17:48 (at top level)
Proof failed.
```

## Revert

- Revert hash matches before: `True`
- Post-revert baseline green: `True`

Raw logs and result files are in this directory. The working tree's cells were never edited; only the archive copy was.
