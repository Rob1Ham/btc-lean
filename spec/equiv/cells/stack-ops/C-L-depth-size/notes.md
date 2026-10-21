# stack-ops/C-L-depth-size

Closes SCR-076 (OP_DEPTH / OP_SIZE) as bounded symbolic laws. Thirteen entries:
DEPTH at depths 0..3, SIZE at lengths 0,1,2,127,128,255,256,520, and SIZE on an
empty stack.

## DEPTH

`OP_DEPTH` has no stack-size pre-check. It pushes
`CScriptNum(stack.size()).getvch()`, so the observable is the final depth and
the encoding of the pre-push depth:

| entry | pre-push depth | pushed vector | final depth |
|---|---|---|---|
| `cell_depth_d0` | 0 | empty (zero) | 1 |
| `cell_depth_d1` | 1 | `01` | 2 |
| `cell_depth_d2` | 2 | `02` | 3 |
| `cell_depth_d3` | 3 | `03` | 4 |

`d = 3` fills all four slots. `d = 4` is excluded: the twin's `st_push_num`
would return STACK_SIZE while Core's unbounded vector would not, which is the
stack-size edge, not this row.

## SIZE

`OP_SIZE` checks `stack.size() >= 1`, leaves the original element and pushes
the minimal `CScriptNum` encoding of its length. The chosen lengths cover every
branch of `CScriptNum::getvch` in the 0..520 range:

| length | pushed vector |
|---|---|
| 0 | empty |
| 1,2,127 | one byte (`01`,`02`,`7f`) |
| 128,255 | two bytes with a `0x00` sign byte (`80 00`, `ff 00`) |
| 256 | `00 01` |
| 520 | `08 02` |

The empty-stack entry (`cell_size_empty`) proves the size pre-check returns
INVALID_STACK_OPERATION (18), after the budget check a budget failure returns
OP_COUNT (7) first.

## Observable and the `usub.sat` trap

`src/obs.h` defines the two observables locally, identically for both legs.
The DEPTH pack reads four *fixed* slots exactly like `pack_obs`; an earlier
version read the dynamic top slot (`s.n - 1`) and the optimiser lowered the
guard to `llvm.usub.sat.i32`, which SAW/abc cannot load. The SIZE pack reads
slot 0 and slot 1 directly, because the only successful shape is two slots.
The original-length field is ten bits, not nine: 520 does not fit in nine, and
a nine-bit field silently aliased 520 with 8.

## Trust

The C leg is a line-cited slice of the budget gate and the DEPTH/SIZE cases,
with the minimal CScriptNum encoder transcribed from `getvch`. The L leg calls
the handlers generated verbatim from `twin/ops_ir.py` by
`cells/_tools/mk_leaf.py`, inside a mirror of `twin/runtime.inc:594-652`.
`cell.cry` is written from the rules, not from either leg; it passes the
encoding bytes explicitly for each SIZE wrapper so the proof does not rely on
Cryptol shifts over the 0..520 range. Both tools run at `-O1`, both legs from
the same source. No source patch.
