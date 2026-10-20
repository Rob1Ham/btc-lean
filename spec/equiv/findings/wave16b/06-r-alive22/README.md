# Wave 16B / 06 — R Alive2 on LLVM 22 (B-03 probe)

Date: 2026-10-20. Task: `06-r-alive22`, branch `wave16b/06-r-alive22`
(base PR head `805c804`). Scope: probe only. **`PINS.lock` is unchanged**;
nothing here is an accepted pin, an official artifact, or an equivalence claim.

## Bottom line

1. **The parse half of B-03 is solved by building Alive2 against LLVM 22.**
   The real rbitcoin 1.95/LLVM-22 module now parses and is fed to Alive2: 351
   defined functions, 9 translate, 342 are rejected at *translation*, not at
   parse. The old `dead_on_return` parse error is gone.
2. **There is no upstream Alive2 release that supports LLVM 22.** No `v22.0`
   tag exists; `master` (2026-10-19) requires LLVM 23 APIs. The newest upstream
   commit that builds against LLVM 22.1.8 is **`0dc2be5f` (2026-01-21,
   `v21.0-61-g0dc2be5f`)**. That is the binary used here.
3. **A newer Alive2 does not fix the rest.** Even current `master` still rejects
   every one of the constructs that block the R engine IR:
   parameter `noalias`, `sret(...)` on definitions, scoped alias metadata and
   `llvm.experimental.noalias.scope.decl` (and silently *drops* precise
   `captures(...)` with only a diagnostic).
   Upgrading Alive2 therefore **cannot** by itself produce an R-at-pin lane.
4. **No compiler/pin change fixes it either** (probed two ways). `-O0` removes
   the alias metadata and `dead_on_return` but keeps `sret` (1,070 signature
   attributes); `-Z mutable-noalias=no -Z box-noalias=no` only halves the alias
   constructs. Every rustc build probed is still rejected by Alive2.
5. **What is actually admissible today is narrow:** the *unmodified* pin IR is
   ingestible for leaf functions that carry none of the unsupported constructs
   (9/351, of which 5 are `rbitcoin_consensus`). One of them
   (`script_code_bytes`) was verified against a rewritten twin with the body
   byte-identical modulo the symbol rename — a real SMT proof, not a
   self-comparison. That is a viable **leaf-only** lane, not an engine lane.
6. **Recommendation:** keep C-L as the engine equivalence lane and R as
   SAW-only at the pin; do **not** claim R/Alive2. Do not strip attributes or
   metadata to force ingestion. Engine-level R/Alive2 requires upstream Alive2
   feature work plus an LLVM-22-targeted build; it is out of reach for PR #29.

## Environment (exact)

| Item | Value |
|---|---|
| Host | Ubuntu 24.04 (noble), x86_64, 16 cores |
| LLVM 22 | apt.llvm.org `llvm-toolchain-noble-22`, package `1:22.1.8~++20260714014902+ca7933e47d3a-1~exp1~20260714135019.80` (LLVM **22.1.8**), `/usr/lib/llvm-22/bin` |
| clang 22 | `1:22.1.8~++20260714014902+ca7933e47d3a-1~exp1~20260714135019.80` |
| Alive2 source | `https://github.com/AliveToolkit/alive2.git` @ **`0dc2be5f`** (`v21.0-61-g0dc2be5f`, 2026-01-21) |
| Alive2 build | Release, `-DBUILD_LLVM_UTILS=ON`, LLVM 22.1.8, Z3 4.8.12, cmake 3.28.3, ninja, clang++-22 |
| Binary | `/tmp/opencode/wave16b-scratch/06-r-alive22/build-0dc2be5f/alive-tv` (scratch, **not installed**) |
| Binary sha256 | `078cd01354ab96145d44a2fdf2902e91825c5797e2b1045c14ec2a1b4345d771` |
| Input IR | `target-195-ir/release/deps/rbitcoin_consensus-68e7c81c2384e3ba.ll`, 14,216,525 B, sha256 `1654c15d3bba8a89ffbd20ebf342fec310ca2e5d0337c26a81a37b8479632c86` (matches `findings/rust/artifacts.md`) |
| Derived bitcode | `llvm-as` 22.1.8 on the above, 2,686,764 B, sha256 `2706affa4a0d09d221f92b6fb3ab3fb189294830f6036d7b6494de5f1864efe0` |
| Unchanged pins | `/opt/equiv-tools/alive-tv-v20.0` untouched; `PINS.lock` not edited |

