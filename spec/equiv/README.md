# Three-leg LLVM IR equivalence — `spec/equiv`

**Status: E0 PASS; E1 PASS; E2–E5 attempted/partial; E6 evidence-tier closure published.** This directory is a self-contained workstream
inside `btc-lean-public`. It exists so that anyone — reviewer, auditor, or
future agent — can evaluate the claim without reading the rest of the repo.

---

## Mission

Build **evidence-tier** results, at the **LLVM IR level**, for agreement among
three implementations of the Bitcoin script engine:

| Leg | Implementation | Lowered by |
|---|---|---|
| **C** | Bitcoin Core v32.99 @ `cce32b168` (`interpreter.cpp` + deps) | pinned clang |
| **L** | a twin generated from the btc-lean Lean model | same pinned clang |
| **R** | rbitcoin (reardencode/rbitcoin), pure-Rust engine | pinned rustc |

For a fixed harness contract (§4), the target obligation is mutual refinement
`L ⊑ C`, `C ⊑ L`, `R ⊑ C`, `C ⊑ R`; transitivity would then give `L ≡ R`.
At the E6 checkpoint only bounded cells and partial family cells are proved,
so **no unconditional `L ≡ R` or `Lean == Core` claim is made**; the published
matrix is conditional and the 183-row ledger files every non-green row.

**Both tools are attempted on every cell:** Alive2 and SAW. Where one cannot
express a cell, the other carries it; where neither can, the cell is filed as
a gap with the blocking IR feature named. No silent omissions.

## The claim, stated honestly

A **conditional** statement:

> For all inputs in the harness domain, if the pinned front-ends, the LLVM IR
> semantics implemented by Alive2 and SAW/Crucible, the SMT solvers, the
> shims, the twin generator, and the same-crypto premise are sound, then the
> three engines agree on verdict and error kind.

It is **not** a Lean-kernel theorem (no Lean-native LLVM IR semantics exists
today), **not** a machine-code/backend result, and **not** a claim about
libsecp256k1 internals. The Lean kernel contributes the twin's provenance and
the 183 SCR rule rows used as the coverage oracle.

## What would falsify it

- A counterexample from Alive2/SAW on any green cell.
- A differential divergence (Core vs Lean vs Rust) on the contract domain.
- A SCR row with no covering cell and no filed gap.
- A patch in `patches/` that changes observed behavior on the corpus.
- Tool-version drift breaking `gate-ir-pin`.

---

## 2. Directory map

```
spec/equiv/
  README.md                 # this file — evaluation entry point
  GOAL.md                   # long-running objective, fleet, parallelization protocol
  PINS.lock                 # every tool/commit/IR version
  Makefile                  # e0 / equiv / gate-ir-pin
  contract/                 # ABI, tape format, error enum, corpus schema
  shims/core/               # extern "C" shim over Core's VerifyScript
  shims/twin/               # shim over the Lean-derived twin
  shims/rust/               # shim over rbitcoin's engine
  twin/                     # twin generator (Lean model → C/C++), or transliteration
  cells/<family>/           # per-cell specs + SAW/Alive2 invocations + certificates
  patches/                  # small, tracked, behavior-preserving Core patches only
  findings/                 # UB reports, counterexamples, divergences, tool reports
  tools/                    # install scripts, capability matrix, gate_ir_pin.py, coverage.py
  results/                  # generated matrix + per-cell records
```

## 3. The three legs

**C (reference).** Build Core at the pin with the pinned clang; emit bitcode
for `VerifyScript`, `EvalScript`, `VerifyWitnessProgram`,
`ExecuteWitnessScript`, `CheckLockTime`, `CheckSequence`, `CastToBool`,
CScriptNum, `GetScriptOp`, signature-encoding checks, sigop counting and
dependencies. `-O0` is primary (dispatch legible); `-O1` is a robustness lane.

**L (Lean twin).** The Lean model (`spec/core/Bitcoin/Interpreter/Defs.lean`,
`stepBody`/`evalFrom`) is the source of truth. Preferred: a small, audited,
deterministic **generator** emits a C/C++ twin from the model's imperative
structure. Fallback: a hand-transliterated twin validated against the Lean
runner; this downgrades the L-leg link to "reviewed transliteration" and is
labelled as such. Compiled by the same clang as C.

**R (rbitcoin).** Pin a commit; pin rustc; emit LLVM IR. Determine the crypto
path (secp256k1 bindings vs pure Rust) and the panic policy. LLVM-version
skew between rustc and SAW is an E0 decision; if it cannot be reconciled, the
R leg runs Alive2-only and the gap is filed.

