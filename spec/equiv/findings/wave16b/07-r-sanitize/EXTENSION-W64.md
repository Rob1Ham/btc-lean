# Wave-64 extension — advisory R sanitize lane (07-r-sanitize)

**Status: advisory, off-pin. Not a pin, not an official artifact, not a
promotion, and not a claim of pinned R equivalence.** The transform is a
weakening (see `REPORT.md` §9); all results below are about sanitized IR, not
about the byte-exact pin module. No file outside this directory was modified.

Branch `wave64/42-r-sanitize-extend`, base `5946c02`. This document extends
`REPORT.md` (wave 16B) with:

1. a fresh reproduction of the 12-rule sanitizer on the pinned
   `rustc 1.95.0 / LLVM 22.1.2` module (hashes unchanged);
2. a machine-readable **translation census** for 351 functions, overall and per
   namespace, with the exact blocker list;
3. **eight SMT-backed cross-artifact refinements** (seven consensus-logic
   functions; five of the eight are new in this wave), each with
   `Transformation seems to be correct!` and **no** `(syntactically equal)`
   suffix;
4. a **new precise blocker** on the cross-artifact side: `load volatile` in the
   official 1.88/LLVM-20 module rejects 64 functions (41 `rbitcoin_consensus`),
   including `eval_script`;
5. a six-times solver-budget experiment that adds no proof.

## 1. Reproduction

| Item | sha256 |
|---|---|
| pin 1.95/LLVM-22 IR (input) | `1654c15d3bba8a89ffbd20ebf342fec310ca2e5d0337c26a81a37b8479632c86` |
| official 1.88/LLVM-20 IR (input) | `95037087cd92b95dee88bcbf14519b99f9ec420be34d01642cc724f5e706cad5` |
| `san7.ll` (sanitized 1.95) | `c475de3053ec8dbc00de44b894bf9bcee6c77dcb928e835385565a4ef0de3c5f` |
| `san7.bc` (LLVM-20) | `22ed16a035c63c79958b43081624534eed62ea8b0fa2388fa51f540aea44eed2` |
| `r188c.ll` (sanitized 1.88) | `dd1f858087fddb5f80386a11c545ba5279466db8a075cfc7b380712b261bc2a5` |
| `r188c.bc` (LLVM-20) | `fb4f7a71bda353cc24410ebdb4b37307adb9a24ee4f9ec6474ddc621006846c4` |
| Alive2 v20.0 binary | `91d9c14af27444c5248b948437b64e9dc7b0ed63d1bf478305a1e9cef2ed50ff` |

Exact commands: `commands-w64.txt`. The sanitizer is unchanged from wave 16B
(`99278f3c…`), reproduces `san7.ll` byte-for-byte, and `audit_diff.py` still
reports `AUDIT CLEAN` (0 unsanctioned changed lines, 0 opcode changes, 1,103
`noalias.scope.decl` lines deleted). The 1.88 module needs the same pass
(R5/R6/R7/R8/R10 plus legacy `nocapture` R12); its sanitized hash matches the
wave-16B value.

## 2. Translation coverage (quantified)

Command: `alive-tv-v20.0 --skip-smt san7.bc san7.bc` (self-comparison; this is
a **translation census**, not a proof), then `census_w64.py`. Full rows:
`w64/census-san7.tsv`.

### 2.1 Overall — 351 defined functions

| status | functions | share |
|---|---:|---:|
| translated, self-comparison `syntactically equal` | 180 | 51.3% |
| translated, Alive2 `correct` but **not** marked `(syntactically equal)` | 3 | 0.9% |
| translated, solver-only (`ERROR: Skip`) | 31 | 8.8% |
| **translated (total)** | **214** | **61.0%** |
| rejected at translation | 137 | 39.0% |

Wave 16B grouped all 183 non-`ERROR: Skip` entries as "correct"; on re-parse,
180 carry Alive2's `(syntactically equal)` marker and 3 are plain `correct`
without the marker. All 214 rows are self-comparisons, not proofs.

The 137 rejections are exactly two classes: `sret([N x i8])` **57** and
atomic instructions **80** (`cmpxchg` 12, `atomicrmw` 30, `load atomic` 37,
`store atomic` 1; all crates).