Reproduction: `commands.sh`. Build logs: `logs/build-cmake-llvm22.log`,
`logs/build-ninja-llvm22.log`.

## Upstream compatibility (measured, not inferred)

| Alive2 commit | Date | LLVM 22.1.8 build | Blocker |
|---|---|---|---|
| `c9af7dbb` (master) | 2026-10-19 | **fail** | `no type named 'UncondBrInst'`, `getLibFunc` signature (LLVM 23) |
| `4b336d3c` | 2026-02-27 | **fail** | `no member named 'getDeadOnReturnInfo' in 'llvm::Attribute'` (LLVM 23) |
| `2a6f34a3` | 2026-02-06 | **fail** | same LLVM-23 `getDeadOnReturnInfo` |
| **`0dc2be5f`** | 2026-01-21 | **builds** | — (parent of the sized-`dead_on_return` commit `fe897fd8`) |

The sized `dead_on_return` support (`fe897fd8`, 2026-01-22) and every later
commit use `Attribute::getDeadOnReturnInfo()`, which LLVM 22 does not have
(LLVM 22 exposes `Attribute::DeadOnReturn` and
`Argument::hasDeadOnReturnAttr()` only). Every Alive2 commit after 2026-01-22
therefore needs LLVM 23, and `master` additionally needs LLVM-23 branch APIs.
Tags: `v21.0` (2025-06-25) is the newest; **no `v22.0` exists**.

Consequence: an "Alive2 for LLVM 22" pin can only be a build of an upstream
commit ≤ `0dc2be5f`, or a fork with a backport.

## Probe results

### 1. Parse blocker is gone (B-03a resolved by the build)

* `llvm-as` 22.1.8 on the real `.ll`: **rc=0** (the v20 `expected ')' at end of
  argument list` on `ptr dead_on_return …` no longer occurs).
* `alive-tv real-r-195.bc real-r-195.bc`: runs to completion of the module and
  reports per-function translation results instead of aborting the file.
  351 defined functions, **9 translate**, 342 rejected.
* The module carries 54 `dead_on_return` attributes in 42 function signatures;
  one of them (`Vec::…::from_iter…`, the function named in the v20 error) was
  extracted and translated with the attribute **kept** (only its param
  `noalias` removed): `1 correct transformations`
  (`logs/…`, `probes/from_iter-195.ll`).

### 2. What still blocks: first-error inventory over the whole module

`logs/first-error-inventory.txt` (from `logs/full-module-selfcompare.out`):

| first error class | all functions | `rbitcoin*` functions |
|---|---:|---:|
| parameter `noalias` | 295 | 159 |
| atomic / other unsupported instruction | 25 | 16 |
| `metadata`-typed value (`llvm.dbg.*`) | 14 | 0 |
| `captures(address…)` (non-`none`) | 6 | 1 |
| `!noalias` metadata (kind 8) | 2 | 1 |
| **total rejected** | **342 / 351** | **177** |

`sret(...)` does not appear as a *first* error (attribute order hits `noalias`
first); it is fatal only on **definitions** (57 in the pin module) and merely
diagnostic on declarations (51).

### 3. Target function `eval_script`: the exact blocker chain

The 1.95 release module has **no standalone `verify_input` symbol** (inlined);
`eval_script` is the R engine entry that exists as a definition. Extracted
module (`probes/eval_script-195.ll.gz`) contains 63 param `noalias`,
223 `!noalias`, 61 `!alias.scope`, 18 `noalias.scope.decl`.

