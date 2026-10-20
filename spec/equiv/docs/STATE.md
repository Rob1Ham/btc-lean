# STATE — three-leg LLVM IR equivalence

**Snapshot:** `2026-10-20 (wave 16/32 integration)`
**Owner:** orchestrator; independent evaluator snapshot archived at
`docs/archive/STATE-2026-10-19T223700Z.md`
**Tree:** `spec/equiv/` on PR branch `equiv/llvm-three-leg`

This is the current state. The earlier evaluator snapshot is preserved rather
than rewritten; where it says “0 green / 178 planned / 6 red”, that is the
historical state before E2–E6 integration, not the current one.

---

## 1. Verdict

The workstream is **evaluable at the evidence tier**. The harness, contract,
pins, shims, cells, tool runs, ledger, matrix, findings, and residual are all
present; `make pins`, `make e0`, `make gate-ir-pin`, and `make equiv` pass.

It is **not** an all-rows-green result and **not** a whole-engine proof:

- 95 of 183 SCR rows are both-tool green;
- 7 are explicitly `unjudged-seam`;
- 81 are filed `gap`s with named blockers;
- 0 are `planned`;
- no `EvalScript`/`VerifyScript` whole-function proof exists (E5 residual);
- no admissible R proof-lane artifact exists (the R behavioral E0 leg does);
- crypto is abstracted on both legs (same-crypto premise).

Those are stated as limits, not hidden. The claim in `results/matrix.md` is
conditional and must remain so.

## 2. Milestone state

| Milestone | State | Evidence |
|---|---|---|
| E0 harness/ABI, three shims, tools, pins, capability matrix | **PASS** | `make pins` rc 0; `make e0` rc 0, 4/4 tapes; `results/e0/`; `tools/capability-matrix.md` |
| E1 stack/altstack, Alive2 + SAW, mutation | **PASS (cells); mutation evidence incomplete** | 9 E1/stack control cells; SCR-069/071 green; SCR-072/074 demoted; 6/8 mutation reports withdrawn, 2 observed, 0 admitted (`cells/_redteam/AUDIT-ADJUDICATION.md`) |
| E2 flow/ScriptNum/hash | **attempted, partial** | `cells/e2-numeric/within-boundary` (SCR-089 partial), `cells/e2-hash/hash160-vector` (SCR-093/094 partial); both tools green; rows filed gap |
| E3 CHECKSIG/CHECKMULTISIG + symbolic checker + error enum | **attempted, partial** | `cells/e3-checksig/C-L-checksig-dispatch`, `cells/e3-cms/C-L-cms-1of1`, fallback `cells/checksig/C-L-checksig-empty`; ordinals 2/13/14/18/28; `M-E3-008` observed non-green, record pending |
| E4 SegWit v0/taproot dispatch, seam inventory | **attempted, partial** | `cells/e4-witness/C-L-witness-v0-dispatch` (dispatch predicates only); `findings/e4/seams.md`; `M-E4-004` observed non-green, record pending; 38 seam/gap rows adjudicated |
| E5 whole-function VerifyScript or residual | **scoped residual** | `findings/e5/E5-RESIDUAL.md`; no whole-function proof; bounded B1/B2 probes (`findings/wave16b/02`, `03`) but the symbolic EvalScript loop, allocator refinement, and exception edges remain; the empty-script line is concolic/non-pin |
| E6 three-leg closure, coverage, gate, matrix | **PASS for the evidence-tier deliverable** | 183/183 adjudicated; `make gate-ir-pin` 0 failures; `make equiv` 89 cells, 0 red, 0 TODO; `results/matrix.md`; `findings/coverage/F-E6-GAPS.md` |
| E6+ wave16/32 row-family cells | **partial, additive** | 95 total green: control-flow 16, limits 21, tapscript 13, locktime 11, checksig 10, policy 7, witness-v0 6, exec 5, disabled 4, hash 1, reimport 1; `findings/wave16/`, `findings/wave32/` |

## 3. Ledger and cells

Commands at this snapshot:

