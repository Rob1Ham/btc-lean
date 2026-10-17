# L2-BOUND — exact-boundary differential lane

Class `bound` in the L2 differential
campaign. Bitcoin Core pins: **cce32b16** (block/consensus/validation,
copied under `spec/vectors/l2/act/refs/`) and **c50817fe** (script,
copied under `spec/vectors/l2/scr/refs/`). bitcoind **v31.1.0** regtest
was used as the tier-0 oracle for money/maturity/locktime.

## What is here

| File | Role |
|---|---|
| `gen_cases.py` | seeded generator; writes `cases.jsonl`, `seeds.json`, `got.json` |
| `bound_model.py` | the two independent encodings: `dut_*` = model definitions (DUT), `orc_*` = pinned Core rule (oracle) |
| `cases.jsonl` | 525 raw cases (id/const/param/value/ctx/want/oracle/evidence); no DUT verdict, so it is not self-judging |
| `got.json` | DUT outputs, joined by id (kept out of `*.jsonl` to avoid double discovery) |
| `run_diff.py` | applies the campaign verdict law, writes `results.l2r` + `summary.json`, exits 2 on an integrity mismatch |
| `results.l2r` | `id|got_ok|got_err|want_ok|want_err|verdict` (canonical form) |
| `summary.json` | per-constant tally and the divergence list |
| `README.md` | this file; the findings doc is `spec/db/findings-edge/L2-BOUND.md` |

## Constants covered (C01..C15)

C01 MAX_MONEY · C02 MAX_BLOCK_WEIGHT (4,000,000) · C03
MAX_BLOCK_SIGOPS_COST (80,000) + MAX_STANDARD_TX_SIGOPS_COST (16,000) ·
C04 COINBASE_MATURITY (100) · C05 LOCKTIME_THRESHOLD (500,000,000) ·
C06 retarget interval (2016 / 144) · C07 BIP34_HEIGHT (227,931) ·
C08 BIP30 (91,722/91,812/91,842/91,880, LIMIT 1,983,702) · C09
MAX_SCRIPT_SIZE (10,000) · C10 MAX_OPS_PER_SCRIPT (201; tapscript 1,000) ·
C11 MAX_SCRIPT_ELEMENT_SIZE (520) · C12 MAX_STACK_SIZE (1,000) +
policy P2WSH stack items (100) · C13 taproot control depth (128,
33+32·128 = 4,129) · C14 nMaxNumSize (4; 5 for CLTV/CSV) · C15
MAX_PUBKEYS_PER_MULTISIG (20).

Every value is exercised AT, ±1 and (where meaningful) ±2, in multiple
contexts (tx-level vs block-level, BASE vs WITNESS_V0 vs TAPSCRIPT,
height vs time locktime arm, canonical vs non-canonical chain pin, …),
so both accept-at and reject-at verdicts are present.

## Reproduction

```bash
cd <checkout>
python3 spec/vectors/l2/bound/gen_cases.py      # 525 cases, seed 2601
python3 spec/vectors/l2/bound/run_diff.py       # integrity-checked results
python3 spec/scripts/l2/l2_harness.py --class bound
```

Expected: `525` cases — **519 AGREE, 2 VERDICT-DIVERGE,
1 KIND-DIVERGE, 3 UNJUDGED, 0 UNRUN**, 0 integrity errors.

## Oracle tiers actually used

* **tier 0** — 8 rows are observations of bitcoind v31.1.0 regtest
  (`testmempoolaccept`): MAX_MONEY / MAX_MONEY+1, maturity delta 100 vs
  99 in two independent height contexts, and locktime 499,999,999
  (height arm → `non-final`) vs 500,000,000 (time arm → allowed).
* **tier 2** — 91 rows are Core `script_tests.json` rows whose expected
  error *is* the boundary. Their DUT verdict is the already-executed
  L2-SCR Lean runner row (`spec/vectors/l2/scr/results/tierC.l2r`); the
  contribution here is the exact-boundary selection, not a new run.
* **tier 1** — the remaining 426 chain-constant rows compare a mechanical
  transcription of the model definition (file/line cited per case)
  against the pinned Core rule (file/line cited per case). They are
  **model-level** rows: they can prove a wrong constant or off-by-one,
  but they do not execute the Lean interpreter. This is this tier's
  honest limitation and is recorded as GAP-1 in the findings.

## Verdicts

See `summary.json`. Two verdict divergences are the BIP30 hash-pin
(D2b) gap (tracked by the BIP30 workstream); one kind divergence is the
already-filed F-L2SCR-002; three unjudged rows are the unmodelled
*policy* P2WSH stack-item limit. No other constant is off by one at its
boundary.
