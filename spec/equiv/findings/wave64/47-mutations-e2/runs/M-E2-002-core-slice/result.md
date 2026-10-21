# M-E2-002-core-slice — M-E2-002 (core-slice)

- Cell: `cells/numeric/C-L-unary-4byte` (catalogue cell `cells/e2-numeric/num-4byte-boundary`)
- Target: `spec/equiv/cells/numeric/C-L-unary-4byte/src/c_leaf.cpp`
- HEAD: `5946c024546e39f55775bfd9a077b042e3feeef4`
- Execution root: byte-identical `git archive HEAD spec/equiv` copy under `.work/spec/equiv` (target hash verified against HEAD before mutation).
- Classification: **KILLED**
- Caught: `True` by `alive2, saw`

## Mutation

```diff
--- a/spec/equiv/cells/numeric/C-L-unary-4byte/src/c_leaf.cpp
+++ b/spec/equiv/cells/numeric/C-L-unary-4byte/src/c_leaf.cpp
@@ -35,7 +35,7 @@
   int64_t bn = 0;
   uint32_t err = 0;
   // CScriptNum bn(stacktop(-1), fRequireMinimal)  [script.h:246-271]
-  if (!decode_num(p, len, /*fRequireMinimal=*/false, 4, bn, err))
+  if (!decode_num(p, len, /*fRequireMinimal=*/false, 5, bn, err))  // M-E2-002 mutant: 5-byte operand accepted
     return num_obs_err(err);
   switch (opcode) {
     case 0x8b: bn += 1; break;                       // OP_1ADD: bn += bnOne
```

- sha256 before: `40062b8734175e26491fff60f3538934be9706f6c677a050eaa861445a2dcf04`
- sha256 after: `c63201531534a279097f9939ff1f158ad50d54afcfe35cf138cfd3edcc238437`

## Command

```sh
cd spec/equiv && bash cells/numeric/C-L-unary-4byte/alive2/run.sh
cd spec/equiv && bash cells/numeric/C-L-unary-4byte/saw/run.sh
```

## Expected detection

Alive2 C-vs-L must report a value mismatch at operand length 5 (C accepts, L returns SCRIPTNUM); SAW must fail the C proof against the independent decodeOk predicate (L <= 4). Witness: cell_1add, lb=5, content 0; baseline error 4 (SCRIPTNUM), mutant pushes 1.

Witness input: `len=5, w=0, OP_1ADD`

## Actual output

| leg | baseline | mutant | post-revert |
|---|---|---|---|
| alive2 | alive2-green | alive2-not-green | alive2-green |
| saw | saw-green | saw-not-green | saw-green |

Alive2 per-function result:

| function | correct | mismatch |
|---|---|---|
| `cell_1add` | False | True |
| `cell_1sub` | False | True |
| `cell_negate` | False | True |
| `cell_abs` | False | True |
| `cell_not` | False | True |
| `cell_0notequal` | False | True |

Alive2 failure excerpt:

```text
  ret i64 %#range_0_%retval.0.i
}
Transformation doesn't verify!

ERROR: Value mismatch

Example:
i32 noundef %w = #x00000000 (0)
i32 noundef %lb = #x00000005 (5)

Source:
i32 %and.i = #x00000005 (5)
i8 %conv.i = #x00 (0)
i32 %shr.i = #x00000000 (0)
i8 %conv2.i = #x00 (0)
i32 %shr4.i = #x00000000 (0)
i8 %conv6.i = #x00 (0)
i32 %shr8.i = #x00000000 (0)
i8 %conv10.i = #x00 (0)
i1 %cmp.i8 = #x1 (1)
```

SAW: 0 succeeded, 1 failed.

```text
                                 (ite _x`3 _x`129 (... ... _x`135 (... ... _x`132)) _x`128)
                                 _x`130))))
                     (ite _x`3
                        (bvEq 1 _x`72
                           (bvOr 1 _x`103 (ite _x`4 (... ... _x`36 _x`101) _x`72 _x`73)))
                        _x`83
                        (bvOr 64
                           (ite _x`3 _x`129
                              (ite _x`3 _x`120 _x`138 (bvOr 64 _x`138 _x`132))
                              _x`137)
                           _x`130)))
                  (bvOr 64
                     (ite _x`3 _x`129
                        (ite _x`3 _x`120 _x`140 (bvOr 64 _x`140 _x`132))
                        _x`139)
                     _x`130)))))
      (bvNat 64 16)

Goal size 1750. Provers used: SBV->Z3
----------Counterexample----------
  w: 671088640
  lb: 5
----------------------------------
Stack trace:
   (builtin) in z3
   cell.saw:56:46-56:48 in (callback)
   (builtin) in llvm_verify
   cell.saw:56:1-56:48 (at top level)
Proof failed.
```

## Revert

- Revert hash matches before: `True`
- Post-revert baseline green: `True`

Raw logs and result files are in this directory. The working tree's cells were never edited; only the archive copy was.