```text
make pins          -> RESULT: OK (pins complete and tool probes passed)
make e0            -> RESULT: PASS (E0_TRIPLE_OK; 4/4 tapes)
make gate-ir-pin   -> RESULT: PASS (0 failures, 0 warnings)
make equiv         -> summary: 89 cell(s) with >=1 green tool, 0 red, 0 TODO
update_ledger.py --check -> up to date
coverage_report.py --strict -> PASS; all 183 SCR rows adjudicated
```

Ledger counts:

| Status | Rows |
|---|---:|
| `both-green` | 95 |
| `alive2-green` / `saw-green` | 0 / 0 |
| `unjudged-seam` | 7 |
| `gap` | 81 |
| `planned` | 0 |
| **Total** | **183** |

Green rows by family (authoritative list: `results/matrix.md`):

- **control-flow (16):** SCR-056–071, except SCR-072 (withdrawn).
- **limits (21):** SCR-018–020, 022–033, 035, 037–039, 041, 042.
- **tapscript (13):** SCR-143–145, 148–152, 163–166, 168; SCR-144 is
  conditional on the same-crypto premise P12.
- **locktime (11):** SCR-122–132.
- **checksig (10):** SCR-102, 103, 105–111, 113.
- **policy-flags (7):** SCR-176–182; **tapscript-reimport (1):** SCR-183.
- **witness-v0 (6):** SCR-134, 135, 137, 138, 139, 141.
- **exec-verify (5):** SCR-002, 004, 014–016.
- **disabled-opcodes (4):** SCR-170, 171, 173, 174.
- **hash-ops (1):** SCR-094.

SCR-021, 040, 072, 074, 133, 136, 140, 142, 175, and the remaining rows are
partial, seam, or gap and are not promoted. The 7 seams and 81 gaps are
indexed in `findings/coverage/F-E6-GAPS.md`, each with a row-specific blocker.

## 4. What is established

1. **Pins.** Alive2 v20.0 (`c0f5434`), SAW 1.6 (`68eed5f`), clang/LLVM
   20.1.2, z3 4.8.12, cvc5 1.3.1; Core `cce32b168…`; Lean model
   `4d62a97e…`; rbitcoin `ae47aa98…`. `PINS.lock` is complete; `[ir]`
   pins the `ir/manifest.json` closure.
2. **Contract v3.** Hash
   `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`.
   The recipe now includes `contract/error_enum.md`; v2 (`c2fcc67a…`) is
   historical and its differential summaries are not silently relabelled
   (`contract/CHANGELOG.md`, `differential/results/CONTRACT-NOTE.md`).
3. **E0.** `make e0` executes the three shims on four tapes; C, L, R agree
   with exact Core ordinals. This is a harness/ABI gate, not IR evidence.
4. **E1 cells and mutation.** All recorded E1/stack cells have Alive2 and SAW
   success markers. The mutation control is **not** passed: six of eight raw
   reports are withdrawn because their green tails contradict their `KILLED`
   headers; `M-E3-008` and `M-E4-004` show genuine non-green output but their
   JSON records remain pending. See `cells/_redteam/AUDIT-ADJUDICATION.md`.
   No required mutation set is complete.
5. **E2.** A symbolic one-byte `OP_WITHIN` cell (2^24 triples) and a concrete
   HASH160 plumbing cell are both tools-green. They are partial by design;
   the hash transform is opaque and the numeric width/edge cases are outside
   the cell. Rows remain gaps.
6. **E3.** Checksig and 1-of-1 CMS cells use one shared external
   `btc_equiv_check_sig`; Alive2 quantifies over its verdict and SAW pins it
   to 0/1. Exact error ordinals 2, 13, 14, 18, 28 are observed on both legs.
   DER/sighash/NULLFAIL/general bounds are not covered; rows remain gaps.
7. **E4.** The v0 dispatch cell proves length/arity predicates only; SHA256
   and `ExecuteWitnessScript` are abstracted. The 38-row seam/gap inventory
   is explicit; SCR-134/135/137 are tool-green but partial and remain gap.