### 2.2 rbitcoin_consensus — 183 defined functions

| status | functions | share |
|---|---:|---:|
| translated, self-comparison | 79 | 43.2% |
| translated, solver-only | 15 | 8.2% |
| **translated (total)** | **94** | **51.4%** |
| rejected: `sret([N x i8])` | 57 | 31.1% |
| rejected: atomic | 32 | 17.5% |
| **rejected (total)** | **89** | **48.6%** |

Atomic split for rbitcoin: `load atomic` 18, `atomicrmw` 7, `cmpxchg` 6,
`store atomic` 1. No `load volatile`, no metadata-kind errors on the 1.95
side. Exact names: `w64/blockers-sret.tsv`, `w64/blockers-atomics.tsv`,
`w64/solver.tsv`.

### 2.3 Engine path

`eval_script` itself is ingestible and self-compares syntactically, but the
public wrappers return `Result<(), ConsensusError>` via `sret([24 x i8])`:

| entry | status | exact first blocker |
|---|---|---|
| `interpreter::eval_script` | translated | self-comparison only, not a proof |
| `interpreter::EvalContext::from_job` | rejected | `load atomic i32 … acquire` |
| `script::verify_job_all_inputs` | rejected | `sret([24 x i8])` |
| `verify_tx_scripts_with_flags` | rejected | `sret([24 x i8])` |
| `verify_tx_scripts_detached` | **rejected** | `sret([24 x i8])` |
| `verify_tx_scripts_detached_forks` | **rejected** | `sret([24 x i8])` |
| `interpreter::bin_cmp` (6), `bin_arith` (2) | translated, solver-only | 10 s SMT budget |
| `interpreter::op_checksigadd` | translated, solver-only | 10 s SMT budget |
| `interpreter::op_checkmultisig` | translated, solver-only | 10 s SMT budget |
| `interpreter::ecdsa_sig_matches` | translated, solver-only | 10 s SMT budget |
| `p2tr::verify`, `tx_precompute::from_tx_inner` | translated, solver-only | 10 s SMT budget |
| `interpreter::script_code_bytes`, `op_checksig` | translated | self-comparison only |
| `script::verify_native_witness` | translated | self-comparison only |

Per-namespace coverage (full table): `w64/summary.md` §"Per-area translation".

## 3. Real cross-artifact refinements (SMT, not syntactic equality)

### 3.1 Method

Both modules are sanitized; then for a unique logical function name present in
both:

1. `llvm-extract --func=<old symbol>` from `r188c.bc`;
2. `llvm-extract --func=<new symbol>` from `san7.bc`;
3. rename the old symbol to the new symbol in the extracted text (symbol-table
   edit only; no instruction edit);
4. `llvm-as`; `alive-tv-v20.0 <1.88> <1.95>` with real SMT (`--smt-to=10000`,
   default solver budget).

Direction: the **1.95-sanitized function is the target**, so
`Transformation seems to be correct!` means the 1.95 function refines the 1.88
function. `jobs.tsv` has the 46 pairs that translate on both sides; the rest of
the shared functions are blocked on at least one side. All logs:
`w64/cross/<tag>/alive.out`.

The 1.95 side cannot be used unmodified even for these eight leaf functions:
extracting them from the LLVM-22 bitcode and assembling with `llvm-as-20` fails
for 7/8 (R2 `target_memN: none` or R3 `nocreateundeforpoison`), and the eighth
(drop glue) assembles but Alive2 rejects `noalias`. `w64/unmodified-195.txt`
records the exact error for each. The sanitizer is therefore a precondition of
ingestion, not an optional convenience; the results below are necessarily about
the sanitized 1.95 functions.

### 3.2 Results: eight SMT proofs

Each row ended with `Transformation seems to be correct!` **without**
`(syntactically equal)`, `0 incorrect`, `0 failed-to-prove`, `0 Alive2 errors`.
The extracted bodies differ (70–331 unified-diff lines including
module/attribute headers; instruction, SSA and attribute details are not
identical), so these are
solver proofs, not the syntactic fast path.

