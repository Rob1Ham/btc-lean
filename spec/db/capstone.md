# Capstone replay: 13 mainnet anchor blocks

## Scope and method

This page records one offline replay of historical, serialized mainnet
blocks through the compiled Lean `validateBlock` pipeline. The input block
data are the checksum-pinned anchor sets from the data release (see
`docs/DATA.md`). The replay does not contact a live network and does not run
or compare against `bitcoind`.

For each block, the runner decodes the block, checks its structure, proof of
work and chain linkage, the merkle root and witness commitment, then runs the
per-transaction stateless and contextual checks with ECDSA signature
verification and an evolving UTXO-ledger fold keyed by txid. The table
reports:

- `inputs adjudicated` — transaction inputs for which the replay produced a
  script verdict;
- `taproot unjudged` — inputs in a taproot path that this replay did not
  adjudicate; they are not counted as validated;
- `fold agrees` — the ledger fold agrees with the block's spend/reward
  accounting;
- `hash==canonical` — the model-computed block hash equals the independently
  pinned canonical mainnet hash.

**Recorded result:** 13 of 13 blocks PASS, 13 of 13 hashes equal the
canonical hash, fold cross-check OK, 5551.6 s wall clock. Timings are
environment-dependent and are not a performance claim.

**Limits.** This is an offline model replay of a finite historical block
set. It is not live-network validation, peer synchronization, chain-tip
following, or a claim of `bitcoind` equivalence. A PASS is a run record, not
a kernel theorem.

## Results

### Anchor set 1

| height | verdict | reason | txs | inputs adjudicated | taproot unjudged | fold agrees | ms | hash==canonical |
|---|---|---|---|---|---|---|---|---|
| 0 | PASS | — | 1 | 0 | 0 | True | 0 | True |
| 74638 | PASS | — | 3 | 2 | 0 | True | 128 | True |
| 91842 | PASS | — | 1 | 0 | 0 | True | 0 | True |
| 91880 | PASS | — | 2 | 1 | 0 | True | 66 | True |
| 481824 | PASS | — | 1866 | 5192 | 0 | True | 1674421 | True |
| 709632 | PASS | — | 2043 | 6630 | 0 | True | 1953831 | True |

### Anchor set 2

| height | verdict | reason | txs | inputs adjudicated | taproot unjudged | fold agrees | ms | hash==canonical |
|---|---|---|---|---|---|---|---|---|
| 170 | PASS | — | 2 | 1 | 0 | True | 339 | True |
| 170060 | PASS | — | 23 | 63 | 0 | True | 14962 | True |
| 170061 | PASS | — | 6 | 14 | 0 | True | 3157 | True |
| 481827 | PASS | — | 1377 | 4855 | 0 | True | 3390156 | True |
| 481828 | PASS | — | 1 | 0 | 0 | True | 3 | True |
| 499195 | PASS | — | 3778 | 4592 | 0 | True | 1199597 | True |
| 709635 | PASS | — | 945 | 2253 | 21 | True | 943347 | True |