8. **E5.** No whole-function proof. SAW loads the real module and executes a
   concrete empty-script case, but stops on `GetScriptOp`, the heap
   allocator, the EvalScript dispatch loop, and exception edges. The green
   empty-script line is non-pin/concolic; it is not a ledger row. The exact
   blockers are in `findings/e5/E5-RESIDUAL.md` and `E5:F-TOOL-001`.
9. **IR.** `ir/manifest.json` records the 15-TU Core closure, twin, and
   rbitcoin artifacts and verifies their hashes; `all_recorded_hashes_match`
   is true. The pinned rustc 1.95/LLVM-22 R IR is not Alive2-ingestible; the
   rustc 1.88/LLVM-20 lane is advisory and not the official artifact.
10. **Matrix.** `results/matrix.md` is generated deterministically and names
    the source, tool, contract, IR, and E5 premises, plus the 95/7/81
    coverage counts and cell links.

## 5. What is not established

- **No unconditional equivalence.** The matrix claim is conditional on
  Alive2/SAW semantics, the shims, the twin/translations, the contract, and
  same-crypto.
- **No engine proof.** 81 gaps include the whole E5 path, most tapscript and
  policy branches, checksig/multisig, crypto/hash leaves, and whole-engine
  composition. E5 is a residual, not a proved row.
- **No R proof lane.** R behavioral E0 is green; the pinned 1.95 IR is
  rejected by Alive2 (`F-TOOL-001`), and the 1.88/LLVM-20 lane is non-pin.
  No R green cell is claimed.
- **No crypto proof.** ECDSA/Schnorr/HASH160 are abstracted or concrete
  witnesses only; the same-crypto premise is explicit.
- **No Lean-kernel theorem.** Results are evidence-tier; the Lean model is a
  provenance/rule source, not a kernel-checked LLVM semantics.
- **Core patches remain PROPOSED.** P-CORE-01/02/03 are not used by any green
  cell and have no differential evidence; no consensus-changing patch exists.
- **Tree state.** The evidence is committed on PR branch
  `equiv/llvm-three-leg`; additive wave branches are integrated through
  isolated worktrees, not pushed to `main`.

## 6. Findings and dispositions

The historical evaluator audit is
`findings/evaluator/audit.md`; its addendum records the post-snapshot
resolutions. In brief:

- **B-06 resolved:** contract v3 includes `error_enum.md`.
- **B-01 resolved for the evidence tier:** 0 planned rows; 95 green, 7 seam,
  81 gap; no row is silently omitted.
- **B-09 open:** mutation evidence is not admitted; six reports are withdrawn
  and two observed runs have pending records.
- **B-10 resolved:** `make equiv` parses `result.txt`, skips aux dirs, and
  reports 28 cells / 0 red / 0 TODO.
- **M-15 resolved:** PINS records the ABI shim source hash.
- **M-16 resolved:** differential R blocker wording corrected; v2 summaries
  marked historical.
- **B-03 open:** no admissible R proof artifact; filed as a limitation, not a
  green claim.
- **B-04 resolved as scoped residual:** E5 residual filed.
- **B-05 open:** Core patches remain PROPOSED and unused.
- **B-07 fixed:** seam validator accepts a named finding id in addition to
  `DECISION-lax-ecdsa.md`.
- **B-08 resolved:** `spec/equiv/` is tracked on PR #29; wave branches are
  integrated into `equiv/llvm-three-leg`.

Every non-green row is a filed gap or seam in the ledger and in
`findings/coverage/F-E6-GAPS.md`; no unfiled row remains.

## 7. Reproduce

```sh
cd spec/equiv
make pins
make e0
make gate-ir-pin
make equiv
python3 results/scripts/coverage_report.py --strict
python3 results/scripts/update_ledger.py --check
python3 results/scripts/build_matrix.py --check
```

Read `results/STATUS.md` for the compact checkpoint, `results/matrix.md` for
the named trust base and per-family counts, and
`findings/coverage/F-E6-GAPS.md` for every non-green disposition.