| function | 1.88 symbol hash (old) | 1.95 symbol hash (new) | result | time |
|---|---|---|---|---:|
| `block::is_final_tx` | `…17h48c1da67753371e2E` | `…17h4915279e4121e295E` | correct (SMT) | 0.22 s |
| **`block::block_subsidy`** | `…17h9aed088c6318a203E` | `…17h3e3a8518a88668c4E` | correct (SMT) | 0.12 s |
| `block::witness_commitment_vout_index` | `…17h6f137e329e071420E` | `…17h9fb3bee2f254ad31E` | correct (SMT) | 1.57 s |
| **`params::ChainParams::subsidy_halving_interval`** | `…17h1143a0685197ea30E` | `…17he6d9d2be4df64870E` | correct (SMT) | 0.14 s |
| **`params::ChainParams::overlay_subsidy_halving_interval`** | `…17h366bf3680d6af847E` | `…17h8ea8819fa3da782aE` | correct (SMT) | 0.11 s |
| `policy::zero_value_spendable_is_dust` (loop) | `…17hf3683a0770491074E` | `…17h241dc154a8650499E` | correct (SMT) | 0.96 s |
| **`script::p2pkh_scriptsig_shape_error`** | `…17h8fb6d465b98e620fE` | `…17h7a6eb8bb1e705f17E` | correct (SMT) | 2.19 s |
| `core::ptr::drop_in_place<ConsensusError>` (drop glue) | `…17hf685c21b5175fc48E` | `…17h4683c4b96bddfc0eE` | correct (SMT) | 0.27 s |

Full symbols are in `w64/jobs.tsv`.

**Five of the eight are new in this wave** (bold rows plus the drop glue);
wave 16B had proven the other three. Four of the five new ones are consensus
logic (`block_subsidy`, both ChainParams halving helpers,
`p2pkh_scriptsig_shape_error`); the fifth is drop glue and is not claimed as
consensus logic.

None of the seven consensus-logic proofs depends on an unknown external
callee: they contain only intrinsics (`llvm.umax.i32` for the subsidy helpers,
`bcmp` for `p2pkh_scriptsig_shape_error`) or no calls at all. Exact symbols,
module hashes and logs are in `w64/jobs.tsv`,
`w64/cross/*/alive.out`, `hashes-w64.txt`.

**The reverse direction also proves for all eight.** Running
`alive-tv <1.95-sanitized> <1.88>` on the same pairs gives
`Transformation seems to be correct!` (SMT) for all eight, `0 incorrect`,
`0 failed-to-prove` (`w64/cross-reverse/results.tsv`, logs in
`w64/cross-reverse/`). On the sanitized IR this is a **mutual refinement**, i.e.
Alive2's refinement relation holds in both directions. It is not a statement
about the byte-exact pin module (see §5).

### 3.3 What this does and does not establish

* It establishes that, **after the sanitization**, the 1.95 build's function
  refines the 1.88 build's function on all inputs for these eight pairs, and
  (reverse run) vice versa. Since both are `-O2` builds of the same source
  pin, this is evidence that the sanitization did not change computed results
  on real consensus code; a value change would have produced a counterexample.
* It is **mutual refinement on sanitized IR**, not an equivalence proof of the
  pin artifacts. The reverse direction is a separate run
  (`w64/cross-reverse/`); both directions are `correct (SMT)`.
* It is **not** an engine proof, not a cell, and not pinned R equivalence.
  Seven small functions are not `EvalScript`.

### 3.4 Cross-version comparison is noisy outside the proofs

Of the 46 pairs: **8 correct (SMT), 8 incorrect, 18 failed-to-prove, 12
timeout**. The 8 `incorrect` are all `Source is more defined than target` and
all trace to cross-build metadata/callee differences, not to the sanitizer:

| pair | counterexample trigger |
|---|---|
| `block::last_script_push` | `i64 %#range_0_%script.1 = UB triggered!` |
| `block::sequence_locks_satisfied` | `i64 %#range_0_%prev_heights.1 = UB triggered!` |
| `block::block_mutated_without_coinbase` | `void = UB triggered!` |
| `script_code_bytes` | `@slice_index_fail` triggered UB (callee symbol differs) |
| `script::classify` | `WitnessVersion::try_from` triggered UB (callee symbol differs) |
| `policy::check_libre_admission` | `check_libre_shape` triggered UB (callee symbol differs) |
| `silent_payments::last_compressed_witness_pubkey` | `witness_items_no_annex` triggered UB (callee symbol differs) |
| `ConsensusError::fmt` (Debug) | `Formatter::debug_tuple_field1_finish` triggered UB (callee differs) |

