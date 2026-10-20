# limits/C-L-w32-sigop-cost — notes

## Composition boundary

The row is the aggregation, not the counters.  The cell takes:

- `legacy` — GetLegacySigOpCount(tx) (scriptSig and scriptPubKey static
  counts, ×4 here);
- `p2sh` — GetP2SHSigOpCount(tx, inputs) (×4 here, under the P2SH flag);
- `witness` — the sum of CountWitnessSigOps over the inputs (×1 here).

Those three counts are proved by `C-L-w32-p2sh-scriptsig`,
`C-L-w32-witness-sigops`, and the legacy-counter cells respectively.  This
cell proves the weight-unit scaling and the two gates, which is exactly what
SCR-037 names.  It does not re-prove the counts.

## Gates

- `coinbase != 0` returns `4 * legacy` immediately (tx_verify.cpp:153-155).
  Both the P2SH and witness terms are skipped, matching the early return.
- `p2sh_flag != 0` adds the P2SH component (tx_verify.cpp:157-159).  The
  witness term is added in both cases; its own WITNESS gate lives in
  CountWitnessSigOps and is already folded into the `witness` input.

## Arithmetic

`legacy`, `p2sh`, `witness` are 32-bit; the largest cost is
`4 * (2*(2^32-1)) + (2^32-1) = 38,654,705,655 < 2^36`, so the int64_t return
is exact and no overflow guard is needed.  The C leg multiplies each term and
adds; the L leg uses the Lean factored form `4 * (legacy + p2sh) + witness`, so
the proof also checks the distributivity step.

## Mutation sanity check

Mutating the L leg's `LEGACY_SIGOP_SCALE` from 4 to 5 makes Alive2 report a
counterexample ("Source value: #x0000000000000004 (4) / Target value:
#x0000000000000005 (5)").  The green result is not vacuous.

## Spot evaluations

| legacy | p2sh | witness | coinbase | p2sh_flag | cost |
|---|---|---|---|---|---|
| 0 | 0 | 0 | 0 | 0 | 0 |
| 1 | 2 | 3 | 0 | 1 | 15 |
| 1 | 2 | 3 | 0 | 0 | 7 |
| 1 | 2 | 3 | 1 | 1 | 4 (coinbase early return) |
| 2^32-1 | 2^32-1 | 2^32-1 | 0 | 1 | 38,654,705,655 |
