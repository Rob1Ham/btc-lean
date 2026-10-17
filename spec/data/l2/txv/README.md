# L2-TXV — differential transaction-validation campaign (class `txv`)

Seeded, reproducible differential run of the shipped Lean transaction
validation definitions against Bitcoin Core @ `cce32b16` (block/
consensus) and `c50817fe` (script lane).  One case = one `(ok, err)`
pair; verdict law is the campaign-wide one from
`spec/scripts/l2/l2_harness.py`:

```
no DUT verdict   -> UNJUDGED
got_ok != want_ok -> VERDICT-DIVERGE
got_err != want_err -> KIND-DIVERGE
otherwise        -> AGREE
```

Per-case campaign classification (`results/verdicts.json`):
`AGREEMENT` / `OUR-BUG` / `ORACLE-ARTIFACT`.

## Run

```bash
cd spec/vectors/l2/txv
python3 gen_cases.py          # writes cases/*.jsonl + cases/manifest.json
python3 run_l2txv.py          # writes results/l2txv.l2r + summary.json + verdicts.json
cd ../../.. && python3 spec/scripts/l2/l2_harness.py --class txv
```

Seeds: `struct 20261017`, `locktime 20261018`, `sigops 20261019`,
`inputs 20261020`.  The Core-corpus family is deterministic (vector
order).  No wall clock, no urandom.

Expected results: **1199 cases, 1183 AGREE, 16 divergences
(8 OUR-BUG + 8 ORACLE-ARTIFACT), 0 UNJUDGED, 0 integrity errors**;
oracle anchor 122/122 `tx_valid.json` entries accepted by the oracle.

## Layout

| Path | Meaning |
|---|---|
| `model.py` | DUT = byte-faithful Lean mirror (file:line cited per def); oracle = Core port |
| `gen_cases.py` | seeded generator (4 families + Core corpus) |
| `run_l2txv.py` | executes both sides, emits `.l2r`, summary, per-case classes |
| `cases/*.jsonl` | case corpus (tx abstract form; scripts hex or `{"size":N}` zero-fill) |
| `results/l2txv.l2r` | canonical result lines consumed by the harness |
| `results/summary.json` | counts, seeds, oracle anchor, sigops counter census, divergence detail |
| `results/verdicts.json` | every case with its campaign classification + rationale |
| `probe/` | read-only Lean `#eval` probe of the shipped sigops/weight defs |
| `refs/README.md` | pinned Core sources + sha256 |

DUT sources (all read-only; no core edits):
`Consensus/TxCheck.lean:69,85` (weight, `checkTransaction`),
`TxValidation/Interface.lean:172,233,271,277,285,528` (`coinMatured`,
`checkTxInputs`, BIP68 fold, `validateTx`),
`DataLaws/Interface.lean:268` (`isFinalTx`),
`Block/Sigops.lean:168,174,219,246,264,281,333` (legacy/P2SH/witness
counters, `txSigOpCost`),
`TxValidation/SigOpsCost.lean:101,147` (the *accurate* X05 counters, used
as a cross-check on the tree's two models).

## Families

| family | cases | what it exercises |
|---|---:|---|
| `struct` | 127 | vin/vout emptiness, negative/over-MAX values, MAX_MONEY accumulation, duplicate prevouts, coinbase scriptSig 2..100, null prevouts, compactSize boundaries, oversize/weight model, 60 seeded random txs |
| `locktime` | 637 | `IsFinalTx` height/time domain split (BIP113), all-final/mixed/empty vin, BIP68 disable/type/mask/version matrix incl. wire `0xffffffff`, height & 512s time boundaries, two-input max, 70 seeded random |
| `sigops` | 116 | legacy `GetSigOpCount(false)` opcode/push-skip, P2SH redeem counting (accurate vs legacy, push-only gate), bare/P2SH-wrapped witness counting, v1+/20/32 programs, ×4/×1 cost, 80,000 gate flips, 45 seeded random |
| `inputs` | 104 | prevout resolution, coinbase maturity depth 99/100/101, coin value ranges/accumulation, in<out, fee boundaries, duplicate-input double count, empty vin |
| `corpus` | 215 | every decodable `tx_valid.json` (122) + `tx_invalid.json` (93) transaction through `CheckTransaction` |

`tx_invalid` is a script-execution corpus: only 9/93 are structurally
invalid, so the family judges DUT-vs-oracle, not corpus-label-vs-oracle
(the labels are recorded in each case).

## Results

`AGREEMENT 1183 / 1199` (98.7 %).  Zero divergence in the 637-case
locktime family and the 215-case Core corpus.  Divergences are three
OUR-BUG classes in the shipped definitions plus one documented
domain artifact — see `spec/db/findings-edge/L2-TXV.md` for the exact
file:line, evidence, and fix direction.
