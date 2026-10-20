# numeric/C-L-within-4byte

SCR-089 (`min ≤ x < max`, `OP_WITHIN`), a bounded op cell with **both tools
green** symbolically over the full 4-byte operand domain.

## Why a second WITHIN cell

`cells/e2-numeric/within-boundary` proved the rule for **one-byte** operands
(all 2^24 triples) with a 2-byte leaf.  Its record states the remaining gap:
2–4 byte operands and the width cap.  This cell closes that gap instead of
duplicating the one-byte result: each of `x`, `min`, `max` is symbolic over
its full content word (2^32) and its length 0..7.

## Source

- `interpreter.cpp:1012-1026` — `case OP_WITHIN`: `CScriptNum bn1
  (stacktop(-3), fRequireMinimal)`, `bn2(stacktop(-2), ...)`,
  `bn3(stacktop(-1), ...)`; `bool fValue = (bn2 <= bn1 && bn1 < bn3)` at line
  1020; then `stack.push_back(fValue ? vchTrue : vchFalse)`.
- `script.h:246-271` — CScriptNum width guard (`vch.size() > 4`) and the
  minimality guard (off: flags = 0).
- `script.h:376-391` — `set_vch` sign-magnitude decode.
- `interpreter.cpp:1877-1878` — the tail's `EVAL_FALSE` for `vchFalse = {}`.

## Entry point

```c
uint64_t cell_within(uint32_t wx, uint32_t lx,
                     uint32_t wmn, uint32_t lmn,
                     uint32_t wmx, uint32_t lmx);
```

Entry stack `[x, min, max]`; lengths are masked `& 7`.

## Symbolic claim

- Alive2: `cell_within`, 1/1 `correct transformations`.
- SAW: 2/2 `Proof succeeded` (C and L) against `tools/num.cry:pWithin` for
  every `(wx, lx, wmn, lmn, wmx, lmx)`.

`pWithin` decodes in the same order as Core and reuses the `sle`/`slt` signed
comparisons defined once for the binary row, so a WITHIN regression caused by
a comparison change would also show up in the SCR-088 cell.
