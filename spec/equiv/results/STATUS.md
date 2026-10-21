# STATUS — three-leg LLVM IR equivalence

**Last updated:** 2026-10-21 (wave66 accepted-cell integration; evidence tier)
**Current state:** **E0 PASS; E6 evidence-tier closure published.**

The ledger has **183/183 SCR rows adjudicated**: **159 both-tool green**,
**1 unjudged seam**, **23 filed gaps**, and **0 planned**. `coverage_report.py
--strict` passes. `make gate-ir-pin` replays **376 certificates** with 0
failures and 0 warnings. This is **not** an all-rows-green claim and not a
whole-engine equivalence proof; the limits are below.

## Milestones

| ID | Deliverable | Status | Evidence |
|---|---|---|---|
| **E0** | Harness/ABI, three hello-world shims, tool install + pins, capability matrix, `PINS.lock` | **PASS** | `make e0` green; 4/4 tapes; `results/e0/`; `tools/capability-matrix.md` |
| **E1** | Stack-op family, Alive2 + SAW, REDTEAM mutation test | **PASS (cells); mutation evidence incomplete** | stack/control cells green; wave64 closes SCR-072/074; mutation sets still incomplete (`cells/_redteam/AUDIT-ADJUDICATION.md`) |
| **E2** | Flow / ScriptNum / hash families | **attempted; partial cells, rows filed gap** | wave64 closes SCR-079–085; E2 mutation set **4/4 required killed** (`findings/wave64/47-mutations-e2/`) |
| **E3** | CHECKSIG/CHECKMULTISIG + symbolic checker + error-enum equality | **attempted; partial cells, rows filed gap** | checksig/CMS ordinals 2/13/14/18/28/32; **mutation 2/5 required** (`M-E3-002`, `M-E3-008` killed; three rows unobserved) |
| **E4** | SegWit v0 / taproot dispatch; seam-unjudged cells enumerated | **attempted; partial cells + inventory** | witness/tapscript cells green; **mutation 3/5 required** (`M-E4-003`, `M-E4-004`, `M-E4-007` killed; two rows unobserved) |
| **E5** | Whole-function `VerifyScript` (SAW invariants) or scoped residual | **scoped residual; bounded probes advanced** | `findings/e5/E5-RESIDUAL.md`, `findings/wave64/44-e5-heap-refinement/`, `findings/wave64/45-e5-exceptions-pcore01/`; no whole-function proof |
| **E6** | Three-leg closure, full SCR coverage, `gate-ir-pin`, published matrix | **PASS for the evidence-tier deliverable** | 183/183 adjudicated; `make gate-ir-pin` 0 failures; `results/matrix.md`; `findings/coverage/F-E6-GAPS.md` |
| **E6+** | Wave 16/32/64/65/66 row-family cells integrated | **partial, additive** | 159 total green; see family table below |

## Ledger snapshot

| Metric | Value |
|---|---:|
| SCR rows in `spec/db/rules.yaml` | 183 |
| Ledger entries in `spec/db/equiv-cells.yaml` | 183 |
| Families | 15 |
| Proof-cell directories (recorded) | 177 |
| `planned` | 0 |
| Both-tool green rows | 159 |
| Alive2-only / SAW-only green rows | 0 / 0 |
| `unjudged-seam` | 1 |
| Filed `gap` | 23 |
| Malformed cell records | 0 |
| `make gate-ir-pin` | PASS (376 certificates, 0 failures, 0 warnings) |
| `make equiv` | PASS (177 cells, 177 with >=1 green tool, 0 red, 0 TODO) |
| `coverage_report.py --strict` | PASS — all 183 rows adjudicated |

Green rows by family (authoritative per-row list is `results/matrix.md`):

| Family | Green | Family | Green |
|---|---:|---|---:|
| control-flow | 17 | limits | 23 |
| tapscript | 21 | locktime | 11 |
| checksig | 16 | witness-v0 | 7 |
| exec-verify | 12 | checkmultisig | 7 |
| push-encoding | 11 | stack-ops | 5 |
| numeric | 14 | hash-ops | 3 |
| disabled-opcodes | 4 | tapscript-reimport | 1 |
| policy-flags | 7 | **total** | **159** |

Non-green rows:

- **`unjudged-seam` (1):** SCR-147 (Taproot tweak/commitment). It requires
  the same-crypto premise and a libsecp tweak proof; the wave64/wave66
  partial evidence narrows the non-crypto content but does not promote it.
- **Filed gaps (23):** SCR-003, 005, 006, 008, 010, 021, 036, 043, 044, 078,
  104, 112, 115, 133, 140, 142, 146, 153, 154, 167, 169, 172, 175.
  Per-row blockers are in `findings/coverage/F-E6-GAPS.md` and the
  wave65/wave66 reports referenced there.

## Wave65 audit correction (independent snapshot audit)

