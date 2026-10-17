# spec/data/l2/blk — block/header validity differential corpus (CLASS=blk)

This directory contains the block/header validity corpus for the L2
differential campaign. Sibling directories (act/ bound/ fuzz/ fuzz2/ inv/
replay/ scr/ sgn/ swt/ tpr/ txv/) contain the other corpus classes and are
outside this directory's scope.

Campaign result: **707 seeded cases, 575 AGREE / 132 DIVERGE / 0
UNJUDGED / 0 integrity**, seed `20261017`. Findings:
`spec/db/findings-edge/L2-BLK.md`.

## Scope (case classes)

80-byte header shape, SHA256d header hash, nBits decode (SetCompact) +
powLimit bounds + high-hash, retarget windows (144/2016, clamp T/4..4T,
BIP94 first-of-period base, min-diff walk-back), merkle root incl. the
CVE-2012-2459 mutation space (duplicate-last, interior duplication at
every level), coinbase-first + BIP34 height commitment (minimal
CScriptNum push), witness commitment (LAST matching output, nonce shape,
wmr binding), subsidy/halving boundaries (mainnet 210000 + regtest 150),
BIP94 timewarp, MTP / future-time.

## Oracle stack

1. **bitcoind v31.1.0 regtest** (binary from a local Core build tree
   outside the repository; a private datadir is used): tier-0
   accept/reject + reject reason for every context/structure/witness/
   pipeline case. The datadir is `<workdir>/l2blk/regtest`, RPC port
   **39412**. The node is started with `-rpcbind=0.0.0.0` (loopback binds fail in
   this sandbox) and `setmocktime=1792200000` so block times are a
   deterministic grid, not wall-clock. Two full runs produce identical
   per-case verdict rows.
   Known artifact: `submitblock` calls
   `UpdateUncommittedBlockStructures` and injects a 32-zero coinbase
   witness nonce, so `commitment_without_nonce` is accepted by the node
   although Core's validation path rejects it; those rows take `want`
   from the pinned source and are labelled `ORACLE-ARTIFACT`.
2. **Pinned Core source `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`**
   transcribed in `harness/l2blk_oracle.py`: `SetCompact`/`DeriveTarget`,
   `GetNextWorkRequired`/`CalculateNextWorkRequired`, `ComputeMerkleRoot`
   with the `mutated` flag, `GetBlockSubsidy`,
   `GetMedianTimePast`, BIP94 timewarp, `CheckWitnessMalleation`.
   Source cache + `FETCHED.txt` are kept in a scratch directory outside
   the repository.
3. **Pinned anchors**: mainnet genesis header/hash/merkle,
   `pow_tests.cpp` nBits expectations, `merkle_tests.cpp` mutation
   vectors (CVE-2012-2459).

### DUT and anti-drift

`harness/l2blk_mirror.py` is a line-by-line port of the shipped Lean
defs (`Bitcoin.Capstone.{Block,Merkle,Pow}`, `Bitcoin.Block.Pow`,
`Bitcoin.Chain.compactTarget`, `Bitcoin.Conservation.blockSubsidy`), with
bugs preserved. `harness/L2BlkProbe.lean` + `harness/l2blk_probe.py` run
a **direct-Lean** tier (`lake env lean --run`, timeout 240) over the real
definitions and cross-check the mirror: 16/16 checks, 0 drift
(`results/blk_probe.txt`). Every finding in the findings file is backed
by both the mirror cases and the direct-Lean probe.

## Layout (this dir)

- `cases/` — per-family case detail, `blk_<family>.ndjson`
  (one seeded case per row; each row has `campaign_verdict` =
  `OUR-BUG`/`ORACLE-ARTIFACT`/`AGREEMENT`, `finding`, `reason_drift`).
  Deliberately **not** `.jsonl`: the canonical harness discovers
  `*.jsonl` as result/corpus artefacts.
- `results/` — canonical `blk_<family>.l2r` rows
  (`id|got_ok|got_err|want_ok|want_err|verdict`) + `blk_probe.txt`.
- `harness/` — `l2blk_gen.py` (seeded generator + node driver),
  `l2blk_oracle.py` (tier 1), `l2blk_mirror.py` (DUT port),
  `l2blk_probe.py` + `L2BlkProbe.lean` (direct-Lean tier).
- `refs/` — reserved for oracle evidence pins.

## Reproduce

```sh
cd spec/vectors/l2/blk/harness
python3 l2blk_gen.py --family all          # 707 cases, seed 20261017
python3 l2blk_probe.py                     # direct-Lean, 16/16
cd <checkout>
python3 spec/scripts/l2/l2_harness.py --class blk   # exit 0
```

Family seeds: `20261017 + k` with k = 1..11 in the order
header, nbits, retarget, merkle, subsidy, bip34, time, structure,
witness, pipeline, context. `--family <name> --limit N` for smoke runs;
`--no-node` skips the four node-backed families.

## Verdicts

`AGREE` / `DIVERGE` per the canonical harness law. Findings are
classified `OUR-BUG` (reported, never silently fixed — see
`spec/db/findings-edge/L2-BLK.md`), `ORACLE-ARTIFACT` (documented node
convenience), or `AGREEMENT` (same accept/reject; `reason_drift` marks
the 15 rows where only the reject string differs). No `spec/core/**`
definition was modified.
