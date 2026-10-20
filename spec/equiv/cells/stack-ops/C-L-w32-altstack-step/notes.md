# stack-ops/C-L-w32-altstack-step

SCR-073 as a symbolic single-step cell.

The existing `e1-altstack/roundtrip` and `stack/C-L-altstack` cells are
closed witnesses: they cover one success roundtrip and the two empty-stack
errors.  They do not touch the opcode budget and they have no symbolic
inputs.  This cell replaces the witness with a symbolic step:

| input | range | row clause exercised |
|---|---|---|
| `opc` | any 32-bit nOpCount | `opc = 200` moves; `opc = 201` is OP_COUNT |
| `exec` | 0/1 | unexecuted branch is a no-op, budget still counted |
| `wire` | 0x6b/0x6c | both ops |
| `sn` | 0..4 | `sn = 0` with TOALTSTACK is INVALID_STACK_OPERATION |
| `an` | 0..4 | `an = 0` with FROMALTSTACK is INVALID_ALTSTACK_OPERATION |
| `s_top`, `a_top` | all bytes | the moved item is the actual top byte |

Alive2 compares the two legs over all of those inputs (with a raised SMT
timeout).  SAW verifies each leg against the independent Cryptol `step`
model.

Limits: this is one EvalScript step, not the loop; the loop's decode and
`opcodeIndex` are out of scope.  Main/alt depths are bounded at 4, so the
combined `stack.size() + altstack.size() > MAX_STACK_SIZE` guard (1000) is
unreachable and is not claimed.  The two opcodes are the only in-domain
wires; other wires return a common sentinel and are not judged.