- **The independent wave65/32 audit found four overclaimed greens.**
  SCR-003 (`eval-empty`) covered the empty frame only, not the row's short
  script with ops; SCR-006 (`scriptSig push-only`) excluded the malformed-tail
  error-kind divergence F-DIV-001; SCR-057 (`CastToBool`) covered only lengths
  0..2; and SCR-132 (`CheckLockTime/Sequence`) covered a bounded two-input
  instance, not an arbitrary vin list. All four cells were demoted at that
  snapshot. SCR-001/040/051/057/086/132 were later re-closed by complete
  wave66 cells; SCR-003/006 remain gaps. Counts after the accepted wave66
  batch are **159 both-green / 1 seam / 23 gaps**. The audit report is
  `findings/wave65/32-audit/report.md`.
- **The matrix headline was corrected.** It previously said “the three engines
  agree”; there are no R cells and the R lane remains advisory/blocked. The
  generated claim now reads: the Core slice and the Lean-derived twin agree,
  C/L only.

## Wave66 accepted batch and held overclaims

The accepted batch adds six row-closing cells and 32 certificates:
SCR-001 (full sequencing/parse-boundary), SCR-040 (loop-to-fold bridge),
SCR-051 (arbitrary-length MINIMALDATA), SCR-057 (0..520 symbolic loop),
SCR-086 (all four clamp sites), and SCR-132 (arbitrary `List TxIn`). The
staging tree passed clean-tree `gate_ir_pin.py`; this tree passes the full
177-cell `make equiv` with 0 red and 0 TODO.

Held as partial evidence, **not promoted**: SCR-003 (NOP-only), SCR-006
(0..4-byte arm + Lean fold), SCR-008 (full only after a `finalLen` model
patch), SCR-010 (8-byte driver / 48-byte walk; C++ wrapper unmodelled),
SCR-021/044/153/154 (C loop or serializer unproved), SCR-036 (ABI bounds
48/16), SCR-078 (depth ≤12 and malformed record), SCR-104 (LOW_S model
divergence), SCR-112 (`F-DIV-004`), SCR-115 (C→Lean all-length link absent),
SCR-133 (SHA-256 driver/instantiation), SCR-146 (short-script digest and
compression premise), SCR-167 (`stepBody → absStep` projection), SCR-169
(fixed decoded-tx shape; primitive link unproved), SCR-172 (O-SKIP), and
SCR-175 (SAW policy-gate timeout). The detailed blockers remain in the
per-wave findings and `F-E6-GAPS.md`.

## Wave64 audit outcomes that changed or constrain the ledger

- **SCR-012 is now green.** The wave64 `exec-verify/C-L-w64-p2sh-single-push`
  cell proves the single-push production and the `WITNESS_MALLEATED_P2SH`
  guard for every reachable scriptSig (0..49 bytes) and redeemScript (4..42
  bytes), including all four push encodings and the BAD_OPCODE/MINIMALDATA
  precedence. This closes the producing-scriptSig residual that the earlier
  tail cell had declared.
- **SCR-008 was demoted from green to gap.** `F-DIV-W32-01` reproduces for a
  valid P2SH-wrapped v0 witness spend: Core resizes the final stack to one
  element, while the pinned Lean `verifyScriptFull` reuses the redeem-script
  length and rejects with CLEANSTACK. The flag/policy face remains proved;
  the witness-implicit face is not. Evidence:
  `findings/wave64/41-div-w32-p2sh-cleanstack/`.
- **SCR-112 has a named definitional divergence.** Pinned Lean
  `Der.isValidPubKey` checks only the header while Core `CPubKey::Set` also
  enforces the promised length; `pk = [0x02]` is the one-byte witness.
  With the real parser the verdict coincides, so this is a gate-level seam,
  not a consensus split. Evidence: `findings/wave64/25-scr-112/`,
  `findings/wave64/60-cpubkey-validity/`.
- **SCR-043 is inapplicable at the interpreter level.**
  `MAX_PUBKEYS_PER_MULTI_A=999` is a miniscript/wallet construction constant;
  the pinned interpreter never reads it, and the Lean tree has no Miniscript
  parser. The census `consensus: true` flag is inconsistent with the row text;
  `rules.yaml` is generated and was not hand-edited. Evidence:
  `findings/coverage/SCR-043-miniscript-bound.md`.
- **SCR-142 cannot prove the historical taproot height window at this pin.**
  `validation.cpp:2261` sets `P2SH|WITNESS|TAPROOT` unconditionally; only
  hash-keyed exceptions replace it. Heights 709631 and 709632 are identical
  at the pin, and the tape has no block-height/hash channel. Evidence:
  `findings/wave64/32-scr-142/`.
- **SAW runner classification is hardened.** The wave64 BIP143 audit found
  shared runners can print `STATUS=saw-green` after an unknown-function error.
  `update_ledger.py` now rejects `Could not find definition`, `Stack trace`,
  `Symbolic execution failed`, `Error during`, `Aborted`, and `panic` in
  addition to `Proof failed`/`saw: error`. No existing green row was demoted
  by this check. Evidence: `findings/wave64/49-bip143-layout/`.
