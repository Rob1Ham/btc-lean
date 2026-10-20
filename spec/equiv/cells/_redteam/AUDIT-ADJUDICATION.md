# Mutation evidence adjudication (2026-10-20)

This file records the adjudication of the eight mutation run reports after the
independent wave16b/16 and wave32/32 audits. It does not rewrite the raw run
logs; those are retained unchanged.

## Admitted as observed (2 runs, 2 distinct IDs)

- `M-E3-008-e3-cell-20261019T230115Z.md` — genuine non-green CHECKMULTISIGVERIFY
  error-terminal output.
- `M-E4-004-e4-cell-20261019T225535Z.md` — genuine non-green v0 witness-length
  output.

Both reports show non-green mutant tails, but their machine records remain
`status: applied` / `outcome: pending`, with no witness or log hashes. They are
therefore **observed, not formally admitted** and count toward no required
mutation set.

## Withdrawn as evidence (6 reports)

- `M-E1-001-twin-20261019T224022Z.md`
- `M-E1-002-twin-20261019T224029Z.md`
- `M-E1-006-twin-20261019T224036Z.md`
- `M-E1-001-core-copy-20261019T224043Z.md`
- `M-E2-010-twin-20261019T224702Z.md`
- `M-E1-008-twin-20261019T225415Z.md`

Each report has a `KILLED` header but pastes a green Alive2/SAW tail
(`Transformation seems to be correct!` / `STATUS=...-green`). The tail is
consistent with the post-revert baseline, not the mutant. The reports are kept
as raw records but are **not evidence of a kill**.

## Effect on claims

The E1/E2/E3/E4 required mutation sets are **not complete**: E2 is 0/4, E3 is
1/5 (observed only), E4 is 1/5 (observed only). `results/STATUS.md` and
`docs/STATE.md` must not claim a mutation PASS. The cell-level Alive2/SAW
results are unaffected; mutation evidence is a separate control.

A future admissible run must: record the actual mutant result, populate the
JSON record with `outcome: killed`, a witness, and log hashes, and revert to
the baseline hash with a green post-revert cell.

## Wave64 update (2026-10-20)

This section is additive; the adjudication above is retained unchanged.

Five new admissible runs now satisfy that bar (see
`cells/_redteam/WAVE64-ADJUDICATION.md` and `WAVE64-MATRIX.md`):

- E3: `M-E3-002` and `M-E3-008` are **KILLED** (2/5 required).
- E4: `M-E4-003`, `M-E4-004` and `M-E4-007` are **KILLED** (3/5 required).

The two 2026-10-19 pending records for `M-E3-008` and `M-E4-004` are
superseded by the new runs but are retained unchanged. The six withdrawn
reports above remain withdrawn. **No required set is complete and no mutation
PASS is claimed.** All five new kills are L-leg transliteration sites; the
protocol's model-site and core-copy pairing for E3/E4 is still unmet.
