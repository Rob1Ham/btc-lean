# control-flow/C-L-if-notif

## Status

`both-green` for the symbolic bounded op domain: element length 0-2, every
byte value, symbolic fExec / sigversion / MINIMALIF flag / stack depth. This is
a single-op cell, not a whole-entry proof.

## Design

The C leaf is the OP_IF/OP_NOTIF case body (`interpreter.cpp:613-645`) with
`CastToBool` (`interpreter.cpp:46-59`) inlined at a compile-time-fixed element
length, one exported function per length in {0,1,2}. `fExec`, the sigversion,
and the MINIMALIF flag are leaf inputs. The state is bounded: stack depth plus
the top element, and one condition-stack slot (the cell starts with an empty
condition stack).

The L leaf is a direct transcription of the Lean model
(`spec/core/Bitcoin/Interpreter/Defs.lean:878-891`): the same TAPSCRIPT arm
(error 51), witness-v0 MINIMALIF arm (error 31), `castToBool`, NOTIF inversion,
and tail-pop, with `Bool` condition-stack push. Error ordinals come from the
generated `core_ord` map, so the C and L error codes are compared as numbers.

The packed observable is `result(2) | error(6) | depth(8) | vf_n(2) | vf0(1)`;
it records the success/error outcome, the post-op stack depth (to prove the pop
and the no-pop-on-skip), and the condition-stack top that the opcode pushes.

## Twin gap filed here

`twin/ops_ir.py`'s `OP_IF` body (`used for wires 0x63/0x64`) checks only
`stack.n < 1`, then `cast_to_bool`. It does **not** implement either minimal-IF
arm: neither `Defs.lean:883-887`'s tapscript check (error 51) nor the
witness-v0 + `minimalIf` policy check (error 31). Its own `lean` annotation
points at `Defs.lean:878-891`, so the handler and its citation disagree. This
cell's L leg deliberately transcribes the Lean model instead, which is why the
two green results do not certify `twin/ops_ir.py`'s OP_IF handler. The gap is
reported in `spec/equiv/findings/wave16/05-control-flow/report.md`; it is not
patched here (shared twin files are out of this task's write scope).

## Alive2

`alive2/run.sh` builds `src/build.sh` and runs three C/L pairs through
`alive-tv`. All three report `Transformation seems to be correct!` with
`1 correct transformations`, `0 incorrect`, `0 failed-to-prove`, and
`0 Alive2 errors`; `alive2/result.txt` ends in `STATUS=alive2-green`.

`src/build.sh` post-processes the extracted `.ll` to drop the ` or disjoint `
poison flag before reassembly. SAW 1.6 leaves that flag unconstrained in the
returned term, and the packed fields are bit-disjoint by construction, so the
rewrite is value-preserving. Both tools consume the same normalized artifact.

## SAW

`saw/run.sh` copies `src/cell.cry` / `src/cell.saw` into `build/` and verifies
each leg against the same independent Cryptol predicate: 6 `Proof succeeded!`
lines (3 lengths x C and L), no `Proof failed`; `saw/result.txt` ends in
`STATUS=saw-green`.

## Limits

- Element length 0-2 only (the twin bounded element domain). Lengths >= 3 are
  not machine-enumerated.
- One opcode, one condition-stack push, no script loop, no opcode budget, no
  push-size/stack-size checks. Those are separate cells/rows.
- `sigversion` is an enum with three values; the cell treats any other value as
  base. Those values are unreachable in Core, and both legs use the same
  convention.
- No Core source patch is used.