- **Alive2/SAW evidence quality is not uniformly hardened.** The wave64
  nondeterminism audit measured 118/141 Alive2 greens without
  `--always-verify` and at the default 10 s budget, and 114/141 SAW greens
  using `abc`; one raw `-O1` control was deterministically vacuous (2 SMT
  queries, `correct`) and became `incorrect` after `opt -O2` (34 queries),
  with a native driver returning 64 vs 32. This does **not** re-adjudicate
  the recorded rows, but it is an open evidence-quality finding: a green
  marker alone is not a proof of non-vacuity. The recommended hardened
  recipe is `opt -O2`, `--always-verify`, explicit SMT budget, and parsed
  `Num queries > 0` / `Num timeout: 0` / `Num skips: 0`. Evidence:
  `findings/wave64/52-tool-nondeterminism/`.
- **Certificate portability is audited in a clean checkout.** The wave64
  checker replays all cell certificates plus manifests from a detached
  worktree; stale/absolute/build-artifact manifest entries were cleaned and
  moved to explicit `EXTERNAL-HASHES.txt` / `HISTORICAL-PROPOSAL-HASHES.txt`
  records. Evidence: `findings/wave64/51-cert-repro-hardening/`.
- **P-CORE-01 remains PROPOSED.** The amended exception-preserving form is
  compiled and differentially exercised in a bounded lane, but it is not used
  by any green cell; the catch-deleting form must not be adopted for a
  behavioral claim. Evidence: `findings/wave64/45-e5-exceptions-pcore01/`.
- **R remains an E0-only behavioral lane.** The pinned rustc 1.95 / LLVM-22
  module is not Alive2-ingestible; the typed-error wrapper is an off-pin
  proposal. Evidence: `findings/wave64/50-r-harness-typed-error/`.

### What is *not* claimed

- No unconditional Lean == Core or C == L == R statement. The matrix claim is
  conditional on the pinned front-ends, Alive2/SAW semantics, the shims, the
  twin/translations, and same-crypto.
- No whole-engine `VerifyScript`/`EvalScript` proof. E5 is a scoped residual:
  the symbolic dispatch loop, heap/allocator refinement, exception edges, and
  guard variables remain open.
- R has no admissible proof-lane artifact. R behavioral E0 passes; R proof
  cells do not.
- No mutation PASS. E2 is 4/4 required; E3 is 2/5; E4 is 3/5. All wave64 E2
  kills include a model-site application; E3/E4 kills are L-leg
  transliteration sites and do not satisfy the full site pairing.
- Crypto is abstracted on both legs; see `docs/DECISION-lax-ecdsa.md`. No
  libsecp256k1-internals claim.
- No Lean-kernel theorem. Results are evidence-tier; the Lean model is a
  provenance/rule source, not a kernel-checked LLVM semantics.

## Reproduce

```sh
cd spec/equiv
make pins
make e0
make gate-ir-pin
make equiv
python3 results/scripts/coverage_report.py --strict
python3 findings/wave64/51-cert-repro-hardening/tools/cert_repro_check.py --rev HEAD --fuzz 0
make gate-repro
```

The matrix is `results/matrix.md`; the complete non-green disposition index
is `findings/coverage/F-E6-GAPS.md`. The trust base is `docs/TRUST-BASE.md`.

## Cell → ledger rule

`results/scripts/update_ledger.py` is the supported updater. A row becomes
green only when a valid cell lists it and the raw `alive2/result.txt` and
`saw/result.txt` both contain the success marker. A partial-coverage cell can
be tool-green without promoting its row; the ledger keeps it gap unless the
cell says `scr_row_coverage: full` and the updater derives green. The updater
uses **per-row** coverage bullets, so a partial bullet for one row does not
demote a sibling row that is fully covered by the same cell.

## Artifacts

| Artifact | Purpose |
|---|---|
| `spec/db/equiv-cells.yaml` | 183-row SCR coverage ledger |
| `results/matrix.md` | generated per-family matrix, trust base, cell links |
| `results/STATUS.md` | this checkpoint |
| `findings/coverage/F-E6-GAPS.md` | every non-green row and disposition |
| `findings/e2/report.md`, `findings/e3/report.md`, `findings/e4/report.md` | family attempts and limits |
| `findings/e5/E5-RESIDUAL.md` | whole-function residual |
| `findings/ir/report.md` | 15-TU closure and tool-ingestion findings |
| `cells/_redteam/MUTATIONS.md`, `cells/_redteam/runs/`, `cells/_redteam/AUDIT-ADJUDICATION.md` | mutation catalogue, raw runs, adjudication |
| `contract/CHANGELOG.md` | contract v2 → v3 re-pin |
| `docs/TRUST-BASE.md`, `docs/STATE.md` | premises and current state |
