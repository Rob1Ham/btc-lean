# STATE — three-leg LLVM IR equivalence

**Snapshot:** `2026-10-20T00:00:00Z` (UTC), post-wave16 integration
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

- 22 of 183 SCR rows are both-tool green;
- 17 are explicitly `unjudged-seam`;
- 144 are filed `gap`s with named blockers;
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
| E1 stack/altstack, Alive2 + SAW, mutation | **PASS (cells + mutations)** | 9 E1/stack control cells; SCR-069/071/072/074 green; 8 mutation runs, 7 distinct IDs, all killed |
| E2 flow/ScriptNum/hash | **attempted, partial** | `cells/e2-numeric/within-boundary` (SCR-089 partial), `cells/e2-hash/hash160-vector` (SCR-093/094 partial); both tools green; rows filed gap |
| E3 CHECKSIG/CHECKMULTISIG + symbolic checker + error enum | **attempted, partial** | `cells/e3-checksig/C-L-checksig-dispatch`, `cells/e3-cms/C-L-cms-1of1`, fallback `cells/checksig/C-L-checksig-empty`; ordinals 2/13/14/18/28; `M-E3-008` killed |
| E4 SegWit v0/taproot dispatch, seam inventory | **attempted, partial** | `cells/e4-witness/C-L-witness-v0-dispatch` (dispatch predicates only); `findings/e4/seams.md`; `M-E4-004` killed; 38 seam/gap rows adjudicated |
| E5 whole-function VerifyScript or residual | **scoped residual** | `findings/e5/E5-RESIDUAL.md`; no whole-function proof; SAW stops at GetScriptOp, `_Znwm`, EvalScript loop, exception edges; green empty-script line is concolic/non-pin |
| E6 three-leg closure, coverage, gate, matrix | **PASS for the evidence-tier deliverable** | 183/183 adjudicated; `make gate-ir-pin` 0 failures; `make equiv` 28 cells, 0 red, 0 TODO; `results/matrix.md`; `findings/coverage/F-E6-GAPS.md` |
| E6+ wave16 limits/tapscript cells | **partial, additive** | 10 limits rows + 8 tapscript rows both-tool green; `findings/wave16/`; 22 total green |

## 3. Ledger and cells

Commands at this snapshot:

```text
make pins          -> RESULT: OK (pins complete and tool probes passed)
make e0            -> RESULT: PASS (E0_TRIPLE_OK; 4/4 tapes)
make gate-ir-pin   -> RESULT: PASS (0 failures, 0 warnings)
make equiv         -> summary: 28 cell(s) with >=1 green tool, 0 red, 0 TODO
update_ledger.py --check -> up to date
coverage_report.py --strict -> PASS; all 183 SCR rows adjudicated
```

Ledger counts:

| Status | Rows |
|---|---:|
| `both-green` | 22 |
| `alive2-green` / `saw-green` | 0 / 0 |
| `unjudged-seam` | 17 |
| `gap` | 144 |
| `planned` | 0 |
| **Total** | **183** |

Green rows:

- **SCR-018, SCR-019, SCR-020, SCR-022, SCR-023, SCR-024, SCR-025, SCR-029,
  SCR-030, SCR-031** — bounded limits cells (`C-L-script-size`,
  `C-L-push-size`, `C-L-opcount`, `C-L-stack-limit`,
  `C-L-tapscript-precheck`). SCR-021 is tool-green but partial and remains a
  gap.
- **SCR-069, SCR-071, SCR-072** — `cells/control-flow/C-L-nop-return`;
  Alive2 and SAW green on the NOP4..NOP10 straight-line control cell.
- **SCR-074** — `cells/stack-ops/C-L-arity` (16 opcodes, 16 Alive2 + 32 SAW
  green), corroborated by `e1-stack/dup-order`,
  `e1-stack/rot-direction`, `e1-stack/swap-order`, and
  `stack/C-L-dup-drop-swap`.
- **SCR-143, SCR-144, SCR-145, SCR-148, SCR-149, SCR-150, SCR-151, SCR-152**
  — tapscript dispatch cells. SCR-144 (key path) is conditional on the
  same-crypto premise P12. SCR-142 is tool-green but partial (activation
  height is absent from the tape) and remains a gap.

The remaining recorded cells are tool-green but their SCR coverage is
`partial`, or they are corroborating witnesses; the updater therefore does
**not** promote those rows. The 17 seams are the E4 hash/EC/dispatch/sighash/
clean-stack families plus SCR-045 (F-DIV-001 eager-parse seam). The 144 gaps
are indexed in `findings/coverage/F-E6-GAPS.md`, each with a row-specific
blocker.

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
   success markers. `M-E1-001` (twin and core-slice), `M-E1-002`,
   `M-E1-006`, `M-E1-008`, `M-E2-010`, `M-E4-004`, and `M-E3-008` were
   killed by both tools, with clean source restoration and green baselines.
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
    the source, tool, contract, IR, and E5 premises, plus the 22/17/144
    coverage counts and cell links.

## 5. What is not established

- **No unconditional equivalence.** The matrix claim is conditional on
  Alive2/SAW semantics, the shims, the twin/translations, the contract, and
  same-crypto.
- **No engine proof.** 144 gaps include all `exec-verify`, most limits,
  locktime, policy, most disabled-opcode, and most tapscript rows. E5 is a
  residual.
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
  `equiv/llvm-three-leg`; wave worktrees are isolated and not yet all merged.

## 6. Findings and dispositions

The historical evaluator audit is
`findings/evaluator/audit.md`; its addendum records the post-snapshot
resolutions. In brief:

- **B-06 resolved:** contract v3 includes `error_enum.md`.
- **B-01 resolved for the evidence tier:** 0 planned rows; 22 green, 17 seam,
  144 gap; no row is silently omitted.
- **B-09 resolved:** mutations were executed and killed.
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
- **B-08 open:** `spec/equiv/` is untracked (no commits by instruction).

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
