# numeric/C-L-unary-4byte

SCR-087 (`1ADD/1SUB/NEGATE/ABS/NOT/0NOTEQUAL`), a bounded op cell with **both
tools green** symbolically over the full 4-byte operand domain plus the width
reject edge.

## Source

Pinned Core `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`:

- `src/script/interpreter.cpp:929-953` — `case OP_1ADD` … `case OP_0NOTEQUAL`.
  Each arm pops one operand, applies the arithmetic, and pushes
  `bn.getvch()`.
- `src/script/script.h:246-271` — `CScriptNum(vch, fRequireMinimal,
  nMaxNumSize = 4)`; the width guard rejects `vch.size() > 4`.
- `src/script/script.h:342-373` — `CScriptNum::serialize` (sign-magnitude,
  little-endian, extra `0x00`/`0x80` byte when the top bit is set).
- `src/script/interpreter.cpp:1877-1878` — VerifyScript's tail: `EVAL_FALSE`
  when the sole stack element is not `CastToBool`-true.

## Entry points

```c
uint64_t cell_1add(uint32_t w, uint32_t lb);      // 0x8b
uint64_t cell_1sub(uint32_t w, uint32_t lb);      // 0x8c
uint64_t cell_negate(uint32_t w, uint32_t lb);    // 0x8f
uint64_t cell_abs(uint32_t w, uint32_t lb);       // 0x90
uint64_t cell_not(uint32_t w, uint32_t lb);       // 0x91
uint64_t cell_0notequal(uint32_t w, uint32_t lb); // 0x92
```

`w` is the little-endian content of the single operand element, `lb & 7` its
length.  The entry stack is exactly `[x]`, so the tail observes the pushed
result.

## Symbolic claim

- Alive2: `alive-tv build/c_cell_<op>.ll build/l_cell_<op>.ll` for all six
  entry points — 6/6 `correct transformations`.
- SAW: `src/cell.saw` verifies **both** modules against
  `tools/num.cry:pUnary` for every `(w, lb)` pair — 12/12 `Proof succeeded`.

## Model

`pUnary wi w L` decodes with `decode` (width cap 4, sign bit `0x80`, no
minimality), applies `unOp`, re-serializes with `encLen`/`encByte`, and packs
the tail observation.  It is written from `script.h`/`interpreter.cpp` and the
Lean `unOp` equations, not derived from either leg.

Model bug found while building the later EQUAL cell (same file): Cryptol binds
`||` tighter than `==`, so chained comparisons need parentheses; and
`decode` must mask the magnitude to exactly `L` bytes before clearing the sign
bit.  Both are fixed in `tools/num.cry`; the unary and binary proofs were
re-run against the corrected model.

## Tool notes (shared by all five numeric cells)

See `C-L-binary-4byte/notes.md` for the pipeline (post-extract `opt`,
`expand_abs.py`, SMT timeout, z3) — the build and normalisation steps are
identical in every cell of this family.