| step | stripped from the module | Alive2 result |
|---|---|---|
| p0 | nothing | `ERROR: Unsupported attribute: noalias` — **fatal** |
| pA | param `noalias` | `ERROR: Unsupported metadata: 8` — **fatal** |
| pB | + `!noalias`, `!alias.scope` | `ERROR: … @llvm.experimental.noalias.scope.decl(metadata …)` / `Unsupported type: metadata` — **fatal** |
| pC | + `noalias.scope.decl` calls | **translates**, `1 correct … (syntactically equal)`, `0 Alive2 errors` |

Logs: `logs/eval_script-p0-raw.out`, `-pA`/`-pB` (same directory),
`logs/eval_script-pC-translates.trimmed.out` / `.full.out.gz`.
The pC transform **kept** `!range`, `!nonnull`, `!noundef`, `!align`, all
`captures(...)` and all debug metadata — i.e. the minimum fatal class set is
exactly **param `noalias` + scoped alias metadata + `scope.decl`**, smaller than
`findings/rust/sanitize_ir.sh`, which also drops assumptions.

The 968 remaining `ERROR: Unsupported attribute: captures(address…)` lines in
pC are **non-fatal**: Alive2 prints the diagnostic and drops the attribute
(see §4). pC is a *self*-comparison: it proves ingestion, **not** equivalence.

Residual after the same three strips on the **whole module**
(`logs/mod-p3-first-error-inventory.txt`, `logs/mod-p3-summary.txt`; full log regenerable from `commands.sh`): 168 correct, **28 timeouts**
(`ERROR: Timeout`, 10 s), 155 functions still rejected — 57 `sret` definitions,
53 atomics/other instructions, 9 metadata kind 6 (`invariant.load`), 3 leftover
`noalias` (call-site), and 33 `captures` diagnostics that are non-fatal and may
mask a later fatal error. Even this maximal probe transform does not yield a whole-module proof.

### 4. Minimal per-feature repros (`probes/minimal/`)

