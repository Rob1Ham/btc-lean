# Cell `checksig/C-L-checksig-opcount`

## What is proved

One closed function per leg, `cell_opcount`, over a symbolic starting count
`n0`, SigVersion `sv`, execution flag `fExec`, and eight symbolic wire
opcodes `w0..w7`.  The return word is `(count << 8) | error`.

Each step is exactly `Defs.lean:824-830` / `interpreter.cpp:460-464`:

```
counts = (sv == BASE || sv == WITNESS_V0) && wire > 0x60
count' = counts ? count + 1 : count
error 7 iff counts && count' > 201
```

Because `n0` is arbitrary, the one-step rule and the exact `201 -> 202`
failure point are exercised for all inputs; the eight-step unrolling shows
accumulation and that the walk stops at the first error.  `fExec` is carried
but unused in both legs — the increment precedes the execution test, so
unexecuted-branch opcodes are charged too.

## What is *not* claimed

- No script parsing, stack effects, disabled-opcode table, or element-size
  guard; only the budget transition.
- `sv` values other than 0/1 do not count (tapscript); the domain is
  {0,1,2}.
- No R leg (F-HARNESS-002 / F-TOOL-001).
- Alive2 v20 cannot ingest attached TBAA/alias.scope metadata in this shape,
  so the runner strips those optimizer hints from both legs identically.

## SAW notes

The Cryptol predicate folds the same one-step function eight times; the
signature initially declared one parameter too few and was rejected before
any proof obligation (fixed to 11 inputs).  No domain guard is needed: the
function only compares and adds 32-bit words.
