# LLVM IR equivalence plan — three-leg script engine

Status: PLAN (2026-10-19). Execution home: **`spec/equiv/`** (its
`README.md` is the evaluation entry point; `GOAL.md` is the durable
objective). This document is the strategic plan; the `spec/equiv` tree is
authoritative for contract, pins, cells, and results. It supersedes
`docs/CORE-BINARY-VERIFICATION-PLAN.md` (v2) for execution; v2 is retained
as program context. Scope is deliberately narrow: **prove LLVM IR-level
equivalence across three script-engine implementations**. No C++ source
proof, no binary-backend proof, no libsecp proof.

Two amendments to the original plan:
1. **Both tools are attempted on every cell** (Alive2 and SAW), not one per
   cell type; the division in §4 is a capability map, not an assignment.
2. **Small Core patches are allowed** (devirtualization, throw→error-return,
   ptrtoint removal, function splitting) under the strict policy in
   `spec/equiv/patches/README.md`: minimal, tracked, behavior-preserving
   evidence against the unpatched build, and never consensus-changing.

Pins: Bitcoin Core v32.99 @ `cce32b168`; rbitcoin at a pinned commit;
Lean model at the current tree. All tool versions are pinned in
`spec/equiv/PINS.lock` (phase E0).

---

## 1. Objective

Three legs, all lowered to LLVM IR:

| Leg | Source | Path to IR |
|---|---|---|
| **C** (reference) | Bitcoin Core `interpreter.cpp` + deps | pinned clang → `-emit-llvm` |
| **L** (Lean twin) | Lean model → generated C++ (or C) | same pinned clang → IR |
| **R** (Rust) | rbitcoin script engine | pinned rustc → `--emit=llvm-ir` |

Prove, for a fixed harness contract (§2):

- `L ⊑ C` and `C ⊑ L` (mutual refinement ⇒ equivalence on the contract domain)
- `R ⊑ C` and `C ⊑ R`
- by transitivity: `L ≡ R`

**Claim form (honest ceiling).** A conditional theorem: *for all inputs in
the harness domain, if the pinned front-ends, the IR semantics implemented
by SAW/Alive2, the SMT solvers, the shims, the twin generator, and the
shared-crypto premise are sound, then the three engines agree on verdict
and error kind.* The Lean kernel contributes only the twin's provenance
(the model side); IR equivalence is evidence-tier with certificates, not
a Lean-kernel theorem (a Lean-native IR semantics is a noted stretch, §12).

**UB disposition.** Any UB found in Core is a genuine upstream bug and
gets surfaced — but it is a side deliverable, not the focus (§6).

---

## 2. The canonical harness contract

Everything hinges on a single, shared, byte-level ABI. No proof can be
stronger than this contract.

**Signature (identical in all three shims):**

```
extern "C" int entry(
    const uint8_t *tx_bytes, uint64_t tx_len,   // serialized tx (witness format)
    const uint8_t *spk,      uint64_t spk_len,  // scriptPubKey
    int64_t amount,                              // spent output value
    uint32_t input_index,
    uint64_t flags)                              // Core script-verify flag bits
```

**Result:** `0 = fail, 1 = pass, 2 = bad input, 3 = internal/exception`,
plus a side channel `error_kind : u32` mapped to a shared enum. The error
enum is part of the contract: Core `ScriptError`, rbitcoin's error type,
and the twin's error type must map onto it identically. Mapping divergence
is a finding, not an implementation detail.

**Rules:**
- Shims are `extern "C"`, allocation-free at the boundary (caller owns
  buffers), and contain no engine logic. Each is line-reviewed and counted
  in the trust base.
