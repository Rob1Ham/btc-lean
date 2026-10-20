# numeric/C-L-equal-rawbytes

SCR-091 (`raw bytes, not numeric`, `OP_EQUAL` / `OP_EQUALVERIFY`), a bounded
op cell with **both tools green** over every 8-byte element pair and every
length 0..8.

## Source

- `interpreter.cpp:897-923` — `case OP_EQUAL: case OP_EQUALVERIFY:`;
  `bool fEqual = (vch1 == vch2)` at 906 is a `valtype` comparison: equal
  length, then that many bytes.  No `CScriptNum` is constructed, so a 520-byte
  push is legal here and the numeric width cap is irrelevant.
- `interpreter.cpp:907-911` — the `case OP_NOTEQUAL` is commented out with the
  "use OP_NUMNOTEQUAL" note; there is no OP_NOTEQUAL opcode (0x8e is OP_2DIV,
  see the `C-L-2div-disabled` cell).
- `interpreter.cpp:916` — `stack.push_back(fEqual ? vchTrue : vchFalse)`.
- `interpreter.cpp:919-922` — `OP_EQUALVERIFY` pops on success and returns
  `SCRIPT_ERR_EQUALVERIFY` otherwise.
- `interpreter.cpp:1877-1878` — the tail's `EVAL_FALSE` for `vchFalse = {}`
  and for the empty stack left by a successful `EQUALVERIFY`.

## Entry points

```c
uint64_t cell_equal(uint64_t wa, uint32_t la, uint64_t wb, uint32_t lb);
uint64_t cell_equalverify(uint64_t wa, uint32_t la, uint64_t wb, uint32_t lb);
```

`num_len8(l) = min(l & 15, 8)` is applied to both legs *and* to the Cryptol
spec, so the compared domain is exactly lengths 0..8.

## Symbolic claim

- Alive2: 2/2 `correct transformations`.
- SAW: 4/4 `Proof succeeded` (C and L for both wires) against
  `tools/num.cry:pEqual`.

## Model bug found by this cell

The first SAW run failed with a counterexample at `la = lb = 1` whose *padding
bytes* differed.  Both legs compared only the first byte and reported
equality; the model's `equalRaw` compared **all eight** bytes regardless of
length, so it reported inequality.  The legs were right and the model was
wrong.  `equalRaw` now guards each byte with `La < k || ...`, which is exactly
Core's length-then-bytes rule.  This is the value of the third leg: an
independent model that can be wrong in a way two implementations of the same
source are unlikely to be wrong together.

The same file also carries the Cryptol lessons from the earlier cells:
literals take their width from the digit count (use 16 hex digits for `[64]`),
`!` does not exist (use `~`), and `||` binds tighter than `==`, so chained
comparisons need parentheses.

## Observable

The packed observable reserves four bits for the element length, so an 8-byte
top element is representable.  It still packs only the first five bytes of the
top element; for this cell that is enough to distinguish every outcome
(`{1}` versus empty), and the *compared* elements are fully symbolic — the
observable is not the comparison, it is the verdict plus the pushed result.
