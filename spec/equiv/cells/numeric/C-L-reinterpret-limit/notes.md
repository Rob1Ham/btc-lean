# numeric/C-L-reinterpret-limit

SCR-085 (`only re-interpretation enforces limit`), a bounded C/L cell with
both tools green.  The cell separates the three sites the row names:

1. the **raw push** path never constructs a `CScriptNum` and has no 4-byte
   width guard (only `MAX_SCRIPT_ELEMENT_SIZE = 520`);
2. **OP_1ADD** re-interprets its operand through
   `CScriptNum(vch, fRequireMinimal, nMaxNumSize = 4)`, so the width guard
   fires there, exactly for lengths greater than four;
3. `CScriptNum::serialize` / `getvch` has **no width parameter**, so a
   four-byte operand can produce a **five-byte result** that stays on the
   stack as a legal raw element until a later numeric operation
   re-interprets it.

## Source (Bitcoin Core @ `cce32b168`)

- `src/script/script.h:227-236` — the numeric-op width comment:
  operands are restricted to 4-byte integers, but results may overflow and
  are valid as long as they are not used in a subsequent numeric operation.
- `src/script/script.h:246-249` — `CScriptNum` constructor:
  `if (vch.size() > nMaxNumSize) throw scriptnum_error("script number
  overflow");`, with `nMaxNumSize = 4`.
- `src/script/script.h:337-340` — `getvch()` returns `serialize(m_value)`.
- `src/script/script.h:342-373` — `serialize` emits the canonical
  sign-magnitude bytes; there is no width limit in the encoder.
- `src/script/interpreter.cpp:455-458` — the per-instruction raw push check is
  `vchPushValue.size() > MAX_SCRIPT_ELEMENT_SIZE` (520), not 4.
- `src/script/interpreter.cpp:487-492` — the raw push path:
  `stack.push_back(vchPushValue)`.
- `src/script/interpreter.cpp:924-953` — `case OP_1ADD`:
  `CScriptNum bn(stacktop(-1), fRequireMinimal); ... stack.push_back(bn.getvch())`.
- `src/script/interpreter.cpp:1877-1878` — `VerifyScript` tail: `EVAL_FALSE`
  when `CastToBool(stack.back())` is false.

The corresponding Lean witness is
`Bitcoin.Numeric.encodeScriptNum_five_byte_witness` (`2^31` serializes to five
bytes and the 4-byte decoder refuses it), plus
`encodeScriptNum_size_gt_four` and `encodeScriptNum_ignores_flag`.

## Entry points

```c
uint64_t cell_push_raw(uint64_t w, uint32_t l);
uint64_t cell_reinterpret(uint64_t w, uint32_t l);
uint64_t cell_add4_observe(uint64_t w);
uint64_t cell_add4_readd(uint64_t w);
```

`w` is the little-endian content word; `l` is folded by
`clamp8(l) = min(l & 15, 8)` on both legs and in the model.

| Entry point | Script tail after the harness push | Claim |
|---|---|---|
| `cell_push_raw` | `push clamp8(l) bytes` | raw push of every length 0..8; no `SCRIPTNUM` is reachable |
| `cell_reinterpret` | `push; OP_1ADD` | `SCRIPTNUM` (4) iff `clamp8(l) > 4`; otherwise ordinary 1ADD |
| `cell_add4_observe` | `push 4 bytes; OP_1ADD` | result may be five bytes; at `w = 0x7fffffff` it is `00 00 00 80 00` |
| `cell_add4_readd` | `push 4 bytes; OP_1ADD; OP_1ADD` | second add re-interprets the result and returns `SCRIPTNUM` exactly at `w = 0x7fffffff` |

## Concrete witness (both legs, compiled and run)

The packed observable is `result(2) | error(6) | depth(3) | len(4) | bytes 0..4`.
C and L produce identical values:

| call | packed observable | reading |
|---|---|---|
| `cell_push_raw(0, 5)` | `0x0000000000002908` | result 0, error 2, depth 1, len 5, five zero bytes (raw push accepted, tail false) |
| `cell_reinterpret(0, 5)` | `0x0000000000000010` | result 0, error 4 (`SCRIPTNUM`), no stack |
| `cell_reinterpret(0, 4)` | `0x0000000000008901` | result 1, error 0, depth 1, len 1, value 1 |
| `cell_add4_observe(0x7fffffff)` | `0x0000400000002901` | result 1, error 0, depth 1, len **5**, bytes `00 00 00 80 00` |
| `cell_add4_readd(0x7fffffff)` | `0x0000000000000010` | result 0, error 4 (`SCRIPTNUM`) on the second add |
| `cell_add4_readd(0x00000001)` | `0x0000000000018901` | result 1, error 0, depth 1, len 1, value 3 |

The five-byte result is `2^31`'s canonical encoding: magnitude
`0x80000000` little-endian is `00 00 00 80`, and because the top magnitude
byte has the high bit set a positive `0x00` sign-extension byte is appended.
This is exactly Core's `serialize` (`script.h:364-369`) and the Lean witness.

## Symbolic claim

- **Alive2**: 4/4 entry points, `Transformation seems to be correct!`,
  `0 incorrect transformations`, `0 Alive2 errors`.
- **SAW**: 8/8 proofs (`cell_push_raw`, `cell_reinterpret`,
  `cell_add4_observe`, `cell_add4_readd` × C and L) against the shared
  `tools/num.cry` model plus the cell-local raw-push observable in
  `src/cell_extra.cry`.

Domains:

- raw push / reinterpretation: every `(w, l)` pair, i.e. every content word
  `2^64` and all 16 length inputs (0..8 after `clamp8`);
- fixed four-byte result cells: every `2^64` content word (only the low four
  bytes participate, so this is the full `2^32` four-byte operand domain).

The model computes `rawTruthy` (CastToBool over a raw element), raw byte
packing, `pRawPush`, and `pAdd4Readd`; decode/serialize/unOp come from the
shared model.  The shared model's `pUnary` is used for the reinterpretation
entry point and for `cell_add4_observe`, so the numeric semantics are not
re-derived for this cell.

## Bounds and non-claims

- The leaf observes only the first five bytes of the top element (`num_obs` in
  `num_common.h`).  No numeric operation in this cell pushes more than five
  bytes, so the truncation is not reachable on a produced value.
- Element width is 8 bytes and depth is 4.  These are bounded-leaf
  representation constants, not consensus limits.  Raw push lengths above 8
  and the 520-byte `MAX_SCRIPT_ELEMENT_SIZE` boundary are outside this cell.
- Flags are fixed to 0, so `fRequireMinimal` is false and the minimality guard
  is not exercised (that is SCR-079/SCR-080/SCR-084 territory).
- The stack-underflow branch of `OP_1ADD` is not exercised (SCR-078).
- This is a bounded op cell, not a whole-engine equivalence proof, and it is
  not a Lean-kernel theorem.  No Core source patch is used.