## 4. The harness contract (summary; normative text in `contract/ABI.md`)

ABI **v2** has two symbols. The proof-bearing one is `equiv_entry`; the
7-argument `entry` is a convenience wrapper that discards the kind and is not
used by cells or gates.

```c
/* normative: error_kind MUST be written on every return */
extern "C" int equiv_entry(
    const uint8_t *tx_bytes, uint64_t tx_len,   /* TX_WITH_WITNESS serialization */
    const uint8_t *spk,      uint64_t spk_len,  /* scriptPubKey, raw bytes */
    int64_t amount, uint32_t input_index, uint64_t flags,
    equiv_error_kind *error_kind);

/* non-normative convenience wrapper */
extern "C" int entry(
    const uint8_t *tx_bytes, uint64_t tx_len,
    const uint8_t *spk,      uint64_t spk_len,
    int64_t amount, uint32_t input_index, uint64_t flags);
```

Result `0 fail | 1 pass | 2 bad input | 3 internal/exception`. On failure
`error_kind` is Core's `ScriptError` ordinal at the pin (1:1, 56 values);
results 2/3 carry `EQUIV_ERR_UNKNOWN_ERROR`. Error *precedence* is observable
and part of the cell postcondition. The tape, domain rules, and contract hash
recipe are in `contract/tape.md`; the taxonomy is `contract/error_enum.md`.
Shims contain no engine logic; they are line-reviewed and counted in the trust
base.

## 5. Both tools — division and dual-attempt policy

| Tool | Strengths | Measured hard limits (do not infer from upstream docs alone) |
|---|---|---|
| **Alive2** (`alive-tv` v20.0) | bounded leaf cells, both-direction refinement, precise UB detection, concrete counterexamples | hard error on `invoke`/`landingpad` ("Could not translate"); indirect-call equivalence fails in practice; `ptrtoint`/`inttoptr` are shape-dependent (basic `ptrtoint+0` proved, round-trip identity is not); loops only by bounded unrolling; final memory is compared in v20 (stricter than value-only); LLVM 22 Rust IR rejected (`dead_on_return`, metadata kind 8) so R/Alive2 at the 1.95 pin is inapplicable |
| **SAW** (`llvm_verify`, v1.6) | whole-function proofs, symbolic execution through `invoke`/`landingpad` when the throw path is pruned, loop invariants, indirect calls/externals via overrides, JSON summaries | feasible `__cxa_*` exception paths need explicit overrides; every external/global function pointer needs an override; unbounded loops need an invariant (a timeout without one is not a proof); bitcode ceiling measured at LLVM 22.1.2 (LLVM 23.1.1 rejected) |

**Policy:** every cell is attempted with both tools where structurally
possible. `cells/<family>/<cell>/` records `alive2/` and `saw/` independently,
each with its own result or a filed reason. "Both green" is the strongest
tier; "one green + one inapplicable (reason)" is accepted; "neither" is a
filed gap. The executed probe matrix and raw logs are in
`tools/capability-matrix.md` and `findings/tools/probes/`; the exception,
indirect-call, and bitcode-ceiling addenda are in
`findings/verifications/artifacts/`.


## 6. Core patch policy (small modifications allowed)

Small, reviewed modifications to the pinned Core source are permitted **only**
to make the code expressible for a tool, never to change consensus behavior:

1. Minimal and localized (devirtualize the checker, convert a throw to an
   error return at the same site, remove a ptrtoint, split a function for
   cell slicing).
2. Recorded in `patches/` with: id, upstream file:line, diff, rationale,
   and **behavior-preservation evidence**: differential runs against the
   unpatched build on the full corpus + fuzz lanes, plus a review note.
3. Never merged silently: the IR artifacts record `patched: yes/no` and the
   patch id set.
4. Upstreamable in principle; anything not upstreamable is flagged in the
   cell's trust note.

The same-crypto premise (§7) is not a patch: checkers are abstracted, not
modified.

## 7. Crypto seam

Engine equivalence is proved with the signature checker abstracted as a
shared external (Alive2) or symbolic override (SAW) — the proof-level
counterpart of `docs/DECISION-lax-ecdsa.md`. The claim is conditional on
"same crypto". A separate bonus lane may prove the checker implementations
equivalent (Core/libsecp vs rbitcoin, and twin vs Core).

## 8. Evidence standards

