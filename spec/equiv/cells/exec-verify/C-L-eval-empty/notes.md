# exec-verify/C-L-eval-empty — notes

## Design

The cell extracts the only part of `EvalScript` that is a *frame* property
rather than opcode semantics: the loop-entry condition, the stack handoff, and
the trailing `vfExec` check.  Everything below the loop (GetScriptOp, the
switch, CScriptNum, limits, vectors) is the E5 residual and is replaced by a
declared out-of-model marker so the function stays total and Alive2 can
compare it.

Why the marker is honest: the marker is what the harness returns for inputs
outside the cell's claim.  It appears in both legs identically, so Alive2's
equality includes it, but the SAW postcondition carries the input stack for
every case, and the row statement is only made for `ops_len = 0`.  The marker
branch is not a chain claim and is not used to promote a row.

## Build and tools

```text
clang++-20 (Ubuntu clang version 20.1.2) -O1 -c -emit-llvm
llvm-extract/llvm-dis 20.1.2, --func=cell_eval_frame --recursive
alive-tv 20.0 (LLVM 20.1.2 build)
SAW 1.6 (68eed5f), bundled z3
```

Generated `build/` is git-ignored; the certificates include the generated
`.ll`/`.bc` so they verify after a cell run.

## Why "short" reduces to the empty script

`GetScriptOp` (script.cpp:313-364) always consumes at least one byte and
returns an opcode for any non-empty input, even if the push data is truncated
(it returns `false` — a parse error — but the loop has still entered).  So a
script whose opcode list is empty is exactly the empty script.  A script with
one push *does* change the stack, so the ledger summary's "short" cannot mean
"some pushes"; it means the zero-op base case, which is what the Lean rule
covers (`evalFrom _+1 [] st`).

## Limits

- No opcode execution at all (E5 residual).
- Fuel is not modelled; see spec.md.
- The stack is bounded to four one-byte items.  The frame touches none of
  them, so the bound only limits how much of the "unchanged" projection is
  observable, not the branch structure.

## Mutation proposal (not executed)

Insert `stack.clear()` on the success path (or return depth 0).  Expected:
Alive2 counterexample for `st_n != 0`; SAW failure of `cell_eval_frame`
because the postcondition returns the input stack.
