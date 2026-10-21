# control-flow/C-L-verify

## Status

`both-green` for the symbolic bounded element domain (length 0-2, every byte
value) and symbolic stack depth.

## Design

The C leg is the `case OP_VERIFY` body (`interpreter.cpp:663-675`) with
`CastToBool` (`interpreter.cpp:46-59`) inlined at a compile-time-fixed element
length, one exported function per length in {0,1,2}. The L leg transcribes the
Lean model (`Defs.lean:901-904`) and uses the generated bounded
`cast_to_bool` plus `core_ord` (`TWIN_INVALID_STACK_OPERATION -> 18`,
`TWIN_VERIFY -> 11`).

The observable is `result(2) | error(6) | depth(8)`. The post-op depth
distinguishes pop from no-pop, which is the row's core claim; the error code
distinguishes VERIFY from the empty-stack error.

## Alive2

`alive2/run.sh` runs three C/L pairs (length 0, 1, 2): each reports
`Transformation seems to be correct!` with `1 correct transformations`,
`0 incorrect`, `0 failed-to-prove`, `0 Alive2 errors`; `alive2/result.txt`
ends in `STATUS=alive2-green`.

`src/build.sh` drops the ` or disjoint ` poison flag from the extracted `.ll`
before reassembly. SAW 1.6 leaves that flag unconstrained in the returned
term; the packed fields are bit-disjoint by construction, so the rewrite is
value-preserving, and both tools consume the same normalized artifact.

## SAW

`saw/run.sh` copies `src/cell.cry` / `src/cell.saw` into `build/` and verifies
both legs against the same independent Cryptol predicate: 6 `Proof succeeded!`
lines (3 lengths x C and L), no `Proof failed`; `saw/result.txt` ends in
`STATUS=saw-green`.

## Limits

- Element length 0-2 (the twin bounded element domain); lengths >= 3 are not
  machine-enumerated.
- The opcode is modelled as dispatched; the `fExec` gate for non-conditional
  opcodes is proved in `C-L-conditional-stack`.
- No Core source patch is used.
