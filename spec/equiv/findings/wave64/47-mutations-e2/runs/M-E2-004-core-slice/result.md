# M-E2-004-core-slice — M-E2-004 (core-slice)

- Cell: `cells/e2-numeric/within-boundary` (catalogue cell `cells/e2-numeric/within-boundary`)
- Target: `spec/equiv/cells/e2-numeric/within-boundary/src/c_leaf.cpp`
- HEAD: `5946c024546e39f55775bfd9a077b042e3feeef4`
- Execution root: byte-identical `git archive HEAD spec/equiv` copy under `.work/spec/equiv` (target hash verified against HEAD before mutation).
- Classification: **KILLED**
- Caught: `True` by `alive2, saw`

## Mutation

```diff
--- a/spec/equiv/cells/e2-numeric/within-boundary/src/c_leaf.cpp
+++ b/spec/equiv/cells/e2-numeric/within-boundary/src/c_leaf.cpp
@@ -33,7 +33,7 @@
   const int64_t a = core_set_vch_1byte(av);     // bn1 = stacktop(-3)
   const int64_t b = core_set_vch_1byte(bv);     // bn2 = stacktop(-2)
   const int64_t c = core_set_vch_1byte(cv);     // bn3 = stacktop(-1)
-  const bool v = (b <= a && a < c);             // interpreter.cpp:1020
+  const bool v = (b <= a && a <= c);  // M-E2-004 mutant: inclusive max             // interpreter.cpp:1020
   BStack s{};
   // vchTrue is {1}; vchFalse is the empty vector (interpreter.cpp:423-425).
   const uint32_t e = v ? core_push_raw(s, 1u, 1u) : core_push_raw(s, 0u, 0u);
```

- sha256 before: `4e72978fa99ad69e058b0791966813a0643fc42424b396d3a87c12fdab26ebca`
- sha256 after: `c17b6c5d4c4a5a4dd720cc74727f1dfaaaccbade2fceae881ef87344c35bd8ce`

## Command

```sh
cd spec/equiv && bash cells/e2-numeric/within-boundary/alive2/run.sh
cd spec/equiv && bash cells/e2-numeric/within-boundary/saw/run.sh
```

## Expected detection

Alive2 C-vs-L must report a value mismatch on a triple where x == max; SAW must fail the C proof against the independent within predicate (min <= x < max). Witness: x=5, min=1, max=5; baseline EVAL_FALSE, mutant vchTrue.

Witness input: `av=5, bv=1, cv=5`

## Actual output

| leg | baseline | mutant | post-revert |
|---|---|---|---|
| alive2 | alive2-green | alive2-not-green | alive2-green |
| saw | saw-green | saw-not-green | saw-green |

Alive2 per-function result:

| function | correct | mismatch |
|---|---|---|
| `cell_within` | False | True |

Alive2 failure excerpt:

```text
  ret i64 %retval.4
}
Transformation doesn't verify!

ERROR: Value mismatch

Example:
i8 noundef zeroext %av = #x00 (0)
i8 noundef zeroext %bv = #x00 (0)
i8 noundef zeroext %cv = #x00 (0)

Source:
ptr %s = pointer(local, block_id=0, offset=0) / Address=#x8000000000000000
i1 %tobool.not.i29299 = #x0 (0)
i8 %#0 = #x00 (0)
i64 %conv.i28 = #x0000000000000000 (0)
i64 %sub.i30 = #x0000000000000000 (0)
i64 %cond.i31 = #x0000000000000000 (0)
i1 %tobool.not.i34298 = #x0 (0)
i8 %#1 = #x00 (0)
```

SAW: 0 succeeded, 1 failed.

```text
                   (bvAnd 32 (bvNat 32 2088960)
                      (bvShl 32 _x`13 (bvToNat 32 (bvNat 32 13)))));
      _x`18 = bvOr 64
                (bvUExt 32 32 (bvOr 32 (bvOr 32 (bvNat 32 8) _x`15) _x`16))
                _x`17;
      _x`19 = bvNat 32 1;
      _x`20 = bvOr 64
                (bvUExt 32 32 (bvOr 32 (bvOr 32 _x`19 _x`15) _x`16))
                _x`17;
    }
 in ite _x`1 _x`14 _x`18
      (ite _x`1 (bvEq 32 _x`19 _x`13)
         (ite _x`1 (bvEq 32 _x`3 (bvAnd 32 (bvNat 32 127) _x`13)) _x`18
            _x`20)
         (ite _x`1 (bvEq 32 _x`3 (bvAnd 32 (bvNat 32 255) _x`13)) _x`18
            _x`20))

Goal size 279. Provers used: abc_verilog
----------Counterexample----------
  a: 65
  b: 241
  c: 65
----------------------------------
Stack trace:
   (builtin) in abc
   cell.saw:14:44-14:47 in (callback)
   (builtin) in llvm_verify
   cell.saw:14:1-14:47 (at top level)
Proof failed.
```

## Revert

- Revert hash matches before: `True`
- Post-revert baseline green: `True`

Raw logs and result files are in this directory. The working tree's cells were never edited; only the archive copy was.