| probe | result |
|---|---|
| `sret([24 x i8])` on a **definition** | `ERROR: Unsupported attribute: sret([24 x i8])` — fatal |
| `sret(...)` on a **declaration** | diagnostic only; callers still translate (51 of the module's 108 `sret` sigs are declarations) |
| `ptr noalias` param | `ERROR: Unsupported attribute: noalias` — fatal |
| `captures(address)` param | `ERROR: Unsupported attribute: captures(address)` but **non-fatal**: attribute is dropped and the function translates (`2 correct … (syntactically equal)`); see soundness note below |
| minimal `-O2` Rust probe (`probe.bc`) | `ERROR: Unsupported metadata: 8` (`!noalias`) — unchanged from F-TOOL-001 |

**Soundness caveat on `captures`.** Alive2 drops non-`none` `captures(...)`
from *both* sides with only a printed diagnostic (`errorAttr` return value is
ignored). Dropping a capture contract from a source **widens** the source's
allowed behaviour (the pointer may now escape arbitrarily), which makes the
refinement check weaker — this is an upstream soundness gap, not just noise.
It does not block ingestion, but any cell relying on capture contracts must
record it.

### 5. `dead_on_return` semantics (caveat)

Parsing and attribute handling work. The implementation
(`ir/instr.cpp`, `Return::toSMT`) poisons the pointee block when the
**verified function itself** returns. A caller-side effect of a *callee's*
`dead_on_return` is not modeled: both directions of a "store through the
pointer after the call returns" probe pass (`probes/minimal/dead_on_return-sem*.ll`).
For a source this is conservative (missing UB only strengthens the check); for
a target it is an Alive2-wide precision gap. Not a blocker for ingestion, but
it must be recorded if a cell relies on cross-function `dead_on_return`.

### 6. What current upstream still cannot do

Checked in `master` (`c9af7dbb`, 2026-10-19):

* no `llvm::Attribute::StructRet` case in `llvm2alive.cpp` → `sret(...)` still
  `Unsupported attribute`;
* `Attribute::NoAlias` is only mapped to `FnAttrs::NoAlias` (function/return
  attribute); parameter `noalias` is still unmapped, although
  `ParamAttrs::NoAlias` exists in the IR;
* `Attribute::Captures` → `if (capturesNothing(...)) … else errorAttr(...);`
  with `// TODO: support other captures` (`llvm2alive.cpp:1643`);
* no reference at all to `!alias.scope`/`!noalias` instruction metadata or to
  `llvm.experimental.noalias.scope.decl`;
* atomics (`load atomic`, `atomicrmw`, `cmpxchg`) remain unsupported.

So the blocker is not "an old Alive2": it is missing Alive2 features that
rustc 1.95/LLVM 22 emits by default.

### 7. Positive result: a narrow, surgery-free leaf lane exists

`script_code_bytes` (from the unmodified pin module) was compared against a
twin whose only change is `trunc nuw i64 %2 to i1` → `icmp eq i64 %2, 1`
(equivalent under the retained `!range [0,2)`). Source body is byte-identical
modulo the `@src` symbol rename; no attributes or metadata were removed.

```
Transformation seems to be correct!      # SMT proof, not "syntactically equal"
```

`logs/scb-pair-verify.out`, `probes/scb-pair.ll`. Six non-fatal
`Unsupported attribute: captures(address, read_provenance)` lines come from the
`slice_index_fail` **declaration**; the callee stays uninterpreted.

Functions that ingest unmodified (9/351): `alloc::boxed::box_new_uninit`,
`script_pool::help_steal`, `script_pool::on_steal_worker`,
`tx_precompute::block_wire_len_from_pres`, `policy::meets_min_relay_fee`,
`interpreter::script_code_bytes`, 2× `std::sys::thread_local…destroy`,
1 hash-set drop glue. None is on the engine path.

### 8. Compiler-flag / opt-level alternatives (both negative)

Construct counts per module (`logs/construct-metrics.txt`):

| metric | pin release | `-Z mutable-noalias=no -Z box-noalias=no` | `-O0` |
|---|---:|---:|---:|
| defined functions | 351 | 344 | 2,627 |
| param `noalias` | 714 | 527 | 2 |
| `sret(...)` sigs | 108 | 108 | **1,070** |
| `captures(address…)` | 233 | 229 | 1 |
| `dead_on_return` | 54 | 53 | 0 |
| `!noalias` attachments | 8,960 | 7,863 | 0 |
| `!alias.scope` attachments | 2,341 | 1,027 | 0 |
| `scope.decl` calls | 1,103 | 240 | 0 |
| atomics | 535 | 534 | 182 |

* The `-Z` lane still fails on param `noalias` and `sret` (captures is
  dropped non-fatally, see §4).
* The `-O0` lane removes all alias metadata and `dead_on_return`, but
  `eval_script` at `-O0` still stops at
  `ERROR: Unsupported attribute: sret([24 x i8])`.
* For reference, the advisory rustc 1.88/LLVM-20 artifact also carries
  `sret` (368), param `noalias` (4,118) and `!noalias` (9,247); its reported
  "ingestion" depends on `sanitize_ir.sh` stripping those classes.

**No rustc invocation probed produces Alive2-ingestible IR.** Rust's ABI uses
`sret` for returns wider than 16 bytes (e.g. `Result<…>`), and LLVM 22 emits
precise `captures`/`dead_on_return` in release builds, independently of the
alias-metadata flags.

## Why stripping is not an admissible fix

* Alive2 refuses unknown metadata on the **source** deliberately
  (`llvm2alive.cpp:1507-1513`: "For the target, dropping metadata is fine …").
  Dropping UB-bearing metadata (`!noalias`, `!alias.scope`) from a source
  yields a *stronger* obligation and is arguably conservative, but that
  argument is per-kind: the same transform also drops `!noundef`/`!range`/
  `!nonnull` (as `sanitize_ir.sh` does), which widens the source and is
  unsound. No per-kind obligation has been written or reviewed for the R leg.
* `sret`/`captures` are ABI attributes, not hints; rewriting the signature to
  a pointer return changes the function contract.
* Any stripped module has a different hash and is **not** the pin artifact.
* F-TOOL-001 already forbids stripping as a proof step; brief rule 5 forbids
  weakening preconditions for a green marker. This probe follows that.

If a transform lane were ever wanted, it needs: a written per-kind soundness
obligation, a contract review, a new artifact hash in `PINS.lock`, and
re-certification of every cell that cites it. That is a re-pin, not a probe.

## Options and recommendation

| Option | Feasible now | Admissible | Covers engine rows |
|---|---|---|---|
| **A. Upgrade Alive2** (LLVM-22 build of `0dc2be5f`) | yes, built here | only for construct-free leaves | **no** — 177/177 rbitcoin engine-path functions rejected |
| A′. Upgrade + upstream feature work (param `noalias`, `sret`, precise `captures`, scoped alias metadata + `scope.decl`, atomics) and an LLVM-22-targeted release | no | would be | yes, eventually |
| **B. Controlled compiler/pin change** (1.88/LLVM 20, `-O0`, `-Z` flags) | yes | not at pin | no — still rejected (`sret` etc.) and non-pin |
| **C. Leaf-only Alive2 lane at pin** (unmodified IR) | yes | yes, for the 9 listed leaves | no |
| **D. Accept C-L only; R SAW-only** | yes | yes | yes (via C-L) |

**Recommendation: D now, with C as an optional add-on, and A′ as the only
engine-level path.**

1. For PR #29: do not claim R/Alive2. Keep R cells SAW-only with
   `alive2/inapplicable.md` citing this report; keep C-L as the engine
   equivalence lane.
2. Optional (proposal only, needs a new `[tools]` pin and cell review): adopt
   the LLVM-22-built `0dc2be5f` binary for **construct-free leaf** cells
   (self-comparison = ingestion only; a real cell needs a spec twin like
   `scb-pair.ll`). Value is limited to leaves.
3. Do not pursue a re-pin to rustc 1.88/LLVM 20, `-O0`, or `-Z` flags as an
   R/Alive2 fix: measured, they do not yield ingestible IR, and they are not
   the pin.
4. If engine-level R/Alive2 is a goal beyond this PR, file upstream Alive2
   issues for parameter `noalias`, `sret`, precise `captures`, and scoped alias
   metadata/`scope.decl` (no tracking issues found for `sret` or
   `captures(address)` as of 2026-10-20), and separately request an LLVM-22
   branch build.

## Exact blockers (for the ledger)

* **B-03a (resolved by build, not by pin)** — `dead_on_return` parse: fixed by
  building Alive2 against LLVM 22. No upstream release supports LLVM 22; the
  newest buildable upstream commit is `0dc2be5f`.
* **B-03b** — parameter `noalias`: 295/342 first errors, 159/177 rbitcoin.
  Unsupported in `master`.
* **B-03c** — `sret([N x i8])` **on definitions**: 57 definitions (and 1,070 at
  `-O0`); declarations only produce a diagnostic. Unsupported in `master`.
* **B-03d (soundness, not ingest)** — precise
  `captures(address[, read_provenance])…`: 233 signature attributes. Only
  `captures(none)` is modeled; Alive2 prints a diagnostic and **drops** the
  rest on both sides, widening the source. Upstream `master` TODO
  (`llvm2alive.cpp:1643`).
* **B-03e** — `!noalias`/`!alias.scope` instruction metadata and
  `llvm.experimental.noalias.scope.decl`: 8,960 / 2,341 / 1,103 occurrences.
  Unsupported in `master`.
* **B-03f** — atomics and `metadata`-typed values: 25 + 14 first errors
  (std/`mpsc`, `llvm.dbg.*`); not on the single-input engine path but blocks
  whole-module runs.
* **B-03g (minor)** — caller-side `dead_on_return` effect unmodeled; source
  direction is conservative.

## Non-claims

* No R-vs-C or R-vs-L equivalence proof was run; no row is promoted.
* `eval_script` pC is a self-comparison (ingestion), not a proof.
* `scb-pair.ll` is a synthetic probe, not a cell; its twin is not a spec.
* The built binary is scratch, not installed, and not a pin.
* `PINS.lock`, contract, Lean, census and result files are untouched.
