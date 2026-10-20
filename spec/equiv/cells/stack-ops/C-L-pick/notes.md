# stack-ops/C-L-pick

Closes SCR-075 (OP_PICK / OP_ROLL) as a family of bounded symbolic laws. Each
entry is the same C slice and the same twin handler; only the depth, the ROLL
index constant, and the fExec constant differ.

## Shape of the cell

Twelve entries:

| entry | depth | index | fExec |
|---|---|---|---|
| `cell_pick_d3_sym`, `_d2_sym`, `_d1_sym` | 3, 2, 1 | symbolic | 1 |
| `cell_roll_d3_k0/k1/k2` | 3 | 0, 1, 2 | 1 |
| `cell_roll_d2_k0/k1` | 2 | 0, 1 | 1 |
| `cell_roll_d1_k0` | 1 | 0 | 1 |
| `cell_pick_d0`, `cell_roll_d0` | 0 | symbolic | 1 |
| `cell_skip` | 3 | symbolic | 0 |

The index is pushed last, so depth `d` means `d` data elements plus the index.
At depth 3 the total stack is 4, the largest value in the leaf domain, so the
final STACK_SIZE guard is exercised at its boundary but never tripped. PICK at
depth 3 pushes a copy and also leaves four elements. All data elements are
symbolic one-byte values.

## What the law pins down

1. **Budget first.** `opc` is the incoming nOpCount, not the opcode; the wire
   is fixed per entry (0x79 for PICK, 0x7a for ROLL). BASE/WITNESS_V0 charge one
   unit for any wire above OP_16, so nOpCount 201 returns OP_COUNT (7) and 200
   passes. TAPSCRIPT charges nothing. Because nOpCount is symbolic in every
   entry, both sides of the boundary are covered. `cell_skip` has fExec = 0 and
   symbolic nOpCount, so it also proves budget failure precedes the skip.
2. **Size pre-check.** At depth 0 only the index is on the stack; size < 2
   returns INVALID_STACK_OPERATION (18) for both opcodes.
3. **Index decode and bounds.** CScriptNum over a one-byte vector: 0x80 is
   negative zero (0), 0x81..0xff are negative, and everything else is its
   unsigned value. After the index is popped, n outside [0, d) is 18. The PICK
   entries keep the index symbolic over all 256 encodings, so in-range
   selection, the 0x80 negative-zero case and every out-of-range encoding are
   all in the proof. ROLL enumerates every valid constant index at each depth.
4. **The move.** PICK copies stacktop(-n-1) and pushes it, increasing the depth
   by one. ROLL erases that element and pushes it on top, keeping the depth.
   The packed observable exposes all four slot values and the depth, so a
   copy-without-pop, a wrong ordering or a wrong depth fails. At depth 3 ROLL
   k0 is the identity, k1 swaps the top two, k2 rotates the bottom to the top;
   all three are checked with symbolic values.

## Tool-specific builds

The two tools need different optimisation levels for this cell, so they build
into separate directories (`build-alive2/` and `build-saw/`):

- Alive2 at `-O1` rejects the ROLL arms: the twin's constant-index shift loop
  keeps an undef-valued element extraction in `bounded_memcpy`, and Alive2
  reports the source as more defined than the target. At `-O2` the loop folds
  and C and L compare.
- SAW/abc at `-O2` reports "Poison value created / negative integer was
  zero-extended even though the nneg flag was set" for the negative-index
  encodings in `decode_num`'s `zext nneg`. At `-O1` abc proves all 24 legs,
  including the negative-index branch.

Within each tool both legs come from the same source at the same level, so the
comparison remains C-vs-L. `spec.md` records the split; each certificate lists
its own build directory.

## Trust

C is a line-cited slice of EvalScript's budget gate, fExec gate and PICK/ROLL
case. L calls the handlers generated verbatim from `twin/ops_ir.py` by
`cells/_tools/mk_leaf.py`, inside a mirror of `twin/runtime.inc:594-652`; an
unexecuted entry is one false condition-stack frame so the twin's own `vf_all`
decides. `cell.cry` is a direct transcription of the rules above, not derived
from either leg, and the SAW script verifies both legs of every entry against
it. No source patch.
