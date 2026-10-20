# control-flow/C-L-unspendable

## Status

`both-green` symbolically over the whole 32-bit size range and all first-byte
values. This is the whole predicate, not a bounded witness set.

## Design

`CScript::IsUnspendable` (`script.h:564-567`) reads exactly two facts: whether
the script is non-empty, its first byte, and its size. The cell takes
`(size, first)` as inputs, so no script array is needed and the proof covers
every size, including the 10000/10001 boundary, and every first byte,
including OP_RETURN (0x6a).

The C leg is the source predicate verbatim:

```
return (size() > 0 && *begin() == OP_RETURN) || (size() > MAX_SCRIPT_SIZE);
```

The L leg transcribes the Lean definition (`Ledger/Interface.lean:96-101`):
`(s.bytes.size > 0 && s.bytes.get! 0 == 0x6a) || s.bytes.size > 10000`. The
Lean `MAX_SCRIPT_SIZE` is defined as 10000 in that file; the leaf carries the
same literal and does not use `build/twin_ops.h`'s bounded `MAX_*` constants
(those are re-bound to the leaf domain and would be wrong here).

## Alive2

`alive2/run.sh` runs the single C/L pair: `Transformation seems to be correct!
(syntactically equal)`, `1 correct transformations`, `0 incorrect`, `0
failed-to-prove`, `0 Alive2 errors`; `alive2/result.txt` ends in
`STATUS=alive2-green`. The two leaves compile to identical IR because both are
the same Boolean expression over the same two inputs.

## SAW

`saw/run.sh` verifies both legs against the independent Cryptol predicate: 2
`Proof succeeded!` lines, no `Proof failed`; `saw/result.txt` ends in
`STATUS=saw-green`.

## Limits

- The predicate is pure; this cell says nothing about where it is called
  (`AddCoins`/UTXO admission is a separate ledger cell).
- The first byte is taken as an input rather than read through `CScript`; the
  postcondition holds for all values, so the abstraction is total.
- No Core source patch is used.
