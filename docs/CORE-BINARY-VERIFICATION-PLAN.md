# Core binary verification plan (script engine) — v2, LLVM-first

Status: SUPERSEDED FOR EXECUTION (2026-10-19). The active plan is
`docs/LLVM-EQUIVALENCE-PLAN.md`, which narrows scope to the three-leg
LLVM IR equivalence campaign. This document is retained as program
context (impossibility ledger, phase history, fleet rationale).

Original status: PLAN (2026-10-19, rev 2). This revision replaces the v1 strategy.
v1 treated "no official C++ semantics" as a wall; v2 corrects that: the
wall only exists for *source-level C++ proofs of Core's code*. Compiling
to **LLVM IR with a pinned clang** makes the front-end definitional, and
mature equivalence instruments (Alive2, SAW) operate at exactly that
layer. The normative reference is unchanged: Bitcoin Core v32.99 @
`cce32b168`.

Nothing below is implemented yet. Every phase states what it proves and
what remains trusted.

---

## 1. What actually blocks us (revised ledger)

### B1. Source-level C++ proof of Core's interpreter — blocked, and not worth unblocking

There is no official formal C++ semantics, but there *are* academic ones.
The problem is fit, not existence:

| Project | Semantics | Why it does not accept `interpreter.cpp` |
|---|---|---|
| CompCertCPP (Ramananandro et al., Coq) | C++ object model subset (construction/destruction, inheritance) | No templates, no exceptions, no STL; Core uses all three (`prevector`, `scriptnum_error` thrown/caught inside `EvalScript`, `span`) |
| K framework C semantics | Full C, executable | C only, not C++ |
| Norrish HOL C++ model | C++ data types, partial, old | Never completed to a verification workflow |
| FormalSpecCpp (2025) | LLM-generated spec *dataset* | Benchmark data, not a semantics to verify against |

Bringing `interpreter.cpp` into any of these subsets is a rewrite, not a
"trivial modification" — so per the project preference we do **not**
modify Core's source. Restricted-subset semantics remain relevant only
for a *twin* we generate ourselves (Phase 2).

**What replaces it:** clang is the definitional C++→LLVM front-end. We pin
the exact clang version and flags; the IR is the shared substrate for
everything downstream. C++ semantics questions collapse into "what does
pinned-clang emit", which is reproducible and hashable.

### B2. UB is a premise we check, not a gap

v1 called undefined behaviour a definitional gap. Wrong disposition: it is
a *checkable premise with a bug-report protocol*:

- Run the UBSan-instrumented Core build over the full corpus + fuzz lanes.
- Alive2 detects UB in every equivalence cell it checks.
- **Any UB found in `interpreter.cpp` (or `script.cpp`/`scriptnum`) is an
  upstream Bitcoin Core bug to surface and fix** — that is a deliverable
  of this project, not an obstacle. (Likely clean — this code is heavily
  audited — but `prevector`'s raw-memory tricks and CScriptNum overflow
  arithmetic are the places to watch.)

### B3. The crypto seam — still a wall, now with a clean interface

libsecp256k1 (`__int128`, per-platform asm) stays out of scope
(`docs/DECISION-lax-ecdsa.md`). New alignment: SAW's override mechanism
lets us replace the `BaseSignatureChecker` callbacks with symbolic
functions during equivalence proofs — the same seam decision, expressed
at the proof level. Taproot key-path and checksig cells bottom out there
and are labelled unjudged, exactly as in the census today.

### B4. SMT discharge is not Lean-kernel proof — three mitigations

- SAW can export proofs to Coq/Rocq for independent replay.
- Equivalence cells record solver, version, query size, and result as
  certificates (evidence tier, like the conformance records).
- Stretch (Phase 4a): a Lean-native semantics for an LLVM IR subset would
  eventually let cells be replayed in the Lean kernel. No such thing
  exists today (Vellvm is Coq; Isabelle/LLVM is Isabelle). Building one
  is a genuine research contribution, not a dependency.

### B5. Pin drift — unchanged

Every result is valid for one build of one commit. Binary/IR lanes add
compiler+flags pins to the census pin discipline (a new gate, like
`anchor_pin_check.py`).

**Consequence — the headline claim, revised:** a conditional theorem with
*mechanized* premises:

> For all scripts `s`, contexts `c`: if pinned build config `K` is used
> and trusted components `T = {clang-K, Alive2/SAW + SMT, extraction
> generator}` are sound, then `CoreIR_K(s, c) ≡ Twin(s, c) ≡ M(s, c)`,
> where `M` is the Lean model — with `M ≡ Twin` proved in the Lean
> kernel, `Twin ≡ CoreIR` discharged at LLVM level with recorded
> certificates (optionally Coq-replayed), and every residual filed.

---

## 2. The three legs

| Leg | Artifact | Verification status |
|---|---|---|
| **Core** | `libbitcoin_consensus` / interpreter compiled to pinned LLVM IR | reference (the thing being checked) |
| **Twin** | C (or Rust) extracted from the Lean model's verified IL | `M ≡ Twin` proved in Lean; extraction mechanical |
| **rbitcoin** | reardencode's pure-Rust engine (independent implementation) | triangulation: its own Core-differential harness exists (`script-oracle/`) |

