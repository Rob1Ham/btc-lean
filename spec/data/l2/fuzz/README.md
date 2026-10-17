# L2-FUZZ — seeded differential fuzz campaign

This directory contains the class `fuzz` corpus. Findings:
`spec/db/findings-edge/L2-FUZZ.md`; campaign status notes are kept outside
this data subset.

Class: `fuzz`. 1,337 seeded cases (1,007 transaction + 180 header + 150
block), every case reproducible from the recorded seed. Oracle: an
independent Python port of the pinned Core code `mirror_fuzz.py`, with a
bitcoind v31.1.0 regtest parse cross-check. DUT: the Lean decoders
(`decodeTx` / `decodeBlockHeader` / `decodeBlock`), `checkTransaction`,
`powOk`, `merkleOk`.

## Files

| Path | Role |
|---|---|
| `gen_fuzz.py` | deterministic generator; master seed `20261017` |
| `cases/fuzz_cases.jsonl` | 1,337 cases (`id,kind,seed,family,mutation,hex,note`) |
| `mirror_fuzz.py` | independent Core-source mirror (parse + CheckTransaction + merkle + PoW) |
| `lean/FuzzMain.lean` | Lean DUT runner (compiled evaluation, no theorems) |
| `judge_fuzz.py` | runs Lean, computes wants, optional bitcoind cross-check, writes results |
| `results/fuzz.l2r` | canonical 6-field result rows for `spec/scripts/l2/l2_harness.py` |
| `results/detail.json` | per-case audit trail (got/want/Core probe/class/known ref) |
| `results/summary.json` | campaign tally |

## Case families

Transaction: `valid` 120, `bitflip` 262, `truncate` 180,
`count-overflow` 160, `opcode-stream` 120, `witness` 140, `boundary` 25.
Header/block: `hdr-valid` 40, `hdr-bitflip` 100, `hdr-trunc` 40,
`blk-valid` 40, `blk-mut` 80, `blk-count` 30.

Mutations cover bit flips in version/counts/values/locktime/marker, field
truncation at and between field boundaries, CompactSize 0xfd/0xfe/0xff
overflow + non-minimal encodings, random opcode/push streams, random
witness structures (superfluous, count mismatch, item-length overflow,
flag bytes 0/1/2/3/0xff), money/coinbase/duplicate/null-prevout boundaries,
and the 4M-weight edge (base size 999,999 / 1,000,000 / 1,000,001, with and
without witness).

## Verdict contract

Per case: `AGREEMENT`, `OUR-BUG`, or `ORACLE-ARTIFACT`.
Parse-layer rejection is judged as acceptance only (Lean `SerError`
taxonomy is not compared); structural rejection compares Core's exact
`bad-*` reason.

Result: **1,295 AGREEMENT / 3 OUR-BUG / 39 ORACLE-ARTIFACT**; canonical
harness sees **1,334 AGREE / 3 VERDICT-DIVERGE / 0 UNJUDGED** (all three are
the known `F-TS04-001` oversize branch; not fixed here).

## Reproduce

```bash
python3 spec/vectors/l2/fuzz/gen_fuzz.py                 # 1,337 cases (deterministic)
python3 spec/vectors/l2/fuzz/mirror_fuzz.py              # mirror self-test
# optional Core oracle (own datadir, regtest, port 28577, listen=0):
#   bitcoind -regtest -datadir=<workdir>/btcdat \
#     -rpcuser=fz -rpcpassword=fz -rpcport=28577 -listen=0 -daemon
python3 spec/vectors/l2/fuzz/judge_fuzz.py                # Lean + mirror + Core
python3 spec/scripts/l2/l2_harness.py --class fuzz
```

`judge_fuzz.py` runs `lake env lean --run lean/FuzzMain.lean` from
`spec/runners/` (the existing `bvectors` package; no build). It never edits
shared Lean files.

## Scope notes

- PoW true-branch is cryptographically unreachable at the mainnet target
  within budget; PoW agreement is audited as a separate assertion (0
  mismatches over all parsed headers/blocks), and block verdicts judge
  decode + merkle root.
- `decodeBlock`/`decodeBlockHeader` reject trailing bytes by contract;
  Core's `DecodeHexBlk` RPC path ignores them (39 flagged artifacts, Lean
  and mirror agree with each other).
- `F-TXVA-001` (0xfe count > MAX_SIZE accepted by `decCS`, rejected by
  Core `ReadCompactSize`) is rediscovered label-only: both sides reject
  end-to-end, so it is verdict-neutral.
