# Wave64 E3/E4 mutation adjudication (2026-10-20)

Scope: repair the E3/E4 mutation-evidence gap left by
`AUDIT-ADJUDICATION.md`. Base commit `5946c02`. Worktree
`/tmp/opencode/wave64/48-mutations-e3e4`, branch
`wave64/48-mutations-e3e4`.

This file adds evidence. It does not rewrite the 2026-10-19 raw records, and it
does not promote any cell or SCR row.

## 1. Admissible runs added (5 distinct mutants, 5 kills)

Every run below used
`cells/_redteam/run_mutant_admissible.py`, which:

1. runs both tools on the unmutated cell and requires both green (B-gate);
2. writes the concrete witness declaration *before* applying the mutation;
3. applies exactly one mutation through `mutate.py`;
4. runs both tools on the mutated build, capturing raw logs and result files;
5. reverts through `mutate.py`, checks the target hash equals `sha256_before`,
   and re-runs both tools green;
6. writes `outcome: killed`, `classification: KILLED`, the witness, log hashes,
   operator and `reverted_at_utc` into the mutant JSON record.

| Mutant | Target | Cell | Tools | Witness | Run report |
|---|---|---|---|---|---|
| `M-E3-002` | `cells/_tools/e3/cellsig/l_cms.cpp` | `e3-cms/C-L-cms-1of1` (`cell_cms_nulldummy`) | alive2 + saw | `Source value 112` (`SIG_NULLDUMMY=28`) vs `Target value 264` (result 1) | `runs/M-E3-002-e3-cell-20261020T220746Z/report.md` |
| `M-E3-008` | `cells/_tools/e3/cellsig/l_cms.cpp` | `e3-cms/C-L-cms-1of1` (`cell_cmsverify`) | alive2 + saw | `Source value 52` (`CHECKMULTISIGVERIFY=13`) vs `Target value 24` (`EVAL_FALSE=2`) | `runs/M-E3-008-e3-cell-20261020T220846Z/report.md` |
| `M-E4-003` | `cells/tapscript/C-L-taproot-scriptpath-dispatch/l_leg.cpp` | `tapscript/C-L-taproot-scriptpath-dispatch` (`cell_leaf_version`) | alive2 + saw | result 2 (tapscript) vs 1 (non-tapscript); SAW `control0=0xffff...ffc1` masked wrongly | `runs/M-E4-003-e4-cell-20261020T221027Z/report.md` |
| `M-E4-004` | `cells/_tools/e4/l_cell.cpp` | `e4-witness/C-L-witness-v0-dispatch` (`cell_v0_dispatch`) | alive2 + saw | `plen=20, wn=3`: packed 160 (fail,40) vs 1 (success) | `runs/M-E4-004-e4-cell-20261020T221054Z/report.md` |
| `M-E4-007` | `cells/tapscript/C-L-tapscript-isopsuccess/l_leg.cpp` | `tapscript/C-L-tapscript-isopsuccess` (`cell_is_op_success`) | alive2 + saw | `w=80`/`w=98` (`OP_SUCCESS80/98`): baseline 1 vs mutant 0; SAW witness `w=98` | `runs/M-E4-007-e4-cell-20261020T221110Z/report.md` |

Machine records (all `status: reverted`, `outcome: killed`, non-empty
`witness`, non-empty `log_hashes`, `operator` set):

- `mutants/M-E3-002-e3-cell-20261020T220759Z-f775117e.json`
- `mutants/M-E3-008-e3-cell-20261020T220904Z-f775117e.json`
- `mutants/M-E4-003-e4-cell-20261020T221035Z-27f8ab24.json`
- `mutants/M-E4-004-e4-cell-20261020T221058Z-5d97ae96.json`
- `mutants/M-E4-007-e4-cell-20261020T221114Z-387da37e.json`

Revert receipts are the matching `.json.revert.json` files. The four target
sources were restored byte-for-byte to their baseline hashes; the post-revert
baseline was green on both tools in every run.

## 2. Superseded pending records (2)

