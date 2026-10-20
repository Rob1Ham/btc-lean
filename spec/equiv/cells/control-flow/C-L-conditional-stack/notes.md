# control-flow/C-L-conditional-stack

## Status

`both-green` for the declared one-dispatch domain with a bounded condition
stack (depth 0-2). This is not a whole-script proof.

## Design

The cell models one opcode dispatch followed by the loop-exit check:

- the `[OP_IF..OP_ENDIF]` gate (`interpreter.cpp:493`) decides whether a
  non-conditional opcode runs when `fExec` is false;
- `OP_ELSE` (`:647-653`) toggles the top of `vfExec` and errors on an empty
  stack;
- `OP_ENDIF` (`:655-661`) pops `vfExec` and errors on an empty stack;
- after the loop (`:1245-1246`) a non-empty `vfExec` is
  `UNBALANCED_CONDITIONAL`.

The C leg is the source slice with `vfExec` replaced by a bounded
`(n, v0, v1)` struct; the loop body's two stack operations (`toggle_top`,
`pop_back`) are written exactly. The L leg transcribes the Lean model
(`Defs.lean:893-900`, gate at `:851-853`), with `core_ord` mapping
`unbalancedConditional` to the Core ordinal 20. The `executed` bit records
that a non-conditional handler ran, so the gate row is observable rather than
merely implied.

The selector is two bits: 0=ELSE, 1=ENDIF, otherwise NOP. Both leaves mask the
selector with `& 3` before mapping, and the Cryptol spec does the same; this
avoids clang lowering the mapping to a bit-test switch whose symbolic shift
amount is poison for selectors >= 4.

## Alive2

`alive2/run.sh` builds `src/build.sh` and runs the single C/L pair through
`alive-tv`: `Transformation seems to be correct!`, `1 correct
transformations`, `0 incorrect`, `0 failed-to-prove`, `0 Alive2 errors`;
`alive2/result.txt` ends in `STATUS=alive2-green`.

`src/build.sh` drops the ` or disjoint ` poison flag from the extracted `.ll`
before reassembly (the packed fields are bit-disjoint by construction, so the
rewrite is value-preserving). Both tools consume that same normalized
artifact.

## SAW

`saw/run.sh` copies `src/cell.cry` / `src/cell.saw` into `build/` and verifies
both legs against the same independent Cryptol predicate: 2 `Proof
succeeded!` lines (C and L), no `Proof failed`; `saw/result.txt` ends in
`STATUS=saw-green`.

## Coverage notes

- SCR-061: ELSE toggle on depth 1 and 2; ELSE on depth 0 gives 20.
- SCR-062: ENDIF on depth 0 gives 20; ENDIF on depth 1 pops to 0.
- SCR-063: a skipped NOP (or ENDIF from depth 2) leaves depth 1 at loop exit,
  which is 20.
- SCR-064: ELSE with `fExec=0` still dispatches; NOP with `fExec=0` does not
  (`executed=0`).

## Limits

- One dispatch per proof; the cell cannot express a multi-opcode script.
- Condition-stack depth 0-2 only.
- IF/NOTIF push semantics live in `C-L-if-notif`; this cell does not re-prove
  them.
- No Core source patch is used.
