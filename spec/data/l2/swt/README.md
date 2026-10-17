# L2-SWT — differential SegWit lane

This directory contains the L2-SWT corpus.
Core pins: script lane **c50817fe** (`refs/*.c50817fe`), consensus lane
**cce32b16** (`refs/consensus_validation.h.cce32b16`). No shared Lean
definition was edited; findings are filed in
`spec/db/findings-edge/L2-SWT.md`.

Scope: differential-test the frozen DUT's segwit surface —
witness-program recognition, `VerifyScript` witness dispatch, weight /
serialization (BIP141/144), and BIP143 digests — against an independent
mirror of Core plus a bitcoind tier-0 calibration. Every case carries one
verdict: `AGREE` / `KIND-DIVERGE` / `VERDICT-DIVERGE` / `UNJUDGED`.

## Artefacts

| File | Purpose |
|---|---|
| `refs/` | Pinned Core sources: `interpreter.cpp`, `script.cpp`, `script.h`, `script_error.h`, `transaction.h` @c50817fe; `consensus_validation.h` @cce32b16. |
| `oracle/verify_swt.py` | Independent Python mirror (written from Core, not from the Lean bodies): `IsWitnessProgram`, `VerifyScript`, `VerifyWitnessProgram`, witness `EvalScript` subset, NULLDUMMY/CHECKMULTISIG, BIP144 sizes, BIP143 digest. Self-tested against the 6 published BIP143 sigHash vectors. |
| `gen_cases.py` | Seeded deterministic generator (`SEED=20261017`; family seeds `+1..+5`). `--check` runs the BIP143 self-test. |
| `cases/swt_cases.l2c` | 550 runner cases (`id\|mode\|want_ok\|want_err\|ss\|spk\|wit\|flags\|pol\|extra`). |
| `cases/swt_cases.jsonl` | Seed header + per-case family/intent/want metadata. |
| `lean/L2SwtRunner.lean` | Lean DUT runner over `Bitcoin.Interpreter.Defs`, `Activation`, `DataLaws`, `TxCheck`, `Serialization`, `SigHash.Digest`. `stubChecker` is held constant on both sides. Fuel 2,000,000. |
| `results/swt.l2r` | 550 verdict rows, canonical `id\|got_ok\|got_err\|want_ok\|want_err\|verdict` form. |
| `oracle/tier0_weight.py` | Starts an isolated `bitcoind` v31.1.0 regtest, funds an anyone-can-spend output and a P2WSH(OP_TRUE) output, spends each, and pins Core's `getrawtransaction` `weight`/`size`. |
| `oracle/tier0_weight.json` | Tier-0 evidence: bitcoind subversion, raw txs, Core weights. |
| `oracle/replay_tier0.py` | Emits `cases/tier0_cases.l2c` from that JSON and `--check`s `results/tier0.l2r` (exit 1 is expected while F-L2SWT-001 is open). |
| `results/tier0.l2r` | 2 replayed raw txs (legacy no-witness; P2WSH spend). |

## Case families (550)

| family | what | cases | verdicts |
|---|---|---:|---|
| `wp` | `IsWitnessProgram` recognition: versions 0/1/2/16, program lengths 0–41, size/malformed-opcode/declared-length and P2A boundaries | 190 | 190 AGREE |
| `vs` | `VerifyScript` structural: bare/P2SH-wrapped v0, P2WPKH, non-20/32 v0 lengths, v1 taproot key/script path, v2–v16, unexpected witness, WITNESS-off, NULLDUMMY, seeded combinations | 182 | 179 AGREE, 3 UNJUDGED |
| `w` | BIP141/144 weight: exact 4,000,000 boundary, no-witness vs witness, CompactSize edges, output-spk axis, multi-input | 76 | 48 AGREE, 27 KIND-DIVERGE, 1 VERDICT-DIVERGE |
| `b` | BIP143 digest: 6 published vectors plus seeded tx/scriptCode/hashType/amount variants | 88 | 88 AGREE |
| `sep` | BIP143 digest ≠ legacy digest (`got_ok = bip != legacy`) | 14 | 14 AGREE |

Totals: **519 AGREE, 27 KIND-DIVERGE, 1 VERDICT-DIVERGE, 3 UNJUDGED**
(519/547 judged agree). All 28 divergences are one filed OUR-BUG,
**F-L2SWT-001** (no-witness marker/flag overcount); see the findings doc.

## Tier-0 calibration

Core v31.1.0 regtest reports, on two raw txs:

| case | Core size/weight | DUT | verdict |
|---|---|---|---|
| legacy `OP_TRUE` spend (no witness) | 71 / 284 | `t=74`, `w=287` | KIND-DIVERGE |
| P2WSH(`OP_TRUE`) spend | 76 / 289 | `t=76`, `w=289` | AGREE |

The legacy delta is exactly `2 + nIn = 3` bytes of weight, confirming the
bug outside the mirror/oracle stack.

## Reproduce

```bash
cd spec/vectors/l2/swt
python3 gen_cases.py --check          # BIP143: 6/6 vectors
python3 gen_cases.py                  # byte-identical swt_cases.{l2c,jsonl}

cd <checkout>/spec
lake env lean --run vectors/l2/swt/lean/L2SwtRunner.lean \
  cases vectors/l2/swt/cases/swt_cases.l2c vectors/l2/swt/results/swt.l2r
python3 scripts/l2/l2_harness.py --class swt
```

Optional tier-0 (needs bitcoind 31.1; isolated datadir, `-listen=0`,
RPC 28557):

```bash
cd spec/vectors/l2/swt
BITCOIND_BIN=/path/to/bitcoin-31.1/bin python3 oracle/tier0_weight.py
python3 oracle/replay_tier0.py
cd <checkout>/spec
lake env lean --run vectors/l2/swt/lean/L2SwtRunner.lean \
  cases vectors/l2/swt/cases/tier0_cases.l2c vectors/l2/swt/results/tier0.l2r
python3 vectors/l2/swt/oracle/replay_tier0.py --check
```

Runner modes: `wp` (recognition), `vs` (`verifyScriptFull`), `w`
(synthesized weight), `wr` (raw-tx weight replay), `b` (BIP143 digest),
`sep` (BIP143 vs legacy separation). `ss`/`spk`/`wit` are hex; witness
items are `;`-separated per input and `_`-separated per item, with `e` for
an empty stack; extra fields use `:`.

## Verdict law

Verbatim from `spec/scripts/l2/l2_harness.py`: no DUT verdict → `UNJUDGED`;
accept/reject differs → `VERDICT-DIVERGE`; accept/reject agrees but Core's
`SCRIPT_ERR_*`/check-transaction kind differs → `KIND-DIVERGE`; otherwise
`AGREE`. The harness recomputes every row (no trusted tallies) and reports
`VERIFIED+OPEN` while F-L2SWT-001 is unfixed.
