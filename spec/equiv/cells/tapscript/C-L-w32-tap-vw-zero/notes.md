# tapscript/C-L-w32-tap-vw-zero

## Scope

The cell covers SCR-168 as a symbolic predicate: `vw` ranges over the whole
reachable budget domain `[0, 4000050]` derived from
`interpreter.cpp:1991` (`GetSerializeSize(witness.stack) + 50`, witness
stack bounded by MAX_BLOCK_WEIGHT). Outside that domain the function returns
the fixed marker `0xdeadbeef`; the guard is harness, because Core has no
such branch (its caller contract supplies the initialised budget).

The exactly-zero instance is `vw = 50`, which is inside the quantified
domain; the cell additionally exercises the `0 / -1` boundary (`vw = 49`,
`vw = 50`). The mutant named in `spec.md` (flip `<` to `<=`) is rejected by
both tools.

## What is not modelled

- Signature/pubkey bytes and BIP340 verification: same-crypto premise, the
  verdict is a free boolean.
- `ExecuteWitnessScript`'s initialisation itself, the witness stack
  serialization, and the outer script loop. The initial budget is an input.
- Policy flags other than `DISCOURAGE_UPGRADABLE_PUBKEYTYPE`; flags = 0.
