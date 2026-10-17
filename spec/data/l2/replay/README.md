# L2-REPLAY — real mainnet historical chain-data replay (class=replay)

This is the real-chain replay corpus for the L2 differential campaign.
**Oracle = Bitcoin Core
acceptance**: every real mainnet block/tx in this repo was accepted by Core
(they are all in the best chain) — our Lean validation backends MUST accept
them too. Any divergence = **OUR-BUG (critical)**.

## Corpus (RBOOK.json, frozen @ repo 702bfb30)

EVERY real serialized mainnet block in-repo: 67 blocks
(`spec/vectors/{anchors, anchors2, anchors2/V01..V16, anchors3/V2-02,
anchors4/V3-02}`) + 125,805 seed lines (each a real mainnet prevout tx) +
`spec/vectors/cve/` (3). Special cases: BIP30 exception blocks 91842/91880;
SCR-016 flag-exception blocks 170060 (BIP16-exception, in-corpus) and
692261 (taproot-exception, hash in Core chainparams/refs; no raw in-repo).

## Backend (L2R-BACKEND-STATE)

The capstone pipeline via the V12Run import surface
(`Bitcoin.Serialization.Interface` W02 decode → `Bitcoin.Consensus.TxCheck`
W10 stateless → `Bitcoin.TxValidation.Interface` W09/W11/W13×W14b real
ECDSA → `Bitcoin.Capstone.{Block,Merkle,RealChecker}` → `Bitcoin.Ledger`
W12 fold → `validateBlock` monolithic), elaborated @ mirror scratch copy
of spec/core (closure = the 41-module capstone link set; shared .lake
untouched; lake-free F-V10-004 leanc route). RBOOK pins every artifact
sha256; refs/ pins Core chainparams @ cce32b16 + c50817fe.

## Runner (run/L2Replay.lean)

V12Run.lean verbatim-clone (V12Run is the capstone-runner snapshot) +
L2R lanes; modes (`L2R_MODE`):
- `block` — V12Run blockLane verbatim (validateBlock full depth, real
  ECDSA). Line `L2RBF`.
- `stateless` — L2R: decodeBlock + headerHash == .hash pin (REAL sha256d)
  + parent-link == .parent pin + `merkleOk` (real merkle root) +
  per-tx `checkTransaction` (W10). Line `L2RBS`.
- `seeds` — L2R: per seed line (real prevout tx): `decodeTx` +
  `checkTransaction` + (`L2R_SHA=1`, default) `txidOf tx ==` line txid =
  **Lean real sha256d(serTx) vs the python fetch-time sha256d = a
  cross-implementation differential on every replayed tx**. Line
  `L2RSTX`; failure rows (rare) to TSV `L2R_OUT`.

Env: `L2R_VECTORS` = the corpus dir (e.g. .../spec/vectors/anchors2/V13),
`L2R_ID` = RBOOK id, `L2R_H` = height, `L2R_OUT` = failure TSV.

## Cases + verdicts (results/)

- `results/l2r-bs.jsonl` — 67 `R-BS` block-stateless cases
- `results/l2r-stx.jsonl` — 66 `R-STX` per-seed-file cases = 125,805
  per-line replays (failure rows in `results/seeds/*.tsv` when any)
- `results/l2r-bf.jsonl` — `R-BF` blockFull cases (specials + deep)
- `results/l2r-cve.jsonl` — 3 `R-CVE` cases (cve_replay @ HEAD)
- `results/l2r-specials.md` — SCR-016 flags/exception-block specials

Verdicts: `AGREEMENT` (backend accepted + all pins matched) /
`OUR-BUG` (false reject or pin mismatch; critical; filed precisely in
spec/db/findings-edge/L2-REPLAY.md, never silently fixed) /
`ORACLE-ARTIFACT` (data-side: e.g. 400000/526000 TRIMMED-1000 seeds
(CLEANUP) make full-depth impossible = documented depth artifact).
Findings: spec/db/findings-edge/L2-REPLAY.md. Campaign status notes are
kept outside this data subset.

## Campaign result

`run/l2replay_campaign.py` drives the compiled runner over the R-book and
writes `results/{stateless_blocks,seeds_files,seeds_lines,full_blocks,flags}.jsonl`
in the campaign-canonical row form. Verified by
`spec/scripts/l2/l2_harness.py --class replay`:

- **785 cases / 784 AGREE / 1 VERDICT-DIVERGE / 0 UNJUDGED / 0 UNRUN**
- 67/67 stateless blocks; 125,805/125,805 seed txs (0 decode/stateless/txid
  failures); 576 deterministic per-line samples (`sampleSeed` recorded);
  13 full-depth blocks; 5 SCR-016 flags cases.
- The single divergence is **F-V12-006** (`470000`, `unexpected-witness`),
  pre-existing and owned outside this directory (see
  `spec/db/findings-edge/L2-REPLAY.md` §4).
- Three corpus `.hash` pins absent upstream (481827/163305/180000) were
  recovered from blockstream API and recorded in RBOOK.json
  (`pinRecovered`); `cases/blkpin/` holds symlinked raws + the pins so the
  runner can hash-check without writing into the source `vectors/` tree.
