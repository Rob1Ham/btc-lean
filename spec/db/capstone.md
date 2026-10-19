# Capstone replay: real mainnet anchor blocks

## Scope and method

This page records one offline replay of historical, serialized mainnet
blocks through the compiled Lean `replayBlockPartial` diagnostic adapter.
The input block data are the checksum-pinned anchor sets from the data
release (see `docs/DATA.md`). The replay does not contact a live network
and does not run or compare against `bitcoind`.

`replayBlockPartial` is a **diagnostic** adapter: it supplies the
serialized block, the release UTXO view, and the parent hash, but no
ancestor/clock context. It therefore reports `accepted=false` and
`isPartial=true` even when every available check agrees. `replayOk`
means the checks that could be run agreed; it is not an acceptance
claim. `scriptAdjudication=complete` with `scriptUnjudged=0` means the
runner produced a verdict for every input; otherwise the unjudged
inputs are reported and are not counted as validated.

**Blocks: 13 — replayOk 13, accepted 0, hash==canonical 13** · script-unjudged total 0 · fold cross-check OK · sum of per-block ms 9779.4s (blocks run concurrently).

**Limits.** This is an offline model replay of a finite historical
block set. It is not live-network validation, peer synchronization,
chain-tip following, or a claim of `bitcoind` equivalence. A
`replayOk` record is a run record, not a kernel theorem.

## Results

### Corpus 1 — historical anchor blocks

| height | replayOk | accepted | isPartial | reason | txs | inputs adjudicated | script unjudged | adjudication | fold agrees | ms | hash==canonical |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | True | False | True | partial-context | 1 | 0 | 0 | complete | True | 0 | True |
| 74638 | True | False | True | partial-context | 3 | 2 | 0 | complete | True | 130 | True |
| 91842 | True | False | True | partial-context | 1 | 0 | 0 | complete | True | 1 | True |
| 91880 | True | False | True | partial-context | 2 | 1 | 0 | complete | True | 68 | True |
| 481824 | True | False | True | partial-context | 1866 | 5192 | 0 | complete | True | 2795563 | True |
| 709632 | True | False | True | partial-context | 2043 | 6630 | 0 | complete | True | 3502804 | True |

### Corpus 2 — extended anchor blocks

| height | replayOk | accepted | isPartial | reason | txs | inputs adjudicated | script unjudged | adjudication | fold agrees | ms | hash==canonical |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 170 | True | False | True | partial-context | 2 | 1 | 0 | complete | True | 68 | True |
| 170060 | True | False | True | partial-context | 23 | 63 | 0 | complete | True | 4191 | True |
| 170061 | True | False | True | partial-context | 6 | 14 | 0 | complete | True | 910 | True |
| 481827 | True | False | True | partial-context | 1377 | 4855 | 0 | complete | True | 1652360 | True |
| 481828 | True | False | True | partial-context | 1 | 0 | 0 | complete | True | 2 | True |
| 499195 | True | False | True | partial-context | 3778 | 4592 | 0 | complete | True | 900220 | True |
| 709635 | True | False | True | partial-context | 945 | 2274 | 0 | complete | True | 923076 | True |