rbitcoin matters for three reasons: (1) its `script-oracle/verify.cpp` is
a ready-made C-ABI oracle harness around Core's real `VerifyScript`
(checker, witness, flags wired) — the exact Phase-0 pattern, MIT/Apache
dual-licensed for reuse with attribution; (2) rustc also emits LLVM IR,
so rbitcoin enters the same equivalence lane as Core; (3) Rust's UB story
is checkable with Miri, and Kani gives bounded bit-precise proofs of its
engine directly. Triangulating Lean ⇔ rbitcoin ⇔ Core with two
LLVM-level legs and one Lean-kernel leg is much harder to fool than any
single pair.

---

## 3. Phases (revised)

### Phase 0 — Oracle bridge + UB clearance (days)

- **P0.1** Core oracle: build from the pin with a pinned clang; adapt the
  `verify.cpp` C-ABI shim pattern (attribution to reardencode/rbitcoin)
  so the harness adds no logic.
- **P0.2** Lean runner interop: same byte-exact schema as `l2/scr`
  (script, flags, tx context, witness) so the existing corpora replay
  without regeneration.
- **P0.3** Tier-0 run: 1258 `script_tests` + 1788 L2-SCR rows, Core-oracle
  vs Lean. Expected: all AGREE except the known taproot/EC-seam rows.
- **P0.4** UB clearance: UBSan-instrumented Core build over the same
  corpus + the fuzz generators; findings become upstream-issue drafts;
  "UB-clean on corpus" becomes a recorded premise.
- **P0.5** rbitcoin leg: clone at a pinned commit; run its script-oracle
  pattern with our corpus; land `spec/data/l2/scrbin/` with three-oracle
  records (Core / Lean / rbitcoin).

### Phase 1 — Lean-side anchor (unchanged from v1)

- **P1.1–P1.3** Define imperative IL; prove `evalFrom` ↔ IL simulation
  (forward + backward; fuel via `FuelStability`). Every SCR row statement
  is preserved by the translation.
- **P1.4** SCR debt: 20 def-target rows get theorem faces (DEEP-A
  pattern), 6 residuals (SCR-030/066/067/070/074/086) closed or
  re-scoped, SCR-054/055 target drift fixed.
- **P1.5** Census integration: `BitcoinProofs.Refinement.*` in the
  default closure, axiom-pinned, gates green.

### Phase 2 — Twin extraction

- **P2.1** Evaluate verified-extraction options for the model side
  (LambdaClass Research ZK equality-saturation extraction, Feb 2026, is
  the candidate; fallback: mechanical generator + independent checker
  script that diffs twin C against the IL).
- **P2.2** Emit the twin in C (CompCert-subset if we want the optional
  verified-compile path; plain C otherwise) and/or Rust.
- **P2.3** Compile twin and Core with the *same pinned clang* to LLVM IR
  at `-O0`/`-O1` (record choice; `-O0` keeps the switch structure
  legible, `-O1` is more realistic).

### Phase 3 — LLVM IR equivalence campaign (the centerpiece)

- **P3.1 SAW whole-function equivalence:** `llvm_verify` on
  `VerifyScript` (Core IR) against the twin, with the signature-checker
  callbacks overridden as symbolic functions (B3). Loop invariants over
  the `EvalScript` dispatch loop via compositional overrides. Export
  proofs to Rocq where feasible.
- **P3.2 Alive2 refinement cells:** per-opcode-family pairs (twin vs
  Core) — the switch arms are bounded-loop bodies, which is Alive2's
  sweet spot; each cell records UB findings, solver, and certificate.
- **P3.3 rbitcoin leg:** rbitcoin engine vs Core engine at LLVM IR
  (both same-clang where possible; rustc emits IR natively); Kani
  bounded proofs of rbitcoin engine properties (stack bounds, opcode
  counting); Miri UB clearance on the engine crate.
- **P3.4 Report + gates:** `docs/BINARY-EQUIVALENCE.md` — matrix
  (family × instrument × verdict), every divergence/unproved cell filed
  as a residual; new `gate-binary-pin` checking compiler+flags+commit
  pins; README/CLAIMS updated to the conditional theorem (§1).

### Phase 4 — research stretches (explicitly optional)

- **P4a** Lean-native LLVM IR subset semantics (would let SAW/Alive2
  cells replay in the Lean kernel; a publication-grade contribution).
- **P4b** Lifter-based refinement of Core's actual binary (one function,
  one build) — unchanged from v1.

---

## 4. Fleet

| Agent | Owns |
|---|---|
| ORACLE | P0: Core oracle, Lean interop, UBSan run, rbitcoin leg |
| IL-SEM | P1: IL definition + simulation proofs |
| SCR-DEBT | P1: def-target faces, residuals, drift fixes |
| TWIN | P2: extraction evaluation + generation |
| LLVM-EQ | P3.1–P3.2: SAW + Alive2 cells, certificates |
| RUST-LEG | P3.3: rbitcoin equivalence, Kani, Miri |
| LEDGER | census/gates/docs integration, claims discipline |
| REDTEAM | adversarial review of every phase exit; mutation-test the harnesses; attack the equivalence claims |

Rules unchanged: phase exits require REDTEAM sign-off; no claim text
lands without LEDGER review against `docs/CLAIMS.md`; every record
carries its tool pins.

## 5. Non-goals

- No verification of libsecp256k1; the seam stays (B3).
- No modification of Core's source; UB findings are reported upstream,
  not patched around.
- No unconditional Lean≡Core claim; the conditional form (§1) is the
  ceiling, with premises mechanically checked where possible.
- No change to the 726-row census denominator; new obligations get their
  own ledgers.
