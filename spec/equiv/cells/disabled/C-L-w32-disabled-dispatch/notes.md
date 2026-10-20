# notes — C-L-w32-disabled-dispatch

Rows: SCR-170, SCR-171, SCR-174.

## What is proved

`cell_guard` is the loop-head guard slice. For symbolic `w`, `wv0`,
`nOpCount`, `fExec` both legs agree, and the SAW predicate is independent:

| condition | outcome |
|---|---|
| `wv0 && w > 0x60 && nOpCount + 1 > 201` | 7 = OP_COUNT |
| `w` in the fifteen disabled wires | 17 = DISABLED_OPCODE |
| otherwise, `fExec` set / clear | 64 execute / 65 skip |

The disabled arm is reached after the budget arm and never reads `fExec`,
which is the SCR-171 ordering claim. The budget arm is the stated exception in
SCR-170 (`OP_COUNT` preempts `DISABLED_OPCODE`).

`cell_default` extends this to Core's switch entry and default arm. The L-side
wire classes are generated, not hand-written: `src/gen_wire_table.py` imports
`twin/ops_ir.py`, parses `disabled_wire` out of `twin/runtime.inc`, and refuses
to build if `{disabled, pushbytes, pushnum, bad, dispatched}` is not a
partition of `0x00..0xff`. This is what makes the default-set comparison
meaningful: a hole in the twin's coverage would be a duplicate/overlap or a
missing wire, not a silent `BAD_OPCODE`.

Default set proved equal on both legs:
`{0x50, 0x62, 0x65, 0x66, 0x89, 0x8a} ∪ [0xbb,0xff]`, with `0xba`
distinguished as an explicit case that returns BAD_OPCODE under
BASE/WITNESS_V0.

## What is not covered

- Tapscript: the fifteen bytes are OP_SUCCESSx and never reach this step;
  see `disabled/C-L-w32-opsuccess-scan`.
- `GetOp` decode failure and PUSH_SIZE ordering (F-DIV-001).
- OP_CODESEPARATOR/CONST_SCRIPTCODE, stack effects, and the remaining switch
  arms' internal semantics. 64 only means "the execute arm is reached".
- `nOpCount` is a 32-bit wrapping add, matching Core; no 201-op accumulator
  state machine is modelled.

## Tool note

Alive2 certificates include `build/wire_table.h`, which is regenerated on
every run from the pinned twin sources. The `build/` directory is ignored by
git, as for the other cells; `sha256sum -c` is run from the repository root
in a tree where the cell has been built.
