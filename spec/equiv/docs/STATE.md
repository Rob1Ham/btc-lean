# STATE — three-leg LLVM IR equivalence

**Snapshot:** `2026-10-21 (wave64 integration; evidence tier)`
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
present; `make pins`, `make e0`, `make gate-ir-pin`, and `make equiv` are the
gates, with the current certificate/ledger status below.

It is **not** an all-rows-green result and **not** a whole-engine proof:

- 152 of 183 SCR rows are both-tool green;
- 2 are explicitly `unjudged-seam`;
- 29 are filed `gap`s with named blockers;
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
| E1 stack/altstack, Alive2 + SAW, mutation | **PASS (cells); mutation evidence incomplete** | stack/control cells green; wave64 closes SCR-072/074; E1 mutation set not complete (`cells/_redteam/AUDIT-ADJUDICATION.md`) |
| E2 flow/ScriptNum/hash | **attempted; partial cells, rows filed gap** | wave64 closes SCR-079–085; **E2 required mutation set 4/4 killed** (`findings/wave64/47-mutations-e2/`) |
| E3 CHECKSIG/CHECKMULTISIG + symbolic checker + error enum | **attempted; partial cells, rows filed gap** | checksig/CMS ordinals 2/13/14/18/28/32; **mutation 2/5 required** (`M-E3-002`, `M-E3-008` killed) |
| E4 SegWit v0/taproot dispatch, seam inventory | **attempted; partial cells + inventory** | witness/tapscript cells green; **mutation 3/5 required** (`M-E4-003`, `M-E4-004`, `M-E4-007` killed) |
| E5 whole-function VerifyScript or residual | **scoped residual; bounded probes advanced** | `findings/e5/E5-RESIDUAL.md`; `findings/wave64/44-e5-heap-refinement/`; `findings/wave64/45-e5-exceptions-pcore01/`; no whole-function proof |
| E6 three-leg closure, coverage, gate, matrix | **PASS for the evidence-tier deliverable** | 183/183 adjudicated; `make gate-ir-pin` PASS; `results/matrix.md`; `findings/coverage/F-E6-GAPS.md` |
| E6+ wave16/32/64 row-family cells | **partial, additive** | 152 total green; families below; `findings/wave16/`, `findings/wave32/`, `findings/wave64/`, `findings/wave65/` |

## 3. Ledger and cells

Commands at this snapshot:

```text
make pins          -> RESULT: OK (pins complete and tool probes passed)
make e0            -> RESULT: PASS (E0_TRIPLE_OK; 4/4 tapes)
make gate-ir-pin   -> RESULT: PASS (344 certificates, 0 failures, 0 warnings)
make equiv         -> PASS (164 cells, 0 red, 0 TODO)
coverage_report.py --strict -> PASS; all 183 SCR rows adjudicated
cert_repro_check.py --rev HEAD --fuzz 0 -> PASS (all cell certs + manifests)
make gate-repro    -> PASS
```

Ledger counts:

| Status | Rows |
|---|---:|
| `both-green` | 152 |
| `alive2-green` / `saw-green` | 0 / 0 |
| `unjudged-seam` | 2 |
| `gap` | 29 |
| `planned` | 0 |
| **Total** | **183** |

Green rows by family (authoritative list: `results/matrix.md`):

- **control-flow (16):** SCR-056, 058–072.
- **limits (22):** SCR-018–020, 022–035, 037–039, 041, 042.
- **tapscript (21):** SCR-143–145, 148–152, 155–166, 168.
- **locktime (10):** SCR-122–131.
- **checksig (16):** SCR-096–103, 105–111, 113.
- **policy-flags (7):** SCR-176–182; **tapscript-reimport (1):** SCR-183.
- **witness-v0 (6):** SCR-134, 135, 137, 138, 139, 141.
- **exec-verify (11):** SCR-002, 004, 007, 009, 011–017.
- **checkmultisig (7):** SCR-114, 116–121.
- **push-encoding (10):** SCR-045–050, 052–055.
- **stack-ops (5):** SCR-073–077; **numeric (13):** SCR-079–085, 087–092.
- **disabled-opcodes (4):** SCR-170, 171, 173, 174.
- **hash-ops (3):** SCR-093–095.

The 2 seams are SCR-146/147; the 29 gaps are SCR-001, 003, 005, 006, 008,
010, 021, 036, 040, 043, 044, 051, 057, 078, 086, 104, 112, 115, 132, 133,
136, 140, 142, 153, 154, 167, 169, 172, 175. Each has a row-specific blocker in
`findings/coverage/F-E6-GAPS.md`; the wave64 reports add exact witnesses.

## 4. What is established

