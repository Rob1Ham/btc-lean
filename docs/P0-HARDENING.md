# P0 consensus hardening (2026-10-19)

This is a re-audit of the live P0 findings against `main` at `37d1568`, after
the issue #16 (`#21`) and issue #22 merges. The old audit base was `80bf09b`;
several findings from that base were already fixed or changed by the merges
and are not re-applied here.

## Fixed in this batch

1. **CompactSize `0xfe` range check (TXV-012).** `Bitcoin.Serialization.decCS`
   now rejects a canonical but over-range `0xfe` value with
   `compactSizeTooLong`, matching Core `ReadCompactSize` (`serialize.h`:
   non-canonical check first, then `MAX_SIZE`). The proof corpus's
   `F-Y01-005` divergence is retired, and the witness-stack decoder test now
   expects the range error rather than a later truncation.

2. **Strict contextual script adjudication.** `replayBlockPartial` keeps the
   diagnostic `scriptUnjudged` report for partial anchor replay and reports
   `fullValidation = false`; it is not an acceptance predicate. The
   contextual entry (`validateBlockInContext`) rejects any run with an
   unadjudicated input as `script-unjudged`; it cannot return `ok` while an
   input's signature data was unavailable. The single next-block entry point
   `validateNextBlock` derives its header/clock context from a `ChainState`
   holding the checked parent hash, UTXO view, header index, and node clock.
   The report's `scriptAdjudication` remains complete exactly when the
   unjudged count is zero.

3. **Exact BIP30 on the connection path.** `Bitcoin.Ledger` now has
   hash-aware `applyBlockExactU` / `applyBlockExactL`, and
   `Block.Connect.connectBlock` uses an exact variant with the candidate's own
   block hash and the BIP34 ancestor hash. The old height-only wrapper remains
   available for canonical-chain specializations; `applyBlockExactL_canonical`
   proves the exact gate reduces to it at the pinned own hash and `BIP34Hash`.
   A fork colliding at 91842/91880 can no longer borrow the canonical
   height-only repeat exception.

4. **Real txid on the connection path.** `applyBlockExecTxid` keys created
   coins by `Bitcoin.DataLaws.txid` (double-SHA256 of the witness-free
   serialization), and `connectBlock` uses it. The capstone and ledger keys
   are bridged by `Bitcoin.Capstone.Block.txidKey_eq_ledger`. The frozen
   `applyBlock`/`applyBlockExec` preimage-key wrappers are preserved for the
   existing ledger theorems.

## Evidence

- `cd spec/core && lake build` — 149 jobs.
- `cd spec/proofs && lake build BitcoinProofs` — 1,733 jobs.
- `spec/core/Test/Capstone/Bip30.lean` — 27/27 checks, including the new
  ledger-level fork collision checks.
- `spec/core/Test/Capstone/TaprootBlocks.lean` — 8/8 checks; valid real
  Taproot spends still adjudicate completely.
- `cd spec/core && lake exe issue22` — 3/3 checks: the single entry point
  equals the contextual pipeline, and context-free replay reports
  `fullValidation = false`.
- `lake exe capstone` (release data bundle) — 13 anchors are replayed as
  diagnostic partial runs; the runner prints `accepted=false` and
  `partial-context`, never an acceptance claim.
- Contextual regressions: `HeaderContext`, `Finality`, `ScriptFlags`,
  `SigopBudget`, and `ValueChecks` all pass.
- Static gates: `rule_crosscheck.py`, `theorem_index.py --check`,
  `residuals_index.py --check`, `proof_scope.py --check`, sorry/axiom/wallet
  gates, and the reproducibility checks pass.

## Remaining P0 work (not claimed fixed here)

- **Genesis short-circuit in the capstone pipeline.** `connectBlock` already
  handles BLK-109, but `validateBlock`/`replayBlockPartial` do not yet special-case
  the genesis block. Fixing that requires moving the genesis predicate to a
  module below both `Block.Connect` and `Capstone.Block` to avoid an import
  cycle.
- **Public `decodeCompactSize` (C1 API).** It still has no canonicality or
  `MAX_SIZE` checks; this is the separately documented `F-Y01-001` API
  divergence, not the consensus `decCS` path.
- **Historical reachability.** Full validation still takes a caller-supplied
  `ChainContext` and UTXO view. A complete claim needs a proof that the
  supplied state is derived from the serialized chain history, not merely
  caller-consistent.

## Closure criteria

This batch is ready to merge when the core/proof builds and the listed
regressions pass, with no new axioms. It closes four live P0 implementation
gaps; it does not by itself close issue #4 or issue #16. Those require the
regenerated census, target-binding evidence, and the remaining genesis and
reachability work above.
