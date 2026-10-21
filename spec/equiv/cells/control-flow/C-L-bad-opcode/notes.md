# control-flow/C-L-bad-opcode

## Status

`both-green` for the symbolic single-dispatch domain: four wire classes,
symbolic fExec, sigversion and starting opcode counter.

## Design

The cell covers the two ways an opcode reaches Core's `default:`
`SCRIPT_ERR_BAD_OPCODE` arm (`interpreter.cpp:1227-1228`) and the interaction
with the pre-dispatch checks:

1. `OP_VERIF`/`OP_VERNOTIF` (0x65/0x66) are inside `[OP_IF..OP_ENDIF]`, so the
   gate at `:493` dispatches them even in an unexecuted branch; the Lean model
   makes them `.badOpcode` unconditionally. This is SCR-065.
2. `OP_VER` (0x62) and `OP_RESERVED` (0x50) are outside that range: they are
   BAD_OPCODE when executed and skipped when not. This is SCR-066.
3. The budget (`:459-463`) runs before dispatch. `OP_VER` is `> OP_16`, so an
   unexecuted OP_VER still increments the counter; at 202 the result is
   OP_COUNT (7), not BAD_OPCODE (16).

The selector is two bits (0=RESERVED, 1=VER, 2=VERIF, 3=VERNOTIF), masked in
both leaves and in the Cryptol spec. Without the mask clang lowers the mapping
to a bit-test `switch` whose symbolic `lshr` amount is poison for selector
values >= 4, which Alive2 tolerates (both legs identical) but SAW cannot
refine.

## Alive2

`alive2/run.sh` runs the single C/L pair: `Transformation seems to be
correct!`, `1 correct transformations`, `0 incorrect`, `0 failed-to-prove`,
`0 Alive2 errors`; `alive2/result.txt` ends in `STATUS=alive2-green`.

`src/build.sh` drops the ` or disjoint ` poison flag from the extracted `.ll`
before reassembly (packed fields are bit-disjoint by construction, so the
rewrite is value-preserving); both tools consume the same normalized artifact.

## SAW

`saw/run.sh` verifies both legs against the independent Cryptol predicate: 2
`Proof succeeded!` lines, no `Proof failed`; `saw/result.txt` ends in
`STATUS=saw-green`. After masking the selector, abc discharged the proof with
no symbolic-shift warning.

## Limits

- Only one dispatch; the counter is an input, so the cell proves the step law,
  not a whole-script accumulation.
- Only the four default-arm wires are selected. OP_RESERVED1/OP_RESERVED2 are
  the same `default:` branch and are not separately instantiated.
- sigversion values outside {0,1,2} are unreachable enum values; both legs
  treat them as non-counting, non-special.
- No Core source patch is used.