These 2026-10-19 records remain unchanged and are **superseded** for evidence
counting by the wave64 runs above:

| Old pending record | Old run report | Superseded by |
|---|---|---|
| `mutants/M-E3-008-e3-cell-20261019T230039Z-f775117e.json` | `runs/M-E3-008-e3-cell-20261019T230115Z.md` | `mutants/M-E3-008-e3-cell-20261020T220904Z-f775117e.json` |
| `mutants/M-E4-004-e4-cell-20261019T225524Z-5d97ae96.json` | `runs/M-E4-004-e4-cell-20261019T225535Z.md` | `mutants/M-E4-004-e4-cell-20261020T221058Z-5d97ae96.json` |

The old reports stay in the tree with their adjudication banners. They are not
counted.

## 3. Still withdrawn (6)

The six 2026-10-19 reports with `KILLED` headers but green tails remain
withdrawn as evidence. No new run in this wave changes their status:

`M-E1-001-twin-20261019T224022Z.md`,
`M-E1-002-twin-20261019T224029Z.md`,
`M-E1-006-twin-20261019T224036Z.md`,
`M-E1-001-core-copy-20261019T224043Z.md`,
`M-E2-010-twin-20261019T224702Z.md`,
`M-E1-008-twin-20261019T225415Z.md`.

## 4. Required-set status (no PASS)

| Family | Required | Admissible kills | Status |
|---|---:|---:|---|
| E3 | 5 | 2 (`M-E3-002`, `M-E3-008`) | **INCOMPLETE (2/5)** |
| E4 | 5 | 3 (`M-E4-003`, `M-E4-004`, `M-E4-007`) | **INCOMPLETE (3/5)** |

Unobserved E3 rows: `M-E3-001`, `M-E3-003`, and the required "one of
`M-E3-004`–`M-E3-007`" slot (all four remain unobserved).
Unobserved E4 rows: `M-E4-001`, `M-E4-002`.

They are coverage blockers, not equivalent-mutant claims. The exact missing
witnesses are listed in `WAVE64-MATRIX.md`.

## 5. Blockers beyond the counts

1. **Site pairing is unmet.** All five kills are L-leg transliteration sites
   (`e3-cell` / `e4-cell`). PROTOCOL.md 2.3 also requires at least one
   model-site and one core-copy kill per family. No such kill was produced in
   this wave; the required sets would still not sign off at 5/5.
2. **Missing cells.** The unobserved mutants need materialized cells for CMS
   iteration order, NULLFAIL, encoding gates, FindAndDelete, CODESEPARATOR,
   P2SH redeem-source selection and witness stack order. Several of those
   witnesses are explicitly outside the current bounded cells' preconditions.
3. **Cells remain partial.** A mutation kill is proof-sensitivity evidence for
   the bounded cell. It does not promote SCR-112/134/135/137/152 or any other
   row to green.
4. **SAW abort-on-first-failure.** In the E3 CMS cell, SAW stops a checker
   build at the first failed `llvm_verify`, so its `N/16` count under-reports
   the number of scenarios attempted after the failure. Alive2 ran every
   `cell_*` function in the same run and is the complete-sensitivity leg. This
   affects the printed proof count, not the kill classification.
5. **Path-dependent cell artifacts.** Cell `result.txt`/`certificate.sha256`
   files contain worktree-path-dependent IR hashes. The wave64 runs restored
   the committed cell artifacts after the runs; the raw run directories retain
   the actual hashes observed in this worktree.

## 6. Reproduction

```sh
cd /tmp/opencode/wave64/48-mutations-e3e4
python3 spec/equiv/cells/_redteam/run_mutant_admissible.py \
  --mutation M-E3-002 --target-kind e3-cell \
  --target spec/equiv/cells/_tools/e3/cellsig/l_cms.cpp \
  --cell e3-cms/C-L-cms-1of1 \
  --witness-plan '<the plan recorded in runs/.../plan.md>'
```

The exact commands, baseline/mutant/post statuses, mutation diff, raw logs and
log hashes for each run are in its `runs/<label>-<stamp>/report.md` and
`meta.json`.