- Witness data travels inside `tx_bytes` (Core's `TX_WITH_WITNESS`), which
  is exactly what rbitcoin's existing `script-oracle/verify.cpp` does.
- The contract domain is *all byte strings*; slices/restrictions (e.g.
  no-taproot) are explicit cell preconditions, never silent.

---

## 3. Building each leg

### 3.1 Core leg (reference)

- Compile at the pin with pinned clang; `-O0` is the primary target
  (dispatch structure legible), `-O1` is a robustness lane.
- Emit bitcode for the engine + shim: `VerifyScript`, `EvalScript`,
  `VerifyWitnessProgram`, `ExecuteWitnessScript`, `CheckLockTime`,
  `CheckSequence`, `CastToBool`, CScriptNum, `GetScriptOp`,
  `CheckSignatureEncoding`, `GetSigOpCount` and their dependencies.
- `prevector`/`std::vector` instantiations are in the IR; they are part of
  what is proved.
- **Known IR hazards to handle in E0:** `EvalScript` catches
  `scriptnum_error` (→ `invoke`/`landingpad`); `BaseSignatureChecker` is a
  virtual interface (→ indirect calls/function pointers); possible
  pointer-to-integer casts. Alive2 supports none of `invoke`, function
  pointers, or ptrtoint; SAW handles indirect calls via overrides. This is
  why the tool split in §4 is not optional.

### 3.2 Lean twin leg

- Preferred: Lean model → imperative IL (the existing `stepBody`/`evalFrom`
  structure) → **generated** C/C++ twin via a small, audited generator.
  The generator is the only trust-relevant new code; it is deterministic,
  and its output is diffable.
- Fallback if the IL/generator is not ready: hand-transliterated C++ twin
  checked by differential runs against the Lean model's compiled runner.
  This downgrades the L-leg link to "reviewed transliteration" and must be
  labelled as such.
- Compile with the **same pinned clang** as Core → IR. Same-language,
  same-compiler pairs keep the front-end premise minimal.

### 3.3 Rust leg (rbitcoin)

- Pin commit + rustc; `--emit=llvm-ir`.
- **LLVM version skew is the main risk:** rustc bundles its own LLVM; SAW
  supports a bounded set of LLVM versions (≤20 at SAW 1.5). E0 must select
  a rustc whose LLVM output SAW can ingest, or canonicalize through a
  matching `opt`. If no overlap exists, the R leg runs Alive2-only (which
  is version-tolerant to a point) and the gap is filed.
- Panics: the shim uses `catch_unwind` (or the build uses abort-on-panic);
  panics map to result `3`, exactly like Core's `catch (...)`.
- Crypto: determine whether rbitcoin uses the `secp256k1` C bindings or a
  pure-Rust implementation. If bindings, the same crypto-override premise
  applies to both C and R legs. If pure Rust, run the checker as a separate
  bonus equivalence lane (§5).

---

## 4. Proof architecture: cells and tools

A **cell** = (source function, target function, input precondition, output
relation, tool, certificate). Cells are the unit of work, review, and
coverage.

**Tool assignment (grounded in actual capabilities):**

| Tool | Use for | Cannot do |
|---|---|---|
| **Alive2** (`alive-tv`) | Bounded leaf cells: straight-line/bounded loops, no `invoke`, no function pointers, no ptrtoint; refinement in both directions; UB detection | Exceptions, indirect calls, long/unbounded loops, full memory-model refinement |
| **SAW** (`llvm_verify`, Crucible) | Whole-function equivalence, exception-bearing functions, loops with invariants, indirect calls via overrides, proof export to Rocq | Scales worse than Alive2 on leaf cells; proof objects need recording |

**Cell families** (mirroring the SCR census): pushes/parsing; control flow;
stack ops; numeric/ScriptNum; hashes; CHECKSIG pre-tapscript; CHECKMULTISIG;
locktime (CLTV/CSV); SegWit v0; taproot/tapscript dispatch; disabled
opcodes; limits/accounting.

**Coverage ledger.** `spec/db/equiv-cells.yaml`: one row per cell with
`id`, `legs`, `scr_rows` (the rule IDs it covers), `tool`, `status`,
`certificate_hash`, `gap_note`. Gate: every one of the 183 SCR rows maps
to ≥1 green cell or a filed gap. The census becomes the coverage oracle —
this is what stops the campaign from quietly proving only the easy paths.

**Direction discipline.** For deterministic single-result functions,
refinement both ways is equivalence; run both directions per cell and
record them separately. Where only one direction is proved, say so.

**Independent complement.** The three-oracle differential run (Core vs
Lean vs Rust on corpora + fuzz) does not prove anything, but it catches
harness blind spots and cell-selection errors. Run it on every cell family.

---

## 5. The crypto seam

- Engine equivalence is proved with the signature checker abstracted:
  Alive2 sees a shared external declaration (unknown call = arbitrary but
  identical on both sides); SAW replaces the checkers with symbolic
  overrides. This mirrors `docs/DECISION-lax-ecdsa.md` exactly.
- The claim is therefore **conditional on "same-crypto"**: both sides call
  checkers with identical semantics. That premise is named in every
  certificate.
- **Bonus lane (high value, separate):** prove the checker implementations
  equivalent — Core's libsecp path vs rbitcoin's (Rust) path, and the twin's
  checker vs Core's. Because the engines pass identical byte strings to
  the checker, this is a clean, independent equivalence problem. If
  rbitcoin is pure Rust, this lane is the first real Rust-vs-C crypto
  equivalence result available to this project.

---

## 6. UB protocol (side channel, not focus)

- Alive2 flags UB in every cell it checks; UBSan-instrumented Core runs
  over the corpora; Miri runs over rbitcoin's engine crate.
- Any UB in Core: draft an upstream issue (minimal reproducer + IR cell),
  record it in `spec/equiv/findings/`, and block the affected cell until
  disposition (fix upstream / restrict domain with the restriction
  documented). Do not patch Core locally.
- "UB-clean on the corpus" is a recorded premise of E6, not an assumption.

---

## 7. Pins, gates, reproducibility

`spec/equiv/PINS.lock` records: Core commit, clang version/build, rustc
version, LLVM version of each IR artifact, SAW version, Alive2 version,
Z3/CVC5 versions, flags (`-O0`/`-O1`), triple. 

New gate `gate-ir-pin`:
- every cell's recorded tool versions match `PINS.lock`;
- every cited IR artifact hash is present and matches;
- every SCR row is covered or filed (§4);
- `make equiv` runs the cell suite and regenerates the matrix.

Determinism: rebuild IR from source+flags and compare hashes; a mismatch
is a gate failure.

---

## 8. Milestones

**E0 — Harness and toolchain shakedown.** Canonical ABI; three hello-world
shims implementing one trivial function in C++, C++ (twin path), and Rust;
prove the triple-equivalence pipeline end to end. Fill a capability matrix:
SAW-on-exceptions, SAW-on-indirect-calls, Alive2-on-externals, rustc/SAW
LLVM-version overlap. *Accept: one trivial triple green; capability matrix
documented; PINS.lock committed.*

**E1 — Stack-op family.** OP_DUP/DROP/SWAP/ROT/TOALTSTACK/FROMALTSTACK/
2DROP/2DUP/3DUP/2OVER/2ROT/2SWAP/IFDUP/DEPTH/PICK/ROLL/TUCK across all
three legs. Alive2 leaf cells + one SAW whole-function cell. **Mutation
test:** inject a bug into the twin; the cells must fail (red-team sign-off).
*Accept: family green; mutation caught; first cells in the ledger.*

**E2 — Flow, numeric, hash families.** IF/NOTIF/ELSE/ENDIF/VERIFY/RETURN;
CScriptNum decode/encode + arithmetic + WITHIN; SHA256/SHA1/RIPEMD160/
HASH160/HASH256. *Accept: family matrix green; every gap filed.*

**E3 — Checksig/CMS with symbolic checker.** CHECKSIG/CHECKSIGVERIFY/
CHECKMULTISIG/CHECKMULTISIGVERIFY, NULLFAIL, NULLDUMMY, DER/BIP66
encoding gates, FINDANDDELETE/CODESEPARATOR; error enum equality.
*Accept: cells green; error-taxonomy divergences zero or filed.*

**E4 — Witness v0 and taproot dispatch.** VerifyWitnessProgram,
ExecuteWitnessScript, P2SH/P2WSH nesting, annex, key/script path dispatch,
OP_SUCCESSx. Schnorr/EC cells outside the seam marked unjudged (matching
`DECISION-lax-ecdsa.md`). *Accept: dispatch equivalence green; unjudged
cells enumerated.*

**E5 — Whole-function VerifyScript.** SAW with loop invariants over the
`EvalScript` dispatch loop; exception path; verdict + error equivalence.
*Accept: whole-function proof, or a precisely scoped residual with the
blocking IR feature named.*

**E6 — Three-leg closure.** Transitivity statement `L ≡ C ≡ R` on the
contract; full ledger vs the 183 SCR rows; `gate-ir-pin` green; matrix
published in `docs/LLVM-EQUIVALENCE.md`; trust base restated with every
premise named. *Accept: coverage gate green; no unfiled gaps.*

---

## 9. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Alive2 lacks `invoke`, function pointers, ptrtoint | Cannot check `EvalScript`/checker paths | SAW owns those cells; Alive2 only leaf cells; E0 capability matrix |
| rustc LLVM ≠ SAW-supported LLVM | R leg unbuildable in SAW | E0 toolchain selection; fallback Alive2-only for R; file gap |
| `prevector` inline storage / memory model | Alive2 memory limitations produce false alarms | SAW for those cells; restrict domains explicitly |
| Exceptions in `EvalScript` | Whole-function proof fails | Split throw/no-throw cells; SAW for exception edges; T1 E5 |
| Panics in Rust | Divergent behavior vs Core `catch(...)` | Shim `catch_unwind`; panic → result 3; documented |
| Solver timeouts | Cells stall | Cell size budget; incremental decomposition; certificate caching |
| Error-mapping drift | False equivalence | Error enum is contract (§2); E3 explicitly compares |
| Harness bug (shims) | Proof about the wrong thing | Line review + mutation tests + three-oracle differential |

---

## 10. Trust base (what the final claim rests on)

1. Pinned clang front-end (C and L legs) — C++ → LLVM IR is trusted.
2. Pinned rustc front-end (R leg) — Rust → LLVM IR is trusted.
3. The LLVM IR semantics as implemented by Alive2 and SAW/Crucible.
4. The SMT solvers (Z3/CVC5) and the certificate/export mechanism.
5. The three shims and the canonical contract (small, reviewed).
6. The twin generator (deterministic, audited; downgraded if the
   transliteration fallback is used).
7. The same-crypto premise (§5).
8. The pinned commit/build of each leg.

Not in scope: the linker, the machine backend, the OS, libsecp internals,
and live network behavior.

---

## 11. Deliverables

```
spec/equiv/
  PINS.lock                 # all tool/commit/IR versions
  contract/                 # tape format, error enum, corpus schema
  shims/core/               # extern "C" shim over Core
  shims/twin/               # shim over the Lean-derived artifact
  shims/rust/               # shim over rbitcoin
  cells/<family>/           # per-cell specs + SAW/Alive2 invocations
  findings/                 # UB reports, counterexamples, divergences
docs/LLVM-EQUIVALENCE.md    # generated matrix + trust base
spec/db/equiv-cells.yaml    # cell ledger keyed to SCR rows
```

CI: `make equiv` (cell suite + matrix regeneration), `make gate-ir-pin`.

---

## 12. Out of scope / noted stretches

- Post-IR (machine code/backend) equivalence — separate rung, not this.
- Binary lifting of Core's shipped artifact — not this.
- Lean-kernel replay of SMT results — no Lean LLVM semantics exists today;
  SAW's Rocq export is the independent-replay option. A Lean-native IR
  subset semantics remains a research stretch.
- libsecp internal proofs (except the bonus checker lane, §5).
- Network/policy behavior.

---

## 13. Fleet

| Agent | Owns |
|---|---|
| CONTRACT | §2 ABI, shims, error enum, corpus schema, E0 hello-world |
| CORE-IR | Core build, IR extraction, cell slicing, exception/indirect-call map |
| TWIN-IR | Lean→twin generator (or transliteration), IR, generator audit |
| RUST-IR | rbitcoin pin/build, IR, panic shim, Kani/Miri runs |
| CELLS | SAW/Alive2 proofs per family, certificates, both directions |
| LEDGER | equiv-cells.yaml, SCR coverage, gate, generated docs |
| REDTEAM | mutation tests, harness attacks, divergence triage, per-milestone sign-off |

Milestone ownership: E0 CONTRACT+REDTEAM; E1–E4 CELLS with CORE-IR/TWIN-IR/
RUST-IR; E5 CELLS+CORE-IR; E6 LEDGER+REDTEAM.
