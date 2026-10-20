# control-flow/C-L-opcount

## Status

`both-green` symbolically over all 256 wire opcodes, all sigversion inputs,
and a symbolic starting counter. This is a single-step cell.

## Design

The C leg is the budget block from `interpreter.cpp:459-463`:

```
if (sigversion == BASE || sigversion == WITNESS_V0) {
    if (opcode > OP_16 && ++nOpCount > MAX_OPS_PER_SCRIPT)
        return OP_COUNT;
}
```

with `OP_16 = 0x60` and `MAX_OPS_PER_SCRIPT = 201`. The L leg transcribes the
Lean step (`Defs.lean:824-829`): `counts := (sv = base ∨ sv = witnessV0) ∧
0x60 < w`, then `opCount' := if counts then opCount + 1 else opCount`, then
`if counts ∧ MAX_OPS_PER_SCRIPT < opCount' then .error .opCount`. Both return
the packed `(result, error, counter)`.

The wire is an 8-bit input, matching Core's `opcodetype`, so SAW proves the
statement for every opcode. SAW records the exact value; the IF instance is
`w = 0x63`.

## Alive2

`alive2/run.sh` runs the single C/L pair: `Transformation seems to be
correct!`, `1 correct transformations`, `0 incorrect`, `0 failed-to-prove`,
`0 Alive2 errors`; `alive2/result.txt` ends in `STATUS=alive2-green`.

`src/build.sh` drops the ` or disjoint ` poison flag from the extracted `.ll`
before reassembly; the packed fields are bit-disjoint by construction, so the
rewrite is value-preserving, and both tools consume the same artifact.

## SAW

`saw/run.sh` verifies both legs against the independent Cryptol predicate: 2
`Proof succeeded!` lines, no `Proof failed`; `saw/result.txt` ends in
`STATUS=saw-green`.

## Limits

- The counter is an input: the cell proves the per-opcode step, including the
  201/202 boundary, not an accumulation over a script.
- The 32-bit counter wraps at 2^32; that value is unreachable from Core (the
  counter starts at 0 and errors at 202), and both legs use the same unsigned
  arithmetic.
- No Core source patch is used.
