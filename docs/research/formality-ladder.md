# Formality ladder and trust accounting

> Research note, 2026-10-16.
> Trust model, formality levels L0–L4, axiom/`native_decide`/`sorry` policy, and TCB inventory.

---

## Executive summary

1. We define a 5-rung **formality ladder L0–L4**; every rung has a machine-checkable CI criterion (`#print axioms` fingerprints, sorry-count grep, `#guard_msgs` pins, `leanchecker` replay). Nothing above L0 relies on prose claims.
2. **VERIFIED**: on Lean 4.34.1, `decide` is axiom-free; `native_decide` emits **one named axiom per computation** (`thm._native.native_decide.ax_N_M`) — the post-RFC-12216 machinery (lean4#12217, merged Jan 2026) is already in our toolchain; `Lean.ofReduceBool`/`Lean.trustCompiler` exist but are deprecated.
3. **VERIFIED**: a single wrong `@[implemented_by]` + `native_decide` manufactures a **kernel-checked `False`** (probe 4: `boom`). `native_decide` trust = the whole Lean compiler + every `implemented_by`/`extern` in scope. ⇒ Confine it to test code; never let `_native` axioms into theorem proofs.
4. **VERIFIED**: `partial def`s are **opaque to the kernel** (no equation lemmas, `rfl` and `decide` both fail; only `native_decide` evaluates them). ⇒ The consensus core must not use `partial`; use structural or well-founded recursion (both VERIFIED axiom-clean, kernel-checked termination).
5. **VERIFIED**: two *silent* sorry sources: a failed `decreasing_by` and error-recovery elaboration both export `sorryAx`-backed constants with only a stderr warning. The sorry protocol (§e) exists because of exactly these.
6. **VERIFIED**: `leanchecker` (independent kernel replay, built into Lean since 4.28.0) runs on our toolchain and is one command of CI. External checkers (Lean4Lean, nanoda, con-leche — the latter *proven consistent in Lean*, Aug 2026) are available for L4 cross-validation.
7. Mathlib's policy, researched: LEM + AC used freely (`Classical.choice` accepted; ~53% of mathlib declarations depend on choice), no `sorry` on master, `simpNF` linter, and a daily external axiom audit (nanoda) permitting exactly `{propext, Classical.choice, Quot.sound, Lean.trustCompiler}`.
8. Community-standard TCB publication (seL4, CompCert, Fiat-Crypto, modern Coq/Lean projects): an exhaustive, enumerated assumptions list + a version-pinned component table + a machine-checked axiom ledger. We propose `docs/TCB.md` + a generated axiom manifest.
9. Budgets (PROPOSED): user `axiom`s ≤ 20, each with rule-ID + justification; `_native.*` axioms = 0 under `Theorem/`; FFI = 0 in v1; sorry = per-milestone budget with `-- SORRY[BTC-nnnn]` tags.
10. Biggest *un-eliminable* trust items: Lean kernel + its compiler, the toolchain binary, the imported mathlib subset, and — peculiar to this project — **Bitcoin Core test data as ground truth** (a trust source most proof projects don't have; §c7).

---

## Key findings (with citations)

| # | Finding | Status | Source |
|---|---|---|---|
| K1 | `decide` (kernel reduction) adds **no axioms**; the proof term is `Eq.refl true : decide p = true` checked by the kernel's reflection path | VERIFIED (probe 1) | [V1 §decide], [V1 kernel source] |
| K2 | `native_decide` on 4.34.1 adds **one named axiom per invocation**, e.g. `'t_native' depends on axioms: [t_native._native.native_decide.ax_1_1]`; the axiom's type is the asserted equality (e.g. `decide (1+1=2) = true`), auditable per-instance; it propagates transitively | VERIFIED (probe 1) | [V1 Axioms], [V2 RFC 12216], [V3 PR 12217] |
| K3 | `Lean.ofReduceBool`/`Lean.trustCompiler` (old kernel-callback machinery) are **deprecated** in our version and removed in 4.35; `Lean.collectAxioms` historically failed to collect axioms-referenced-by-axioms (`trustCompiler` invisible) — fixed by the per-computation-axiom design | VERIFIED (probe 1 warnings) | [V3 PR 12217], [V4 issue 8840], [V5 Zulip heads-up] |
| K4 | A wrong `@[implemented_by]` replacement + `native_decide` yields theorems (even `False`) that are **kernel-valid**; every `implemented_by`/`extern` in scope becomes part of the TCB of any `_native`-axiom proof | VERIFIED (probe 4: `oops`, `boom`) | [V1 §On Lean.trustCompiler] |
| K5 | `unsafe` declarations are **kernel-rejected** in theorem statements ("invalid declaration, it uses unsafe declaration …") — unsafe code cannot silently enter proofs; `@[extern]` adds nothing to the logic | VERIFIED (probe 4) | probe 4 |
| K6 | Structural recursion and well-founded recursion produce axiom-clean definitions (WF adds only `propext, Quot.sound` via `omega`); termination is kernel-checked; `partial` defs are kernel-opaque: `rfl` fails, `decide` fails ("did not reduce to `isTrue`"), only `native_decide` works, and no equation lemmas exist in the environment | VERIFIED (probes 5, 5c) | [V1 §decide note on WF] |
| K7 | `sorry` ⇒ `sorryAx`; transitive; user `axiom`s appear verbatim in `#print axioms`; the standard trio is exactly `{propext, Classical.choice, Quot.sound}` and `Classical.em` pulls in all three | VERIFIED (probes 2, 3) | [V1 Validating a Lean Proof] |
| K8 | `leanchecker` (kernel replay of `.olean`s, detects "environment hacking") ships with the toolchain since 4.28.0 and runs on our probe module (exit 0); `#guard_msgs in #print axioms` makes an axiom fingerprint a *build-enforced* invariant | VERIFIED (probe 6) | [V6 lean4checker], [V1 Validating], [V7 MathFin AxiomAudit] |
| K9 | Mathlib: "everything in the master branch compiles without errors, and there are no `sorry`s"; LEM/AC used freely (explicit policy note); `detectClassical` linter exists for choice-minimization audits; a choice-free experiment (PR 35685) shows 53.1% of declarations depend on `Classical.choice`; daily nanoda check permits `{propext, Classical.choice, Quot.sound, Lean.trustCompiler}` | Researched | [V8 contribute], [V9 mathlib3 notes], [V10 Zulip restricting-axioms], [V11 PR 35685], [V12 nanoda check] |
| K10 | Simp risk is a *statement/normal-form* risk, not a kernel-soundness risk: simp output is kernel-checked; mathlib's answer is the `simpNF` linter (dead/duplicated/looping simp lemmas) | Researched | [V13 simpNF linter], [V14 simp doc] |
| K11 | seL4 publishes an exhaustive assumption list (assembly ~340 lines, boot code ~1,200 lines, hardware, compiler+linker — the latter eliminated by binary verification) and states the two meta-assumptions: "HOL is consistent" and "our prover checks this particular proof correctly" | Researched | [V15 seL4 assumptions] |
| K12 | CompCert's TCB is itemized in a dedicated paper (arXiv:2201.10280): verified phase-3 + parser; trusted-unverified: pre-parser, elaboration, printing, external assembler/linker, Coq extraction, OCaml toolchain | Researched | [V16 CompCert TCB], [V17 manual] |
| K13 | Fiat-Crypto keeps `Print Assumptions` clean by *hiding* IO primitives behind a Coq `Module Type` ("we pull a hack to get coqchk to not report these as axioms; all we care about is that there exists a model") — the acknowledged pattern for IO-boundary trust | Researched | [V18 Fiat-Crypto StandaloneHaskellMain.v] |
| K14 | IsabeLLM (arXiv:2601.07654, Jan 2026) verified Bitcoin PoW-protocol lemmas in Isabelle/HOL with LLM-generated proofs — Isabelle's LCF-kernel trust model is the comparison point; it covers the abstract protocol, not validation rules | Researched | [V19 IsabeLLM] |
| K15 | Mathlib's CI literally greps for `sorry` and fails the build; secondary literature calls `sorryAx` "unsoundness in disguise" and recommends grep + `#print axioms` parsing + toolchain pinning as the 4-point audit | Researched | [V20 proofspath], [V8] |

---

## Detailed analysis

### (a) The formality ladder

Each rung is defined by a **machine-checkable criterion** — a command whose exit status is the claim — and by **what failure modes it excludes**. Milestone mapping to the roadmap's M0–M6 is indicative, to be reconciled with the roadmap report.

| Level | Name | Criterion (CI-enforced) | Failure modes excluded | Milestone |
|---|---|---|---|---|
| **L0** | Executable model | `lake build` green; conformance harness passes Core test vectors; `leanchecker` replay clean; **every** `sorry` carries a `-- SORRY[BTC-nnnn]` tag (grep-enforced); `unsafe`/`partial`/`@[implemented_by]`/`@[extern]` inventoried by grep and counted | "Spec doesn't run"; untagged silent gaps; environment hacking; accidental `unsafe`/FFI | M0–M1 |
| **L1** | Invalid states unrepresentable | L0 + constructors/`Subtype`/refined invariants for the cheap invariants (amounts in range, `BIP341` tagged-hash domain separation, witness-count consistency); grep gate: `native_decide` **only under `Test/`**; a rule-ID comment above every def | Whole classes of "model bug" failures (e.g. 21M-cap overflow impossible by type); logic-level trust still = elaborator | M2 |
| **L2** | Managed sorry-budget proofs | L1 + key theorems proved with a **declared sorry budget per milestone** (e.g. M3: ≤ 25); CI computes sorryAx count from `#print axioms` over the theorem manifest; axiom set of each portfolio theorem ⊆ `{propext, Classical.choice, Quot.sound, sorryAx}` + declared user axioms; axiom fingerprint of every theorem recorded in a generated manifest (`TheoremManifest.md`) | "The theorem list grew a silent hole"; drift of axiom usage; regression of proofs into sorries unnoticed | M3–M4 |
| **L3** | Sorry-free portfolio | L2 with **sorryAx count = 0** over the T1–T3 portfolio (the theorem portfolio's list: per-rule invariants → ledger conservation/no-inflation → spec↔Core conformance lemmas); each headline theorem pinned by `#guard_msgs in #print axioms` (VERIFIED: this fails the build on drift); `leanchecker --fresh` on all modules | Incomplete proofs; `sorryAx` anywhere in the transitive deps of a headline theorem | M5 |
| **L4** | Minimal-axiom endgame | L3 + user-axiom inventory ≤ 20, each with a doc-string justification and a rule-ID; `_native.*` axioms = 0 anywhere under `Theorem/`; external-checker cross-validation of the full export (comparator + nanoda or Lean4Lean / con-leche); mathlib pin re-audited on toolchain updates | Kernel-adjacent bugs (elaborator/import handling) caught by second checker; dishonest environment manipulation; axiom creep | M6 |

Notes:
- The **`decide`-vs-`native_decide` policy** is the load-bearing discipline: `decide` (kernel) is free; `native_decide` adds compiler trust, so it is a *testing* tool, never a proof tool. PROPOSED: lint that `Theorem/` (and `Consensus/`) files contain no `native_decide` and no `_native` axioms in `#print axioms` output.
- `native_decide` usage policy in CI: allowed in `Test/` for heavy conformance checks (e.g. SHA-256 of long strings, script runs) **plus** a differential rule: every `native_decide` conformance check that is also expressible kernel-side gets a sampled `decide` cross-check on small inputs (catches compiler/spec divergence early, cf. the unsafe/implemented_by probe).
- L1's "invalid states unrepresentable" is deliberately *cheap-where-possible*: it buys type-level exclusion of entire CVE classes (e.g. the CVE-motivated overflow rules become non-expressible states) at zero proof cost.

### (b) Axiom policy — what each Lean trust primitive introduces

All of the following are VERIFIED on 4.34.1 unless noted.

**User `axiom` declarations.** Appear verbatim in `#print axioms` of dependents (probe 2: `[btcAxOracle]`). Every instance is a hole in the logic that the kernel *cannot* check. Policy (PROPOSED): each axiom lives in `Consensus/Axioms.lean`, is named `btcAx*`, and carries a doc-comment with: rule-ID, why it's not provable (e.g. "encodes SHA-256 collision-freeness — not provable in-system"), what breaks if it's false, and a link to the tracking issue. Target ≤ 20 total; ideal v1 target: **0** in the consensus core (crypto "axioms" should instead be *definitions + conformance tests*, see the crypto layer).

**`native_decide` / `bv_decide` (native computation).** Since lean4#12217 (in our toolchain), each invocation introduces a bespoke axiom whose *type is the exact asserted proposition* (probe 1: `t_native._native.native_decide.ax_1_1`; the RFC shows the axiom type `decide (1 + 2 = 3) = true`). This is auditable per-instance (Ctrl-click jumps to the tactic call site [V5]). What you trust when you use it [V1]: the entire Lean compiler, the runtime (including GMP-backed `Nat` arithmetic — implementation-defined behavior), and every `@[implemented_by]`/`@[extern]` definition in scope. Probe 4 demonstrates the sharp edge: `@[implemented_by wrong] def one : Nat := 1` lets `native_decide` prove `one = 2`, and one `▸`-composition later, kernel-checked `False`. Verdict: `native_decide` = *trusted oracle per call site*, fine for tests, banned from theorem proofs. (`bv_decide` additionally trusts its certificate-verifier code, though not the SAT solver [V5].)

**The standard trio.** `propext` (propositional extensionality), `Quot.sound` (quotient soundness), `Classical.choice` (choice/LEM). The Lean documentation's own guidance: "The three axioms above are standard axioms of Lean's logic, and benign" [V1]. Community consensus: they are the accepted baseline — mathlib's daily external audit whitelists exactly these plus the (now-deprecated) `Lean.trustCompiler` [V12]; mathlib's style notes state LEM and AC are used freely [V9]; the "standard" `#print axioms` expectation published in many mathlib-adjacent projects is `[propext, Classical.choice, Quot.sound]` [V7]. Cost of `Classical.choice` in *our* setting: proofs stay valid, but any def that computes with choice-derived data becomes `noncomputable` [V21] — so classical reasoning in *proofs* is free; classical reasoning in *definitions* (e.g. building a `Decidable` instance via `open Classical`) silently kills kernel `decide`. PROPOSED rule: `Decidable` instances in the consensus core must be axiom-clean (`#print axioms` on the instance) so `decide` stays kernel-fast.

**`decide` vs `native_decide` in CI.** `decide` reduces the `Decidable` instance in the kernel (axiom-free, K1) but is slower and fails on well-founded-recursive definitions when reduction gets stuck [V1]; `decide +kernel` forces kernel-only; `decide +native` is `native_decide` in disguise (adds `_native` axioms). PROPOSED CI fingerprint: `decide` anywhere; `decide +native`/`native_decide` only in `Test/`; the `Test/` budget is unlimited *by count* but each use is visible in the `#print axioms` of test theorems.

**`unsafe` / `implemented_by` / `extern` (compiler trust).** `unsafe` declarations are second-class: the kernel rejects any *theorem* whose statement or proof uses an unsafe constant directly (probe 4) — they reach the logic only through safe wrappers, which is where the trust enters (the wrapper's safety claim is human-checked). `@[implemented_by]` and `@[extern]` are inert in the logic (probe 4: theorems about such defs are axiom-clean) but become TCB the moment native evaluation touches them (the unsafe/implemented_by probe). PROPOSED: a grep inventory of all three attributes per release, each with a one-line justification; zero `@[extern]` in v1 (target ZERO FFI — the spec is pure Lean; hashes/ECDSA are pure-Lean implementations, cf. the crypto layer).

**`@[simp]`-lemma bugs.** Simp is an *elaborator-side* rewriting engine: whatever it produces is ultimately kernel-checked, so a bad simp lemma cannot create an unsound proof — it can (i) never fire (LHS not in normal form), (ii) loop, (iii) shadow/duplicate, or (iv) be a *true but wrong-for-intent* lemma (statement bug — the proof risk here is that the theorem means something else than the reviewer thinks, which no kernel catches). Mathlib's institutional answer is the `simpNF`/`simpComm`/`simpVarHead` linter family, run in CI [V13]. Community view aligns: simp failures are maintenance risks; statement bugs are review risks [V10, V14]. PROPOSED: adopt the Batteries `simpNF` linter from day one; no `@[simp]` on consensus-core defs without a normal-form note.

**`partial` & well-founded recursion.** WF recursion: the termination proof is kernel-checked; definitions stay axiom-clean (probe 5: only `propext, Quot.sound` via `omega`'s proof terms) and equation lemmas (`wfLog2.eq_1`) are ordinary theorems. One caveat [V1, K1]: `decide` can get stuck reducing through WF definitions (it must unfold `WellFounded.fix`), so the executable core should prefer structural recursion where cheap. `partial`: probe 5c shows the environment contains *only* an opaque constant — `rfl` fails ("Not a definitional equality"), `decide` fails ("did not reduce to `isTrue` or `isFalse`"), no equation lemmas exist, and only `native_decide` evaluates it (probe 5c: `cNative` works via `_native` axiom). `partial` exists to avoid the `Inhabited`/termination-proof ceremony at the cost of **kernel opacity**. PROPOSED: `partial` is banned in `Consensus/` and `Theorem/`; permitted only in `Test/`-harness code, never under anything a theorem mentions.

**`IO` / monad purity boundaries.** Probe 6: `def ioConst : IO Nat := pure 42` and do-notation are **axiom-free** — `IO` is ordinary types (`EStateM`-based); the logic never trusts the runtime. The trust boundary is *operational*: when the harness `#eval`s or runs the compiled binary, you trust the Lean runtime to implement `IO.FS.readFile` etc. correctly. So: theorems are unaffected by IO; the *conformance claim* (harness reads a block file and feeds it to the pure spec) rests on the runtime + the file-decoding code, not the kernel. This is exactly Fiat-Crypto's acknowledged situation (K13), handled there by declaring IO primitives as model-justified axioms; in Lean we get it for free because `IO` is a library type, not a logic primitive. PROPOSED: consensus spec is 100% pure (no `IO` in any `Consensus/` def); `IO` appears only in `Harness/`; this makes the purity boundary greppable (`grep -n "IO " Consensus/` must be empty).

### (c) TCB inventory (the deliverable)

Layered TCB for "theorem T of btc-lean, as consumed by an end-user":

```
┌─────────────────────────────────────────────────────────────────────────┐
│ L7  Bitcoin ground truth (semi-trusted conformance vectors)             │
│     • Bitcoin Core @ pinned commit (upstream-track): the definition of "right" │
│     • Core test/ + data/ vectors (the conformance report corpus)                         │
│     • BIP corpus documents                                              │
│     Trust: Core has bugs too; conformance ≠ correctness of Core.        │
├─────────────────────────────────────────────────────────────────────────┤
│ L6  Process trust (CI gates, reports, review controls)       │
│     • sorry-grep, axiom manifest, guard_msgs pins, leanchecker          │
├─────────────────────────────────────────────────────────────────────────┤
│ L5  Our axiom declarations            [target ≤ 20, each justified]     │
│ L4b Our conformance harness (pure Lean + IO boundary, ZERO FFI in v1)   │
│ L4  btc-lean sources: Consensus/ defs + Theorem/ proofs                 │
│     (+ whitelisted @[implemented_by], no unsafe/partial in core)        │
├─────────────────────────────────────────────────────────────────────────┤
│ L3  mathlib (imported subset only)                                      │
│     • own policy: trio allowed, LEM/AC free, no sorry on master,        │
│       simpNF linting, daily external axiom audit                        │
├─────────────────────────────────────────────────────────────────────────┤
│ L2  Lean 4 elaborator / tactics / environment handling                  │
│     (bug here ⇒ wrong-but-typed decls; mitigated by L6 leanchecker)     │
│ L1b Lean compiler + runtime  — ONLY if _native axioms are accepted;     │
│     includes every @[implemented_by]/@[extern] in scope, GMP            │
│ L1  Lean 4 kernel (C++): type checking, defeq, proof irrelevance,       │
│     inductive/quot primitives; Nat kernel numerals bounded by guard     │
├─────────────────────────────────────────────────────────────────────────┤
│ L0  Toolchain & host: elan/lean/lake binaries (pinned lean-toolchain),  │
│     OS/hardware (the seL4 "assumptions" floor)                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Trust budget table** (see also Appendix B):

| # | TCB component | Trust basis | Budget / target | Audit mechanism |
|---|---|---|---|---|
| 1 | Lean 4.34.1 kernel | C++ implementation; de Moura/Moura lineage; external checkers exist (leanchecker built-in; Lean4Lean verified-capable; nanoda in Rust; con-leche proven-consistent) | 1, pinned by `lean-toolchain` | `leanchecker` in CI (VERIFIED working); L4: cross-check with 2nd checker |
| 2 | Lean compiler + runtime | Only trusted when `_native.*` axioms accepted | **0 `_native` axioms outside `Test/`** | `#print axioms` manifest; grep `native_decide` |
| 3 | elan/lean/lake binaries | Downloaded, pinned; residual trust | 1, pinned + hash-noted in release docs | reproducible build note (PROPOSED) |
| 4 | mathlib subset | Mathlib's own axiom policy (trio; no sorry; linted) | import list minimized; **pin exact mathlib rev**; import only needed modules (trust accounting's zero-dep-core decision interacts: keep `Consensus/` importable without mathlib) | `leanchecker`; import-graph lint (PROPOSED: forbid `import Mathlib` umbrella in core) |
| 5 | Our `axiom` declarations | Human justification, one per instance | **≤ 20 total; each with rule-ID + issue link** | `Consensus/Axioms.lean` is the single file; grep-able |
| 6 | FFI / `@[extern]` | n/a in v1 | **ZERO FFI in v1** | grep inventory per release |
| 7 | `unsafe` / `partial` / `@[implemented_by]` | compiler trust / kernel opacity | 0 in `Consensus/`+`Theorem/`; inventory elsewhere | grep + reviewer checklist |
| 8 | Conformance vectors (Core test data) | Bitcoin Core project's own testing; the *translation* of vectors into our harness is our code | Harness code under `Harness/` is axiom-clean, small, reviewed | differential testing vs `bitcoind` (the conformance report) |
| 9 | CI process | scripts in repo, reviewed | — | proof engineering |

**What the end-user of a headline theorem must be told** (the publishable statement, seL4-style [V15]): *"This theorem is machine-checked by the Lean 4.34.1 kernel (cross-checked by `leanchecker`), depends only on the standard axioms `{propext, Classical.choice, Quot.sound}` (see the per-theorem fingerprint in `TheoremManifest.md`), the pinned mathlib revision, and — for the conformance corollary only — the correctness of the pinned Bitcoin Core commit as captured by its test vectors. No FFI, no `native_decide` proofs, no user axioms were used."* That sentence should be *generated* by CI, not written by hand (claim-drift protection, cf. the axiom-ledger pattern of modern Coq/Lean projects [V22]).

### (d) Comparable discipline

- **seL4** [V15]: the gold standard of *honesty-by-enumeration*. Their assumptions page lists, exhaustively: ~340 lines of assembly, boot code (~1,200 lines), hardware, cache/TLB management, and — since binary verification — no compiler/linker. Plus two meta-assumptions (HOL consistent; prover checked this proof). They explicitly rank what to worry about: "If you are worried about the proof, be worried about the assumptions … They are much more likely to cause problems." Lesson for us: enumerate *everything*, including the embarrassing floor (hardware/toolchain), and state which parts were later *removed* from the TCB (compiler → removed via binary verification; for us: `native_decide` → removed via L3's no-`_native` policy).
- **CompCert** [V16, V17]: dedicated TCB paper (arXiv:2201.10280) itemizing verified vs trusted-unverified components (pre-parser, elaboration, printer, external assembler/linker, extraction, OCaml toolchain) — and *why* each unverified piece is hard to verify. Lesson: a TCB document should also say *why the residue exists* and what would remove it (their paper literally proposes next steps; our Open Questions § mirrors this).
- **Fiat-Crypto** [V18]: axiom discipline = keep `Print Assumptions` clean, push IO trust to explicitly-modeled primitives inside `Module Type`s justified by "there exists a model", and get correctness all the way to extracted C/assembly via proof-producing translation validators. Lesson: the IO/FFI boundary is where axiom hygiene gets creative; our Lean-native `IO`-as-library-type makes it simpler (§b).
- **mathlib** [V8–V12]: policy = trio allowed and used freely; no `sorry` on master (CI-grepped); `simpNF` linter; optional `detectClassical` linter for choice-minimization work; an out-of-tree daily audit (nanoda) checks every declaration's axioms against a whitelist — the closest existing thing to our `TheoremManifest.md`. The PR 35685 experiment shows even 53%-choice-dependency is treated as a reducible metric. Lesson: mathlib does NOT minimize axioms beyond the trio, but it *measures* them continuously. We can be stricter (leaner core, fewer choice deps) because our domain is computational.
- **Isabelle / IsabeLLM** [V19, V15]: Isabelle's LCF-style kernel ("engineered to minimise the code that needs to be trusted") + separate small checkers; IsabeLLM's Bitcoin-PoW proofs inherit exactly the seL4 trust model. Lesson: the LLM-generated-proof concern (proof engineering) is fully absorbed by the kernel — AI-written proofs cannot smuggle unsoundness past `#print axioms` discipline; they can only smuggle *wrong statements*, which the traceability matrix (the roadmap) addresses.
- **How to publish a TCB statement**: the observed community pattern (seL4 assumptions page; CompCert TCB paper; Fiat-Crypto README; modern ledger-style `TRUSTED_BASE.md` documents [V22]; MathFin's guard_msgs-invariant file [V7]) = (1) version-pinned component table, (2) exhaustive assumption list with per-item justification, (3) machine-enforced axiom ledger, (4) explicit "what this proof does NOT give" section. We propose all four for `docs/TCB.md`.

### (e) The sorry protocol

**VERIFIED motivation** (probes 2, 5, 5c): `sorry` ⇒ `sorryAx`, transitively, with only a stderr warning — the file type-checks and exports "theorems" as if proved. Two *silent* sources observed: (1) a failing `decreasing_by` silently downgrades the definition to `sorryAx`-backed (probe 5, first run: `'wfLog2' depends on axioms: [sorryAx]` from a tactic error); (2) elaboration error-recovery exports constants backed by `sorryAx` (probe 5c: `c0` after a `simp` error). An `admit`-style hole can hide anywhere a tactic block sits, including term-level `by …` inside definitions.

**Protocol (PROPOSED, with the enforcement mechanics VERIFIED where noted):**

1. **Tagging**: every `sorry` must be preceded on its line or the line above by `-- SORRY[BTC-nnnn]: one-line reason`. The `BTC-nnnn` is a tracking issue; unexplained sorries fail CI.
2. **CI grep gate** (mathlib's own pattern [V20]):
   ```bash
   # fail if a sorry has no tracking tag on the same or previous line
   grep -rn --include='*.lean' -B0 'sorry' Consensus/ Theorem/ | \
     grep -v 'SORRY\[' && exit 1 || true
   # fail on ANY sorry above the current milestone's budget
   SORRIES=$(grep -rc --include='*.lean' 'sorry' Consensus/ Theorem/ | awk -F: '{s+=$2} END {print s}')
   [ "$SORRIES" -le "$SORRY_BUDGET" ] || { echo "sorry budget exceeded: $SORRIES > $SORRY_BUDGET"; exit 1; }
   ```
   plus a sorry-count emitted as JSON per commit → the **dashboard** (sorry count over time, per directory, with budget line) — feeds proof engineering's CI report.
3. **Axiom manifest**: a CI job runs `#print axioms` (or `Lean.collectAxioms`) over every declaration named in `TheoremManifest.md` and diffs against the recorded fingerprint; any new axiom (including a fresh `_native.*` or `sorryAx`) fails the build. VERIFIED enforcement primitive: `#guard_msgs in #print axioms foo` breaks the build on drift (probe 6) — the MathFin pattern [V7] — usable for headline theorems without custom scripting.
4. **Warning-to-error**: CI parses `lean` output for `declaration uses 'sorry'` warnings and fails if the count exceeds the budget (belt-and-suspenders with the grep, since error-recovery sorries may have no literal `sorry` token — see silent source (2)).
5. **Linting the silent risks**:
   - failed `decreasing_by` / elaboration recovery: detectable as `sorryAx` in `#print axioms` of *every* new declaration — the manifest job (3) catches these automatically, which grep cannot;
   - `native_decide` outside `Test/`: grep + `_native` axiom check;
   - `Classical.choice` in computationally-relevant defs: adopt/derive a `detectClassical`-style linter (mathlib's exists [V10]) applied to `Decidable` instances in `Consensus/`;
   - `partial`/`unsafe`/`implemented_by`/`extern`: grep inventory per release (§c7).
6. **Milestone definitions**: *sorry-free milestone* for a portfolio tier (the theorem portfolio's T1–T3) = sorryAx-count 0 over that tier's declarations, two consecutive CI runs, and the manifest fingerprints regenerated+reviewed. Reverting to sorries after a milestone requires a maintainer-approved issue.

---

## Implications (for the other areas)

- **the model architecture**: the consensus core must avoid `partial` (kernel-opaque: kills `decide`, `rfl`, and kernel-level conformance evaluation — VERIFIED) and prefer structural recursion; WF recursion is acceptable but note `decide` reduction can get stuck through `WellFounded.fix` [V1]. Zero-dependency core layer is *axiom-cheap*: without mathlib, `Consensus/` can be trio-free or even fully axiom-free (`#print axioms` empty) — a strong publishable property.
- **the crypto layer**: "verified-vs-axiomatized" should be reframed: axiomatizing SHA-256 (as `opaque` + conformance-tested equations) spends *user-axiom* budget and blocks kernel `decide` on it; a pure-Lean implementation costs build time but is axiom-free and `decide`-able on small vectors, with `native_decide` conformance on large ones. The ladder's `_native`-in-`Test/`-only rule makes the second option strictly better for L3+.
- **the conformance report (conformance)**: `native_decide` is the right tool for heavy test vectors; every such test should also exist in a small `decide`-checked form (differential compiler/kernel cross-check, cf. a prior probe's `boom`).
- **the theorem portfolio**: each theorem in the draft portfolio gets an axiom *fingerprint target* now (trio / trio+declared / axiom-free), so L2→L3 progression is measurable per theorem, not just globally.
- **the roadmap**: map M-milestones to L-levels in the roadmap doc; the sorry budget should be a column of the milestone table.
- **proof engineering (AI-proof engineering)**: kernel + `#print axioms` + `leanchecker` + `#guard_msgs` pins make LLM-authored proofs safe against *unsoundness*; residual risk is *wrong statements*, handled by the traceability matrix and review protocol — cite IsabeLLM as precedent that LLM-generated proofs in an LCF-style kernel are kernel-absorbed.

## Open questions & risks

1. **`Classical.choice` creep in `Decidable` instances** (VERIFIED hazard class, V21): a `by classical` in an instance silently breaks `decide` later. Mitigation linter needs writing (small; mathlib's `detectClassical` is a template). Unresolved: do we forbid choice in `Consensus/` entirely (stronger, more work) or only in instances (cheaper)? → decide at M1.
2. **Toolchain churn**: 4.35.0 removes `Lean.trustCompiler` machinery and changes `_native` axiom naming details [V3]; our probes are version-pinned and the CI manifest must be regenerated on every toolchain bump (cheap, scripted).
3. **Mathlib import weight vs. axiom surface**: every mathlib import widens the transitive axiom surface (53% of mathlib depends on choice [V11]); the zero-dep core keeps `Consensus/` clean, but `Theorem/` will want mathlib. Open: does the L4 "minimal axiom" target allow `Classical.choice` for the ledger theorems? (Recommend: yes — trio is community-blessed [V1, V12]; L4's "minimal" refers to *user* axioms + no `_native` + no `sorryAx`.)
4. **Conformance vectors as a trust source**: Core test vectors cover what Core's authors tested; the theorem "our spec accepts exactly what Core accepts" is only as strong as vector coverage. Mitigation (the conformance report): differential fuzzing against `bitcoind`, and an explicit coverage statement in TCB.md (seL4-style honesty about what is *not* covered).
5. **`leanchecker` catches environment hacking but shares the kernel implementation** [V6] — it is replay, not an independent checker. True independence (nanoda in Rust, Lean4Lean in Lean, con-leche proven-consistent) is an L4 option; cost/benefit to be decided at M5.
6. **Native numerals**: kernel Nat reduction has a literal-size guard (`g_eager_reduce` bound in the kernel source [V1]); huge conformance constants (SHA-256 on long inputs) may be infeasible kernel-side — this is exactly the `native_decide`-in-tests niche; keep theorem statements free of giant closed terms.

## Recommendations

1. **Adopt the L0–L4 ladder** with the CI criteria of §a verbatim; make the ladder a column in the roadmap's milestone table.
2. **Write `docs/TCB.md` at M0** (not at the end) in the seL4/Fiat-Crypto style: component table (Appendix B), assumption list, "what we do NOT claim" — and generate the axiom-ledger section from CI.
3. **Enforce now, cheaply**: sorry-tag grep + `#guard_msgs in #print axioms` on headline theorems + `leanchecker` in CI. All three are VERIFIED-working one-liners on our toolchain.
4. **Ban `partial` in consensus/theorem code; ban `native_decide` outside `Test/`; zero FFI in v1; `unsafe` only in harness**, each enforced by grep inventory.
5. **User-axiom budget ≤ 20** with per-instance justification in `Consensus/Axioms.lean`; aim for 0 at L3.
6. **Pin toolchain + mathlib rev**; regenerate the axiom manifest on bump; note hashes in release docs.
7. **Add the sorry dashboard** (count over time, budget line, per-directory) to the repo's CI artifacts; coordinate format with proof engineering.
8. **Defer external-checker cross-validation (nanoda/Lean4Lean/con-leche) to L4/M5** — decide by measuring `leanchecker` runtime on the real project first.

---

## Appendix A — Sources

**Lean documentation / upstream (V-series):**
- [V1] Lean 4 Reference Manual, "Validating a Lean Proof" + "Axioms" + tactic reference (`lean-lang.org/doc/reference/latest/`) — standard trio guidance; `decide`/`decide +native`/`native_decide` semantics; `Lean.trustCompiler` note; leanchecker/comparator instructions.
- [V2] leanprover/lean4 RFC issue #12216, "One axiom per native computation".
- [V3] leanprover/lean4 PR #12217 (merged 2026-01-28), "feat: one axiom per native computation"; deprecates `ofReduceBool`/`trustCompiler` (removed 4.35.0).
- [V4] leanprover/lean4 issue #8840, "`Lean.collectAxioms` doesn't collect axioms referenced by axioms".
- [V5] Zulip #lean4, "Heads up: changes to native_decide (and bv_decide)" (2026-02).
- [V6] leanprover/lean4checker (deprecated; merged as `leanchecker` since v4.28.0); Lean 4.28.0 release notes; Lean Kernel Arena (nanoda); leanprover/con-leche (proven-consistent checker, 2026-08); Carneiro, "Lean4Lean: Verifying a Typechecker for Lean, in Lean", arXiv:2403.14064.
- [V21] Lean 4 TPiL ch. 12, "Axioms and Computation" (choice ⇒ `noncomputable`; `Quot.sound`; Diaconescu).
- [V1-kernel] `lean4/src/kernel/type_checker.cpp` — `decide` reflection path; Nat-literal reduction guard.

**mathlib / community policy (V-series):**
- [V7] formal-applied-math/formal-mathfin `MathFin/AxiomAudit.lean` + CONTRIBUTING — `#guard_msgs in #print axioms` build-enforced axiom invariant.
- [V8] leanprover-community "How to contribute to mathlib" — "master compiles without errors, and there are no `sorry`s".
- [V9] mathlib3 docs, notes page (`decidable` namespace, LEM/AC policy).
- [V10] Zulip #lean4 "restricting axioms" (2025-01) — `detectClassical` linter source.
- [V11] mathlib4 PR #35685 "reduce the use of Classical.choice" — 53.1% of declarations depend on choice; choice-minimization tooling.
- [V12] Zulip #mathlib4 "Why does the daily Nanoda check allow `Lean.trustCompiler`?" — permitted-axioms JSON for mathlib's daily external audit.
- [V13] Batteries.Tactic.Lint.Simp docs (`simpNF`, `simpComm`, `simpVarHead`) + Zulip simpNF threads.
- [V14] leanprover-community "Simp" extras page (simp normal form doctrine).
- [V20] proofspath.com, "Sorry-Free Discipline and Axiom Auditing in Lean 4" (mathlib CI sorry-grep; "sorryAx is unsoundness in disguise").

**Comparable projects (V-series):**
- [V15] sel4.systems/Verification/assumptions.html + proofs.html; Klein et al., CACM 2010/2020 — TCB assumption enumeration; binary verification removing compiler trust.
- [V16] Leroy, "The Trusted Computing Base of the CompCert Verified Compiler", arXiv:2201.10280 (2022).
- [V17] CompCert manual ch. 1 (verified phase 3 + parser; unverified front-end, printing, assembler, linker; Valex validation).
- [V18] mit-plv/fiat-crypto `src/StandaloneHaskellMain.v` / `StandaloneOCamlMain.v` ("pull a hack to get coqchk to not report these as axioms"); PEPM 2023 overview.
- [V19] Jones & Knottenbelt, "Towards Automating Blockchain Consensus Verification with IsabeLLM", arXiv:2601.07654 (Jan 2026).
- [V22] Example of the modern ledger-style TCB document pattern (version-pinned component table + machine-checked axiom ledger + claim-drift gate): almi.de/almide `proofs/TRUSTED_BASE.md`.


## Appendix B — Trust-budget table & probe transcript

### B.1 Trust budget (summary form; full analysis §c)

| Layer | Item | v1 target | Endgame (L4) | Enforced by |
|---|---|---|---|---|
| Logic | user `axiom`s | ≤ 20, justified | ≤ 20 (aim 0 in core) | single-file + manifest |
| Logic | `sorryAx` | budgeted per milestone | 0 | grep + warning-parse + manifest |
| Logic | `_native.*` axioms | `Test/` only | 0 under `Theorem/` | grep + manifest |
| Logic | standard trio | allowed | allowed (community-blessed) | manifest fingerprint |
| Tools | FFI / `@[extern]` | 0 | 0 in spec | grep inventory |
| Tools | `unsafe` | harness only | harness only | grep + kernel rejection (VERIFIED) |
| Tools | `partial` | 0 in core | 0 in core | grep |
| Tools | `@[implemented_by]` | inventory + justification | same | grep + probe-4-style differential test |
| Deps | mathlib | pinned rev, minimal imports | pinned + import-graph lint | lockfile + CI |
| Tools | toolchain (lean/lake/elan/leanchecker) | pinned 4.34.1 | pinned + 2nd checker | `lean-toolchain`, leanchecker CI |
| Data | Core vectors + BIP corpus | pinned Core commit | pinned + fuzz-differential | the conformance report harness |
| Meta | CI process scripts | reviewed, in-repo | same | proof engineering |

### B.2 native_decide probe transcript (VERIFIED, Lean 4.34.1, commit 5045d005)

```
$ lean --version
Lean (version 4.34.1, x86_64-unknown-linux-gnu, commit 5045d0056413266e57c625dcd7c365b10e377c52, Release)

--- probe1: decide vs native_decide ---
't_decide' does not depend on any axioms                        # by decide
't_native' depends on axioms: [t_native._native.native_decide.ax_1_1]   # by native_decide
warning: `Lean.ofReduceBool` has been deprecated: in-kernel native reduction is deprecated;
         assert native evaluations with axioms instead
Lean.ofReduceBool : ∀ (a b : Bool), Lean.reduceBool a = b → a = b
warning: `Lean.trustCompiler` has been deprecated: ...
Lean.trustCompiler : True
't_top' depends on axioms: [t_native._native.native_decide.ax_1_1]      # transitive propagation
# `decide +kernel` and `decide +native` both accepted

--- probe2: user axioms & sorry ---
'usesBtcAx' depends on axioms: [btcAxOracle]                    # user axiom, verbatim
warning: declaration uses `sorry`
'hasSorry' depends on axioms: [sorryAx]
'hasSorry2' depends on axioms: [sorryAx]                        # sorry behind refine skeleton
'topOfSorry' depends on axioms: [sorryAx]                       # transitive through lemma

--- probe3: standard trio & automation ---
'peUse' depends on axioms: [propext]                            # propext (direct)
'qUse' depends on axioms: [Quot.sound]                          # Quot.sound (direct)
'Classical.em' depends on axioms: [propext, Classical.choice, Quot.sound]
'emUse' depends on axioms: [propext, Classical.choice, Quot.sound]
'simpUse' depends on axioms: [propext]                          # simp (a + 0 = a)
'omegaUse' depends on axioms: [propext, Quot.sound]             # omega
'rflUse' does not depend on any axioms
'peq' depends on axioms: [propext]                              # simp (True ∧ True) = True

--- probe4: implemented_by / unsafe / extern ---
'slowIbCorrect' does not depend on any axioms          # theorem about @[implemented_by] def (kernel proof)
'nativeOnIb' depends on axioms: [nativeOnIb._native.native_decide.ax_1_1]
'oops' depends on axioms: [oops._native.native_decide.ax_1_1]   # WRONG implemented_by: proves one = 2
'boom' depends on axioms: [oops._native.native_decide.ax_1_1]   # ... and False, kernel-checked
error: (kernel) invalid declaration, it uses unsafe declaration 'unsafeLen'
        # unsafe CANNOT appear in a theorem directly
'unsafeAlsoProves' depends on axioms: [sorryAx, unsafeAlsoProves]  # error-recovery sorry (silent-risk exhibit)
'extThm' does not depend on any axioms                 # @[extern] inert in logic

--- probe5: recursion ---
'sumTo' does not depend on any axioms                  # structural recursion
'sumTo.eq_def' does not depend on any axioms
'wfLog2' depends on axioms: [propext, Quot.sound]      # WF recursion (omega's proof terms)
'wfLog2.eq_1' depends on axioms: [propext, Quot.sound]
# FIRST RUN (broken decreasing_by): 'wfLog2' depends on axioms: [sorryAx]  <- silent downgrade!
'collatzSteps' does not depend on any axioms           # partial def declaration itself
# probe5c: environment contains ONLY `collatzSteps` (no equation lemmas);
#   `rfl` fails: "Not a definitional equality: collatzSteps 0 is not definitionally equal to 0"
#   `decide` fails: "did not reduce to `isTrue` or `isFalse`"
'cNative' depends on axioms: [cNative._native.native_decide.ax_1_1]   # native evaluation works

--- probe6: IO / guard_msgs / leanchecker ---
'ioConst' does not depend on any axioms                # IO defs are axiom-free
'ioBind' does not depend on any axioms
IO.FS.readFile : System.FilePath → IO String
'nine' does not depend on any axioms                   # with /-- info: ... -/ #guard_msgs pin, build green
# (a wrong #guard_msgs expectation was shown to FAIL the build)

$ lean -o probe6.olean probe6-io-guard.lean && LEAN_PATH=$PWD leanchecker probe6
$ echo $?
0                                                       # kernel replay of the module: clean
```