The sanitizer deliberately retains `!range`/`noundef`; rustc 1.88 and 1.95
attach slightly different range facts, so Alive2 can find an input that makes
the target's `!range` UB while the source has no such fact. This is an artifact
of cross-build comparison, not a rbitcoin divergence. The 18
`failed-to-prove` runs split into 9 `Unknown libcall` (callee mangled names
differ between rustc versions), 6 Z3 `incomplete quantifiers`, and 3
"non-constant global variable … introduced in target" (interprocedural global
identity); 12 further pairs time out (9 solver timeouts, 3 wall timeouts at
120 s). The exact per-pair rows are in `w64/cross/results.tsv`.

## 4. Precise blockers

### B-07a — `sret([N x i8])` on definitions (57 rbitcoin functions)

Alive2 v20 has no `Attribute::StructRet` handling; the first error is exactly
`ERROR: Unsupported attribute: sret([24 x i8])` (or 32/33/64/65/104/128/136/
304/376). The 57 are all `rbitcoin_consensus`. It hits every public engine
wrapper (`verify_tx_scripts_with_flags`, `verify_tx_scripts_detached`,
`verify_tx_scripts_detached_forks`, `verify_job_all_inputs`), all
`block::facts` helpers, all `ChainParams` constructors, and
`tx_precompute::TxPrecompute::{from_tx, from_tx_wire, from_tx_connect}`.
Exact list: `w64/blockers-sret.tsv`; minimal reproducer `repro/r2-sret.ll`.
`sret` is the ABI contract for returning `Result<_, ConsensusError>`; deleting
it is not a semantics-neutral sanitization, so this lane does **not** do it.

### B-07b — atomic instructions (80 functions; 32 rbitcoin)

Exact first failing instructions:
* `load atomic` 37 (rbitcoin 18), e.g. `EvalContext::from_job`:
  `%37 = load atomic i32, ptr %_18.i.i.i9 acquire, align 8`;
* `atomicrmw` 30 (rbitcoin 7);
* `cmpxchg` 12 (rbitcoin 6);
* `store atomic` 1 (rbitcoin 1).
Exact list: `w64/blockers-atomics.tsv`; minimal reproducer `repro/r3-atomics.ll`.
Atomics are the meaning of the synchronization code (`script_pool`, `Arc`,
`clock`); sanitizing them away is not admissible.

### B-07c — solver budget (31 functions; 15 rbitcoin)

These translate but `--skip-smt` cannot prove them; with real SMT they are the
interpreter opcodes: `bin_cmp` ×6, `bin_arith` ×2, `op_checksigadd`,
`op_checkmultisig`, `ecdsa_sig_matches`, `p2tr::verify`,
`tx_precompute::from_tx_inner`, `signet_magic`, plus 16 non-rbitcoin functions
(`core::fmt`, `Witness::from_slice`, etc.). Exact list: `w64/solver.tsv`.

A 6× solver budget (`--smt-to=60000`, 240 s wall cap) was run on eight
cross-version failed-to-prove pairs; it produced **no new proof**. One pair
(`classify::witness_program`) resolved to `Source is more defined than target`
with `WitnessVersion::try_from` triggering UB — the same cross-build callee
artifact as §3.4, not a proof. Rows: `w64/cross-deep/results.tsv`. The wall is
both formula size and Z3's incomplete quantifiers, not just the 10 s default.

### B-07d — cross-artifact `load volatile` (64 functions; 41 rbitcoin)

This is new in wave 64. The official `rustc 1.88 / LLVM-20` module, after the
same sanitization, still fails with:

```
ERROR: Unsupported instruction:   %x = load volatile i8, ptr @__rust_no_alloc_shim_is_unstable, align 1
ERROR: Could not translate '<name>' to Alive IR
```

for **64** functions, **41** of them `rbitcoin_consensus`, including
`eval_script`, `op_checksig`, `op_checksigadd`, `verify_native_witness`, every
`bin_cmp`, `p2tr::verify`, and most `script::crypto` functions. Exact list:
`w64/blockers-188-volatile.txt`; minimal reproducer
`w64/repro-load-volatile.ll` / `.out`.