1. **Pins.** Alive2 v20.0 (`c0f5434`), SAW 1.6 (`68eed5f`), clang/LLVM
   20.1.2, z3 4.8.12, cvc5 1.3.1; Core `cce32b168…`; Lean model
   `4d62a97e…`; rbitcoin `ae47aa98…`. `PINS.lock` is complete; `[ir]`
   pins the `ir/manifest.json` closure.
2. **Contract v3.** Hash
   `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`.
   The recipe includes `contract/error_enum.md`; v2 is historical and its
   differential summaries are not silently relabelled.
3. **E0.** `make e0` executes the three shims on four tapes; C, L, R agree
   with exact Core ordinals. This is a harness/ABI gate, not IR evidence.
4. **E1–E4 cells.** Every recorded cell has an Alive2 and SAW attempt (or a
   filed inapplicability with a finding id). Wave64 added full rows for
   SCR-072, 074, 079–085, 093/095, and 116/117, plus partial evidence for
   the remaining gaps.
5. **E2 mutation set.** All four required E2 mutants are killed with raw
   baseline → mutant → revert logs, including a model-site application at
   `twin/ops_ir.py`. This is sensitivity evidence, not a row promotion.
6. **E3/E4 mutation sets.** E3 is 2/5, E4 is 3/5. The wave64 kills are
   L-leg transliteration sites; the required model-site/core-copy pairing is
   still unmet.
7. **E5.** No whole-function proof. SAW still stops at the symbolic
   `EvalScript` loop, the heap allocator, guard variables, and exception
   edges. Wave64 proved a bounded heap/capacity model and an amended
   exception-preserving P-CORE-01 form; neither is a ledger row. P-CORE-01
   remains PROPOSED and must not be used to hide a behavior change.
8. **IR.** `ir/manifest.json` records the 15-TU Core closure, twin, and
   rbitcoin artifacts and verifies their hashes. The pinned rustc 1.95 /
   LLVM-22 R IR is not Alive2-ingestible; the LLVM-20 lane is advisory and
   off-pin.
9. **Certificates.** 344 cell certificates replay in `gate-ir-pin`. The
   clean-checkout checker replays all cell certificates and manifests with
   zero errors; 531 hygiene warnings remain (`cross-leg`, absolute machine
   paths inside bound sources, nested divergence manifests) and are listed
   by the checker rather than hidden.
10. **Matrix.** `results/matrix.md` is generated deterministically and names
    the source, tool, contract, IR, and E5 premises, plus the 152/2/29
    coverage counts and cell links.

## 5. What is not established

- **No unconditional equivalence.** The matrix claim is conditional on
  Alive2/SAW semantics, the shims, the twin/translations, the contract, and
  same-crypto.
- **No engine proof.** The gaps include the whole E5 path, most tapscript and
  policy branches, checksig/multisig, crypto/hash leaves, and whole-engine
  composition. E5 is a residual, not a proved row.
- **No R proof lane.** R behavioral E0 is green. Alive2 rejects large parts
  of the pinned 1.95 module (`noalias`, `sret`, scoped alias metadata,
  atomics); the LLVM-20 lane is off-pin. No R green cell is claimed.
- **F-DIV-W32-01 (open).** The Lean `verifyScriptFull` `finalLen` checks
  `isWitnessProgram spk`, so the P2SH-wrapped witness arm is not resized to 1
  under CLEANSTACK; a concrete Lean probe returns CLEANSTACK where Core
  succeeds. SCR-008 is therefore gap; the flag/policy face remains proved.
  Fixing it requires a Lean-model change, which this workstream does not make.
- **F-DIV-004 / CPubKey.** Pinned Lean `isValidPubKey` is header-only while
  Core also enforces the promised length (`pk = [0x02]` is the witness). With
  the real parser the verdict coincides; this is a gate-level seam, not a
  consensus split.
- **SCR-043.** `MAX_PUBKEYS_PER_MULTI_A=999` is a miniscript/wallet
  construction constant, not an interpreter check; the Lean tree has no
  Miniscript parser. No C/L pair exists, so no cell is claimed.
- **SCR-142.** The pin has no taproot height gate; the historical 709632
  window is not a property of `GetBlockScriptFlags@cce32b168`, and the tape
  has no height/hash channel.
- **Crypto.** ECDSA/Schnorr/HASH160/SHA256 are abstracted or concrete
  witnesses only; the same-crypto premise is explicit.
- **No Lean-kernel theorem.** Results are evidence-tier; the Lean model is a
  provenance/rule source, not a kernel-checked LLVM semantics.
- **Core patches remain PROPOSED.** P-CORE-01/02/03 are not used by any green
  cell; P-CORE-04 has focused differential rows but no green cell; P-CORE-05
  measured no-go. No consensus-changing patch is used to hide divergence.
- **Tree state.** The evidence is committed on PR branch
  `equiv/llvm-three-leg`; additive wave branches are integrated through
  isolated worktrees, not pushed to `main`.
