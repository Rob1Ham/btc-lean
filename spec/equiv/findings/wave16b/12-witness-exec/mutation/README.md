# Mutation probes (non-vacuity)

Two single-leg mutants of the L translation were built in scratch and checked
against the unmutated C slice (Alive2) and the unmutated Cryptol spec (SAW).
Neither mutant is committed to the cell; this directory records the runs.

Tools: `alive-tv v20.0` (`c0f5434`, LLVM 20.1.2); SAW 1.6 (`68eed5f`,
release-1.6), solver `abc`; clang++-20 `20.1.2`.

## M1 — cleanstack accepts a non-singleton stack

Diff: `M1-cleanstack.diff`

```diff
-    if (n != 1) {
+    if (n < 1) {
```

This is the mutation the E4 report proposed for the dispatch cell, moved to
the cleanstack consumer (scr 138). With it, a final stack of size 2 is
accepted.

Exact commands (scratch dir `/tmp/opencode/wave16b-scratch/12-witness-exec/mutation`):

```sh
clang++-20 -std=c++17 -O1 -fno-strict-aliasing -fno-discard-value-names -I. \
  -c -emit-llvm c_cell.cpp -o c_leaf.bc
clang++-20 ... -c -emit-llvm l_cell.cpp -o l_leaf.bc
llvm-extract --func=cell_v0_exec --recursive c_leaf.bc -o c_mut.bc
llvm-extract --func=cell_v0_exec --recursive l_leaf.bc -o l_mut.bc
alive-tv c_mut.ll l_mut.ll
saw cell.saw
```

Alive2 (`M1-alive2.log`):

```text
Transformation doesn't verify!
ERROR: Value mismatch
Example:
Source value: #x0400515175517178 (288319786454184312)
Target value: #x0400515175517101 (288319786454184193)
1 incorrect transformations
```

Decoding the packed record: both sides execute P2WSH kind 2
(`51 75 51 51`, length 4, final stack size 2). The C slice returns
`result=0, error=30 (CLEANSTACK)`; the mutant returns `result=1, error=0`.
This is the expected counterexample.

SAW (`M1-saw.log`):

```text
Proof succeeded! cell_v0_exec      (C module)
Subgoal failed: cell_v0_exec cell.saw:28:1
Proof failed.                      (mutant L module)
```

## M2 — WITNESS_V0 applies FindAndDelete

Diff: `M2-sigversion-gate.diff`

```diff
-    const uint32_t found = (sv == 0) ? (uint32_t)fd_found : 0u;
-    const uint32_t applied = (sv == 0 && fd_found != 0) ? 1u : 0u;
+    const uint32_t found = (sv <= 1) ? (uint32_t)fd_found : 0u;
+    const uint32_t applied = (sv <= 1 && fd_found != 0) ? 1u : 0u;
```

With it, `sv = 1` (WITNESS_V0) consumes `fd_found` as if it were BASE, i.e.
the v0 path would apply FindAndDelete. This is the exact SCR-139 violation.

Alive2 (`M2-alive2.log`):

```text
Transformation doesn't verify!
Example:
Source value: #x0000000000000201 (513)
Target value: #x0000000000000207 (519)
1 incorrect transformations
```

Decode: the counterexample is `sv=1, fd_found=1, const_sc=0`. C returns
`result=1, applied=0, found=0, sv=1` (`0x201`); the mutant returns
`result=1, applied=1, found=1, sv=1` (`0x207`).

SAW (`M2-saw.log`):

```text
Proof succeeded! cell_checksig_gate   (C module)
Subgoal failed: cell_checksig_gate cell.saw:30:1
Proof failed.                         (mutant L module)
```

## What this establishes

The two tools are not accepting the cell vacuously: a one-line change to the
cleanstack predicate and a one-line change to the sigversion gate are both
rejected, with the expected input in the counterexample. It does **not**
establish any refinement of the abstractions in `notes.md` (R1-R9); it only
shows the bounded model is pinned by the tools.