Every cell record contains: contract hash, leg fingerprints (commit + tool +
flags + IR sha256), precondition, postcondition, tool version, direction(s),
result, certificate/log hash, and any gap reason. Every SCR row in
`spec/db/rules.yaml` maps to ≥1 green cell or a filed gap in
`spec/db/equiv-cells.yaml`. `make gate-ir-pin` enforces pins and coverage.
REDTEAM must sign off each milestone, including at least one **mutation
test** per family (inject a bug into the twin; the cell must fail).

## 9. Roadmap

| Milestone | Deliverable | Status |
|---|---|---|
| E0 | harness/ABI, three hello-world shims, tool install+pins, capability matrix, `PINS.lock` | **PASS** — `make e0` green; pins complete; proof IR separate |
| E1 | stack-op family, Alive2 + SAW, mutation test | **PASS (cells + mutations)** — SCR-069/071/072/074 green; 8 mutation runs killed |
| E2 | flow / ScriptNum / hash families | **attempted; partial cells** — WITHIN one-byte and concrete HASH160 cells tool-green, rows filed gap |
| E3 | CHECKSIG/CHECKMULTISIG + symbolic checker + error-enum equality | **attempted; partial cells** — exact ordinals 2/13/14/18/28; `M-E3-008` killed |
| E4 | SegWit v0 / taproot dispatch; seam-unjudged cells enumerated | **attempted; partial dispatch cell + 38-row seam/gap inventory** |
| E5 | whole-function `VerifyScript` (SAW invariants) or scoped residual | **scoped residual** — no whole-function proof; `findings/e5/E5-RESIDUAL.md` |
| E6 | three-leg closure, SCR coverage, `gate-ir-pin`, published matrix | **PASS for the evidence-tier deliverable** — 183/183 adjudicated; 0 planned; gate and equiv green |

## 10. How to evaluate this work

```sh
cd spec/equiv
cat PINS.lock                 # what every result is pinned to
make e0                       # reproduce the hello-world triple
make equiv                    # run the cell suite, regenerate results/matrix
make gate-ir-pin              # pins + coverage + no unfiled gaps
```

The current milestone state is `results/STATUS.md` and `docs/STATE.md`. E0
passes: tool probes are green and **C, L, and R agree on all four tapes** with
Core error ordinals (`results/e0/`). R is a clean public-API shim at the 1.95
pin, not the unregistered FFI patch. E0 is a harness gate, not an IR proof; the
proof lanes are the bounded `[core.ir]` lane and the 15-TU `[ir]` closure in
`PINS.lock`/`ir/manifest.json`.

The E6 ledger is **not all-green**: 4 rows are both-tool green, 20 are
unjudged seams, and 159 are filed gaps with named blockers (0 planned).
`make gate-ir-pin` and `make equiv` pass, and `results/matrix.md` publishes
the counts and trust base. Read `findings/coverage/F-E6-GAPS.md` for every
non-green disposition. No unconditional Lean == Core claim is made.

Then check, in order: (1) the contract in `contract/ABI.md`; (2) the shims
(they must contain no logic); (3) each cell's pre/post and certificate;
(4) the gap ledger (every gap has a blocking feature named); (5) the patch
log (each patch has behavior-preservation evidence); (6) the trust base
below. A reviewer who rejects any premise can point at exactly which results
depend on it.


## 11. Trust base

Pinned clang; pinned rustc; Alive2 and SAW/Crucible IR semantics; SMT
solvers; the three shims; the twin generator/translations; the same-crypto
premise; the pinned commits/builds; the 15-TU IR manifest; and the E5 scoped
residual's named assumptions. **Not** in scope: linker, machine backend, OS,
libsecp internals, live network.

## 12. Findings and residuals

`findings/` holds UB reports (any Core UB is drafted as an upstream issue),
counterexamples, divergences, and tool reports. `spec/db/equiv-cells.yaml`
is the cell ledger. A result is not accepted until its finding — if any —
has a disposition.

## 13. Fleet and parallelization

See `GOAL.md`. Eight roles, strict directory ownership, handoff files, no
cross-writes. Parallel-first: independent families and legs run concurrently.

## 14. References

- Alive2: *Bounded Translation Validation for LLVM*, PLDI 2021; `alive-tv`.
- SAW / Crucible: Galois Software Analysis Workbench; `llvm_verify`, Rocq export.
- Vellvm (Coq) and Isabelle/LLVM: formal IR semantics in other provers.
- Kani: bit-precise Rust model checker (MIR → CBMC).
- Miri: Rust UB detection interpreter.
- rbitcoin `script-oracle/verify.cpp`: the C-ABI oracle pattern (MIT/Apache-2.0).