Consequence: `eval_script` can be translated on the 1.95 side but not on the
1.88 side, so the strongest engine function that is actually comparable across
the two artifacts is not `eval_script`. Removing `volatile` would be a semantic
change (it is the rustc 1.88 allocator-shim guard), so this lane records it as a
blocker rather than stripping it.

### B-07e — cross-artifact callee-name mismatch and range-fact drift

Callee hashes differ between rustc 1.88 and 1.95 (`Unknown libcall` in Alive2),
and `!range`/`noundef` facts differ slightly, producing
`Source is more defined than target` counterexamples on 8 pairs. This blocks a
closed-program cross-version proof for those functions even though both sides
translate. It is a comparison artifact, not evidence of a source divergence.
Exact rows: `w64/cross/results.tsv`.

## 5. Soundness and non-claims

1. **Weakening.** The sanitizer drops optimization contracts (`noalias`,
   scoped alias metadata, `captures`, `invariant.load`, `nocreateundeforpoison`,
   `dead_on_return`) and reconstructs lifetime sizes. The sanitized module is
   defined on a superset of inputs and is not equivalent to the pin module in
   the presence of callers that violate the dropped contracts. A pass on the
   sanitized module is evidence about a more-defined program, not the pin.
2. **Not pinned R equivalence.** No row is promoted; `PINS.lock`, the contract,
   Lean, census and official result files are untouched. This directory is
   advisory.
3. **Direction.** §3 proofs are `1.88 → 1.95` refinements, and the reverse run
   also proves for all eight on the sanitized IR (`w64/cross-reverse/`). That is
   mutual refinement of sanitized IR, not equivalence of the pin artifacts and
   not a pin promotion.
4. **`--skip-smt` numbers are a census.** The 180 `correct-syntactic` entries are
   Alive2's syntactic fast path on a self-comparison; they are not proofs.
5. **Provenance.** The 1.95 artifact is the `equiv-ffi` proposal build, not a
   clean-tree build (recorded in `REPORT.md` §2); the 1.88 artifact is the
   proof-lane artifact with the recorded hash. The closure of the seven proofs
   does not depend on `rbtc_rust_verify`.
6. **Sanitizer scope.** No instruction is edited. `audit_diff.py` re-run on the
   pin gives `AUDIT CLEAN`.

## 6. Files added by wave 64

| Path | Contents |
|---|---|
| `EXTENSION-W64.md` | this report |
| `commands-w64.txt` | exact commands, hashes, tool paths |
| `hashes-w64.txt` | input/output/script/log hashes |
| `census_w64.py` | translation census parser (module + Alive2 output) |
| `make_jobs_w64.py` | cross-artifact job-list generator |
| `cross_w64.py` | cross-artifact Alive2 driver |
| `w64/summary.md` | translation tables and engine-path table |
| `w64/census-san7.{json,tsv}` | 351-function census, 1.95 sanitized |
| `w64/census-188.{json,tsv}` | 366-function census, 1.88 sanitized |
| `w64/blockers-sret.tsv` | 57 `sret` definitions, exact type/error |
| `w64/blockers-atomics.tsv` | 80 atomic rejections, exact instruction |
| `w64/solver.tsv` | 31 solver-only functions |
| `w64/blockers-188.tsv` | 203 cross-artifact translation failures |
| `w64/blockers-188-volatile.txt` | 64 `load volatile` failures (41 rbitcoin) |
| `w64/unmodified-195.txt` | why the eight proof functions need the sanitizer even as leaves |
| `w64/jobs.tsv` | 46 cross-artifact symbol pairs |
| `w64/cross/results.tsv` | per-pair status/time/counts |
| `w64/cross-results.json` | same data, machine-readable |
| `w64/cross/<tag>/alive.out` | full Alive2 logs (proofs raw; others gzipped) |
| `w64/cross-reverse/results.tsv` | reverse-direction run for the eight proofs (all correct SMT) |
| `w64/cross-deep/` | 60 s solver-budget run |
| `w64/repro-load-volatile.ll/.out` | minimal `load volatile` reproducer |
