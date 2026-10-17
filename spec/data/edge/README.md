# edge/ — EDGE-MUTANT boundary vectors (mutation-survivor killing corpus)

This is a locally generated boundary corpus, added 2026-10-17, **v3 =
post-TS04 (F-EM-006) repair** (620bbb6 → FIX-TS04 918df3c silently broke
the landed kill → 9d3fee8/b4758e5; detail
`spec/db/findings-edge/EDGE-MUTANT.md` F-EM-002/F-EM-006). It is NOT
vendored from bitcoin/bitcoin and NOT in the top-level MANIFEST.sha256
(which pins the vendored files under core/ + bips/); provenance = this
README + the generator
(`spec/scripts/runners/codegen.py: make_edge_vecs`).

## Files
- `tx_invalid_edge.json` — `te-000..te-003` (4 rows; v2's `te-004` vestige
  DROPPED — see F-EM-002). Explicit object schema:
  `id, version, expectValid, segwit, flags, policyFlags, comment, vin[],
  vout[] | voutRange{n,value,spk}, witness[][]` (hex strings for
  hash/scriptSig/spk/witness items). `voutRange` rows are emitted by codegen
  as replication-built `edgeTx_<id>` pre-defs + `(List.range n).map …` so
  the ~1 MB near-limit rows carry no literal (and never a list literal —
  elaboration/codegen blowup).
- `tx_valid_edge.json` — `ve-000/ve-001/ve-002`, the accept side of the
  same boundaries (ve-001 = non-empty-vin segwit-framed 001 companion;
  ve-002 = the 003 AT-bound companion).
- `pow/compact_target_edge.json` — `pe-000`, document-only FIND-W16-004 row.
  `compactTarget`/`targetOk` are NOT in any vectorrunner layer; the kill is
  the kernel pin in `spec/core/Test/Edge/Pins.lean` (`tests:` channel).

## Wiring
- `codegen.py` emits `spec/runners/BitcoinVectors/Gen/EdgeVectors.lean`
  (`txValidEdge`/`txInvalidEdge` + the `edgeTx_*` pre-defs) and maintains the
  te-/ve- ids in `vector_ids.yaml` (EDGE_RULES v3: te-000→001,
  te-001→003, te-002→005, te-003→006, ve-000→006, ve-001→001, ve-002→003).
  The rows are NOT in the `Compiled` curation tier.
- The edge module opens `BitcoinVectors Bitcoin.Data` (the `edgeTx_<id>`
  pre-defs are the only records with a bare `: Tx :=` ascription — v3 build
  fix, F-EM-006b).
- `BitcoinVectors.lean` (root) imports `Gen.EdgeVectors`.
- `VectorRunnerMain.lean` judges the rows in `txv_stateless` only
  (`txRs`); they are NOT in `txCtxRs`, `txFullRs`, or `serRs` (no raw wire
  bytes; the stateless predicate is what the survivors mutate).
- `mutate.py` therefore scores `te-000`/`te-001` on the judged pass-rate
  (a flipped stateless status is `killed-runner`; v3 run:
  2046→2045 each). `MUT-TXV-003` is ALSO killed by the `tests:` pin
  (`Pins.bigW6`, stripped 4_000_004 = some `.oversize`) and the fast-pack
  pin (`MutationPack.bigTx8` s=6) — the killed-pack channel whose baseline
  check was the F-EM-006 harness sys.exit. `te-002/003/ve-000` are
  boundary-corpus rows; `MUT-TXV-005`/`MUT-POW-001` are killed by the
  `tests:` pins (no judged layer can see their distinction).

## Semantics notes (v3 — post-TS04 `txStrippedWeightL` gate)
- te-000: 0-vin is wire-representable via the BIP144 marker path
  (`00 01 00 01 …`): Core `UnserializeTransaction` reads vin count 0 as the
  marker, flag 0x01, then the real vin count 0. `CheckTransaction` rejects
  `bad-txns-vin-empty` (FIND-W16-001's "unrepresentable" was non-segwit
  framing only).
- **te-001 v3 = the stripped-boundary kill**: 1 coinbase-shape input
  (null prevout, 6-BYTE scriptSig `51`×6), 99994 one-sat vouts → base
  1,000,001 → **`txStrippedWeightL` = 4·1,000,001 = 4,000,004 = the ONLY
  point in (4M, 4M+4] that kills the `> MAX_BLOCK_WEIGHT + 4` loosening**
  (stripped ≡ 0 mod 4 ⇒ only 4M+1..4M+4 are mutant-distinguishing, and
  4M+4 = the unique representable value). The stripped gate
  (FIX-TS04 918df3c, F-TS04-001) is witness/marker-BLIND = exactly Core's
  `GetTransactionWeight` for `!HasWitness()` ⇒ te-001 v3 is
  Core-model-agnostic (no witness/marker term, no F-EM-005 exposure).
- ve-002 = te-001's structure with the 5-byte scriptSig (s=5) = base
  1,000,000 = stripped EXACTLY 4,000,000 = the AT-bound accept side (faithful
  accepts, faithful-+4 accepts — pins that the kill is the bound, not the
  arithmetic). Replaces the 620bbb6-v1 `s=4`/"base 999,999 + witness"
  003-claim (F-EM-002 STALE-DISCREPANCY: 620bbb6's expected-strings said
  "4,000,001 Core-consistent HasWitness" while its committed corpus row was
  a 4,000,003 witness-LESS divergence row and its results file recorded no
  weight story — three mutually inconsistent artifacts). The v1
  witness-FUL Core-exact-companion design (v2 `te-004`) was correctly
  MOOTED by the stripped gate (witness-blind) and dropped.
- te-002/te-003/ve-000: MAX_MONEY boundary — per-output `MAX_MONEY+1`
  (te-002), cumulative `(MAX_MONEY, 1)` = MAX+1 (te-003), exact
  `(MAX_MONEY, 0)` accept (ve-000). The 005 mutant is
  error-constructor-only (see F-EM-003) ⇒ killed-test via `Pins`.
- REPORT, RESCOPED post-TS04 (F-EM-005): `txWeightL`/`serTxWithWitness`
  still always emit the marker/flag + per-input witness stack (a
  witness-less 63-B tx → model 255, Core 252), but the CONSENSUS GATE is
  now `txStrippedWeightL` (witness/marker-blind), so this is no longer a
  tx-acceptance divergence class: it is a BLOCK-layer weight-metric report
  (pinned by `Pins.bigW` :40). The v1 warning "do not add witness-less
  rows at base 1,000,000" is therefore RETIRED — te-001 v3/ve-002 are
  exactly such rows, and the stripped gate judges them like Core.
- `flags: "NONE"` decodes to all-false consensus flags.
