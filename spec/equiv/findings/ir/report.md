# IR-leg report — canonical C/L/R artifacts and tool ingestion

**Role:** IR
**Date:** 2026-10-19
**Write scope:** `spec/equiv/ir/` and `spec/equiv/findings/ir/` only. No commits.
**Status:** all three IR legs built; tool ingestion exercised; **no equivalence
claim**. The `alive-tv` “incorrect” results (one L `cast_to_bool` run and two
Core `-O1` transformations) are preserved verbatim and handed to
TWIN/REDTEAM for triage.

Path convention: `artifacts/...` below means
`/tmp/opencode/ir-pipeline/artifacts/...`, the scratch area holding the
regenerable bitcode and raw tool logs.

---

## 1. Pins and producers

| leg | source | producer | target triple |
|---|---|---|---|
| C | Bitcoin Core v32.99 `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` | clang++ 20.1.2 (LLVM 20.1.2) | `x86_64-pc-linux-gnu` |
| L | `spec/equiv/twin` generator, input hashes below | clang++ 20.1.2 (LLVM 20.1.2) | `x86_64-pc-linux-gnu` |
| R | rbitcoin `ae47aa98174e04d0d8c493f13041daf65e4ac1d3` | rustc 1.95.0, LLVM 22.1.2 | `x86_64-unknown-linux-gnu` |

`PINS.lock` was read, not edited. C and R were built from fresh clones at the
pins with an empty `git status`. R has no `ffi.rs` and no `equiv_entry`; the
`equiv-ffi` feature was not enabled. The C module uses real Core translation
units (15 TUs); no test-only `FileCommit`/`TruncateFile` stubs are linked.

### Toolchain mismatch determination

**No producer, triple, or datalayout mismatch was used as a substitute.**

* C and L are from clang 20.1.2; R is from the pinned rustc 1.95.0/LLVM 22.1.2.
  These are different front-ends by design, not a substituted proof lane.
* C/L target `x86_64-pc-linux-gnu`; R target `x86_64-unknown-linux-gnu`. The
  vendor field differs because clang and rustc spell the same Linux target
  differently.
* Every artifact has the same datalayout:
  `e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128`.
* `make_manifest.py` reports
  `producer_triple_datalayout_mismatches: []` and
  `all_recorded_hashes_match: true`.

The only cross-version conversion is the explicitly non-pin R derivative in
§2.3. It is not used as a pin artifact.

**Flagged PINS prose inconsistencies (no artifact substitution):**
`PINS.lock` `[rbitcoin] toolchain` names rustc 1.95.0/LLVM 22.1.2 and matches
`rust-toolchain.toml`, but `[rbitcoin] build` still describes a
`cargo +1.88.0` advisory IR lane. This pipeline followed the task requirement
and the repo toolchain: R was built with rustc 1.95.0/LLVM 22.1.2. No 1.88
artifact is used or substituted; see IR:F-PIN-002. Separately, `[core.ir]`
records a single-TU build with different hashes from this 15-TU closure; that
is an artifact-scope difference, not a source/toolchain substitution. See
IR:F-PIN-001.

---

## 2. Build results

All build scripts completed; reruns of the C and R scripts produced identical
bytes. The L build was rerun after `twin/gen.py` stabilised; `twin.cpp` and both
L artifacts were unchanged.

| artifact | leg | opt | bytes `.bc` / `.ll` | defined / undefined symbols |
|---|---|---|---:|---:|
| `core-interpreter-O0` | C | -O0 | 717,624 / 4,155,864 | 1759 / 78 |
| `core-interpreter-O1` | C | -O1 | 458,892 / 2,291,851 | 343 / 80 |
| `twin-O0` | L | -O0 | 70,024 / 491,541 | 108 / 7 |
| `twin-O1` | L | -O1 | 62,368 / 362,701 | 61 / 5 |
| `rust-consensus-O0` | R | dev (opt-level=0) | 1,639,992 / 7,282,473 | 2635 functions (text count) / not enumerated |
| `rust-consensus-O0-v20` | R derivative | dev | 1,653,192 / 6,462,187 | 2651 / 590 |
| `rust-verify-input-O0` | R extract | dev | 9,440 / 27,539 | 1 / 35 |
| `rust-is-op-success-O0` | R extract | dev | 2,696 / 2,903 | 1 / 2 |

`llvm-nm-20` cannot read the raw R bitcode, so its symbol count comes from the
textual IR and counts functions only; the v20 count comes from `llvm-nm` and
includes globals. The two counts are not directly comparable.

Full byte hashes (sha256):

| artifact | bitcode | textual IR |
|---|---|---|
| `core-interpreter-O0` | `204cf6711ca56738eccd9d8034fe40e39b01e6f070e286f0882d3fd5956c0975` | `27574bda73da82a67add097aa8275decc64b823e1df11c75f32688cc7b08d18e` |
| `core-interpreter-O1` | `586da352f64b93967d7566e54a2dcb78466b660990ed8b56954afe0a13702b90` | `27158c6a4edb9a95caf5d3670c51f00d8e267fae390d8d6f7c9bba3a52a918ab` |
| `twin-O0` | `81af359c2e3d045ab775875d32fcca577a2bb9585cf72d97c2f412c5c33f07d0` | `f1df37583639a9542178981a86a94945109253730b1d47eefebbe84e7dd64751` |
| `twin-O1` | `654e1180798bb59f4a3b4f18f2eee90bd860b1af6ac2164be64268eb5a866416` | `15e077d461090588f280cf0a60a40c1c27d5ff1f833210e54421af1013480817` |
| `rust-consensus-O0` | `e54b5c1976c20d442c52d2793bd80c37b3d845bc1c9058dfbc9bb2f70eb84df7` | `2610d07aaf4a203942e8ace14e1b4cc85723417e316f4d0be0fe45f84890e15b` |
| `rust-consensus-O0-v20` | `e39c1d29d8f0ef09d9f94cff67dd4bfd59bd7f4b04520e7b98e6a8f98524ebb1` | `f5e1bbf72d892b79b20a7fd97810bcd6e54996a4aa538f25cd15edbabe1fa6b1` |
| `rust-verify-input-O0` | `c329983c36b60f4b6c565a92852217470849054df03aa57b9f92183152676b0f` | `a4a236fe990ff9a2f39449b58e3abb3dd24d359c97b44422277ba2305a03b8e3` |
| `rust-is-op-success-O0` | `84205f25deea1751f1320f1a16c1bda9f39211ffb1db962ebccc4232bbc5eec7` | `40588b9f8ed61451723e376db22943ebd92908b934ad86003f88bea95c80c29c` |

Artifacts live under `/tmp/opencode/ir-pipeline/artifacts/`; the repository
gitignores `*.bc` and build output. `spec/equiv/ir/manifest.json` is the
authoritative record of commands, source hashes, artifact hashes, symbols, and
smoke output. Complete symbol lists are in `spec/equiv/ir/symbols/`. The final
manifest hash is
`bef064dbca8c9884906ad8eec8922ca8ae369fb0479db7c0659c30ca7ad8808e`
(sha256).

### 2.1 C leg

Core’s CMake was used only to generate `bitcoin-build-config.h` and
`compile_commands.json`; the node/test binaries were not built. The 15 TUs
listed in `build_core.sh` were compiled from the Core tree with relative paths,
then linked with `llvm-link` and disassembled with `llvm-dis`. The base flags
are Core’s own compile flags with only `-O`, `-g`, `-o`, and `-c` replaced.
`libsecp256k1`, libc, and libstdc++ remain real external declarations. The
defined/undefined symbol lists contain no `FileCommit` or `TruncateFile`, and
the 17 `secp256k1_*` entries are declarations of the real C API, not replaced
bodies.

The artifact is the script/interpreter TU closure, not the full node. It does
not contain the reviewed `equiv_entry` shim.

### 2.2 L leg

The generator’s drift gate passed on both the checked-in and freshly generated
`twin.cpp`. The generated copy was compiled from its own directory with a
relative path so `source_filename` is `twin.cpp` and the hash is independent of
the scratch directory.

The exact L build inputs were preserved in
`artifacts/twin-src/`:

* `gen.py` `b3f2aeb9048e0ed1e144fd90f5f4e4e258ae5004e048d13fc5116895ae30a7ec`
* `ops_ir.py` `6f0d5531c7f7df919f698e190f31568caa7cbffce866579618f667bb58eeb4c5`
* `runtime.inc` `465388db548f053bd06dbc93f1620600f7233cbcfb58f410ff505c6c5828725c`
* generated `twin.cpp` `39ab7c66ea112ea0108e6f2b93c6bbb8ad0b8261f3230310c989cb8d0af2478f`
* `contract/error_kind.h` `7a5f778f4aed8947a7768da3d3856c99eec2715f5502cb8f59af576c72dca170`

`twin/` has no VCS pin in `PINS.lock` and is owned by another role. During this
run `gen.py` changed twice; the final rebuild was made after `gen.py` reached
the hash above and the drift gate was green. An earlier `gen.py`
(`f2c2e014…`) generated the same `twin.cpp` and therefore the same L IR; the
snapshot is retained so the artifact does not depend on the moving checkout.

### 2.3 R leg

The clean clone was built offline with:

```sh
CARGO_TARGET_DIR=<target> RUSTUP_TOOLCHAIN=1.95.0 CARGO_NET_OFFLINE=true \
cargo rustc --offline -p rbitcoin-consensus --lib --profile dev -- \
  -C codegen-units=1 -C debuginfo=0 --emit=llvm-ir,llvm-bc
```

The pin artifact is the raw rustc LLVM-22 `.bc`/`.ll`. The `-v20` derivative
removes the LLVM-22-only `nocreateundeforpoison` parameter attribute and
reassembles with LLVM 20 tools. `llvm-diff-20` reports no structural difference
between the stripped text and the reassembled module. This is a **conversion,
not the pin**. No cell may cite the derivative as R-at-pin.

`verify_input` is
`_ZN18rbitcoin_consensus6script12verify_input17hbf7966be323ade2eE`; the smoke
leaf is
`_ZN18rbitcoin_consensus6script11interpreter13is_op_success17h56e4847c359ed00eE`.
Both were extracted from the v20 module with `llvm-extract`.

---

## 3. Smoke results

Tools: Alive2 v20.0 (LLVM 20.1.2, Z3 4.8.12) and SAW 1.6 (68eed5f).
`smoke.sh` runs 19 checks: `alive-tv` and `saw llvm_load_module` on each
artifact, plus targeted `--func` runs where the whole module is too large. Raw
stdout/stderr is in `artifacts/smoke/`; the machine-readable copy is
`artifacts/smoke/smoke.json` and is embedded in `manifest.json`.

**Important:** one-file `alive-tv` mode optimises the module with an O2-like
pipeline and checks that the optimised functions refine the originals. It is
not a C⇔L⇔R proof and is not even a pure self-comparison of identical IR. A
timeout, parse error, or translation error is a capability result, never a
pass.

| artifact | `alive-tv` result | SAW load |
|---|---|---|
| C `-O0` | whole module: **timeout** (unsupported `invoke`); targeted `CastToBool`: **1 correct** | **loads** |
| C `-O1` | whole module: **9 correct, 2 incorrect, 1 unproven, 256 Alive2 errors**; targeted `CastToBool`: translation error (`nocapture`) | **loads** |
| L `-O0` | whole module: **timeout** (partial error: `Target is more poisonous than source`); targeted `cast_to_bool`: **1 incorrect** (null/0 counterexample) | **loads** |
| L `-O1` | whole module: **4 correct, 1 unproven, 45 Alive2 errors** | **loads** |
| R raw | **cannot read bitcode**: `Unknown attribute kind (105)` | **load fails**: `PtrOpaque` in `atomicrmw` |
| R v20 module | **timeout** (unsupported `invoke`) | **load fails** at the same `atomicrmw` |
| R `verify_input` | translation error: `sret([24 x i8])` unsupported | **loads** |
| R `is_op_success` | **1 correct** (O2-pipeline check of the leaf) | **loads** |

The C `-O1` and L `-O1` whole-module runs reached summaries; the C `-O0`,
L `-O0`, and R v20 whole-module runs timed out within the 120 s budget. Those
timeouts are not evidence for or against equivalence.

---

## 4. Findings

Local IDs are used here; this report does not promote them to the global
`F-*` namespace.

### IR:F-TOOL-001 — Alive2 v20 cannot read the raw rustc 1.95/LLVM-22 R artifact

* **legs:** R
* **cell:** n/a (tool ingestion)
* **symptom:** Alive2 v20.0 (LLVM 20.1.2) rejects `rust-consensus-O0.bc`
  (`e54b5c1976c20d44…`) before translation:
  `Unknown attribute kind (105) (Producer: 'LLVM22.1.2-rust-1.95.0-stable'
  Reader: 'LLVM 20.1.2')`.
* **evidence:** `artifacts/smoke/alive-rust-raw.alive.log`; command
  `/opt/equiv-tools/alive-tv-v20.0 rust-consensus-O0.bc`.
* **disposition:** tool-gap / open.
* **notes:** This is the same class as global `F-TOOL-001`; the raw artifact
  remains the pin. The `-v20` derivative exists only to probe the rest of the
  module with LLVM-20 tools. It is not a substitute for R-at-pin and must not
  be cited as one.

### IR:F-TOOL-002 — SAW 1.6 cannot load a whole Rust module with opaque-pointer `atomicrmw`

* **legs:** R
* **cell:** n/a (tool ingestion)
* **symptom:** `llvm_load_module` exits 2 with
  `Expected integer or float operand, found PtrOpaque`, at
  `FUNC_CODE_INST_ATOMICRMW` in
  `_ZN3std4sync4mpmc4list16Channel...discard_all_messages...`. The same
  failure occurs for the raw and v20 whole-crate modules.
* **evidence:** `artifacts/smoke/saw-rust-raw.saw.log` (artifact
  `e54b5c1976c20d44…`), `artifacts/smoke/saw-rust-v20-module.saw.log`
  (artifact `e39c1d29d8f0ef09…`).
* **disposition:** tool-gap / open.
* **notes:** SAW 1.6 **does** load the extracted `verify_input` and
  `is_op_success` modules. A whole-crate SAW proof is therefore not available
  without a smaller call-graph closure or a SAW version with opaque-pointer
  atomic support.

### IR:F-TOOL-003 — Alive2 translation gaps on real C and R IR

* **legs:** C, L, R
* **cell:** n/a (tool ingestion)
* **symptom:** Alive2 v20 reports, verbatim:
  * C `-O1`, `CastToBool`: `ERROR: Unsupported attribute: nocapture`;
  * C `-O0`, whole module: `ERROR: Unsupported instruction: %45 = invoke ...`;
  * R `verify_input`: `ERROR: Unsupported attribute: sret([24 x i8])`;
  * R v20 whole module: `ERROR: Unsupported instruction: %_8 = invoke ...`;
  * further C errors: `Unsupported metadata: 1`, `sret(%class.uint256)`,
    `noalias`, and unsupported `invoke`.
* **evidence:** `artifacts/smoke/alive-core-O1-CastToBool.alive.log` (C `-O1`
  `586da352…`), `alive-core-O0-module.alive.log` (C `-O0` `204cf671…`),
  `alive-rust-verify-input.alive.log` (`c329983c…`),
  `alive-rust-v20-module.alive.log` (`e39c1d29…`),
  `alive-core-O1-module.alive.log`.
* **disposition:** tool-gap / open.
* **notes:** `nocapture` is accepted on some functions in the same module but
  rejected on the targeted `CastToBool` at `-O1`; this is an Alive2
  translation limitation, not a proof that `CastToBool` is wrong. `sret` and
  `invoke` are ordinary ABI/exception features of the real artifacts and must
  be handled by closure extraction or a tool version that supports them.

### IR:F-OPT-001 — L `cast_to_bool` O2-pipeline check reports 1 incorrect (null/0)

* **legs:** L
* **cell:** n/a (optimizer validation, not C⇔L)
* **symptom:** `alive-tv --func=_ZN4twinL12cast_to_boolEPKhj twin-O0.bc`
  reports `Source is more defined than target` with
  `ptr %#0 = null`, `i32 %#1 = 0`, and target `i1 %.not16 = UB triggered!`.
  The target has inferred `ptr nonnull` on `%#0`; the source returns `false`
  for `len == 0` without dereferencing the pointer.
* **evidence:** `artifacts/smoke/alive-twin-O0-cast_to_bool.alive.log`; L
  artifact `81af359c2e3d045a…`.
* **disposition:** open — TWIN/REDTEAM triage.
* **notes:** This is the O2-like pipeline that `alive-tv` applies in one-file
  mode, not a comparison of the L artifact against C. It is a candidate
  optimizer unsoundness (or an Alive2 attribute/model issue), not evidence
  that the twin source is wrong. Preserve the counterexample; do not “fix” the
  artifact by hand. The L `-O0` whole-module run also timed out after emitting
  `Target is more poisonous than source`; with no summary it is not counted as
  a separate result.

### IR:F-OPT-002 — C `-O1` whole-module check reports 2 incorrect

* **legs:** C
* **cell:** n/a (optimizer validation, not C⇔L)
* **symptom:** whole-module `alive-tv` on `core-interpreter-O1.bc` reports
  9 correct, **2 incorrect**, 1 failed-to-prove, 256 Alive2 errors. Both
  counterexamples are in
  `GenericTransactionSignatureChecker<CTransaction>::VerifySchnorrSignature`
  and its `CMutableTransaction` twin. They show `%#1 = poison`; the source is
  reported as “function did not return”, while the target reaches a call to
  `@secp256k1_xonly_pubkey_parse` that triggers UB.
* **evidence:** `artifacts/smoke/alive-core-O1-module.alive.log`; C `-O1`
  artifact `586da352f64b9396…`; counterexample starting at the
  `Source is more defined than target` block.
* **disposition:** open — CORE/REDTEAM triage.
* **notes:** These counterexamples involve external libsecp256k1 contracts and
  O2 assumptions. They are not evidence that Core’s Schnorr verification logic
  is wrong, and they are not a C⇔L result. The `-O0` primary artifact does not
  reproduce them because the whole-module run times out.

### IR:F-PIN-001 — `PINS.lock` `[core.ir]` describes a single-TU artifact, not this 15-TU closure

* **legs:** C
* **cell:** every C cell that cites `PINS.lock [core.ir]`
* **symptom:** `PINS.lock [core.ir]` names a single-TU build of
  `script/interpreter.cpp` with O0 hash
  `f5718af79c56ccfd5a5437a313d957573cb87c0de0cdf5641013991268801b2c` and O1
  hash `01003ec095441bad8ada96ed1effa860f84bda23802841c7d7eb15b2e554537f`.
  This IR pipeline builds an `llvm-link`ed 15-TU script-layer closure with O0
  hash `204cf6711ca56738…` and O1 hash `586da352f64b9396…` (see §2).
* **evidence:** `PINS.lock` lines 9 and 16–20; `manifest.json` `legs[C]`
  (`translation_units`, artifact hashes); `build_core.sh`.
* **disposition:** open — ORCHESTRATOR/PIN owner.
* **notes:** Both are unpatched Core source at the pin; the difference is
  artifact scope, not a source or toolchain substitution. A cell must cite the
  exact hash it consumes. The 15-TU closure was chosen so `VerifyScript`,
  `EvalScript`, sighash, and the crypto TUs are present without test stubs;
  it is not the `[core.ir]` single-TU artifact and must not be labelled as such.
  `PINS.lock` was not edited by the IR role.

### IR:F-PIN-002 — `PINS.lock` R build prose describes a 1.88 lane

* **legs:** R
* **cell:** every R cell that cites `PINS.lock`
* **symptom:** `PINS.lock` `[rbitcoin] toolchain` says rustc
  1.95.0/LLVM 22.1.2, but `[rbitcoin] build` (line 40) says
  `cargo +1.88.0 rustc --release ...`. This pipeline built R with rustc
  1.95.0/LLVM 22.1.2, as required by the task and by the repo’s
  `rust-toolchain.toml`.
* **evidence:** `PINS.lock` lines 37–40; `manifest.json` `legs[R].producer`
  (`toolchain: 1.95.0`, `llvm: 22.1.2`); `artifacts/logs/rust-build.log`.
* **disposition:** open — ORCHESTRATOR/PIN owner.
* **notes:** No 1.88 artifact was used and no toolchain was substituted. The
  1.95 raw artifact is the pin producer; the v20 derivative is conversion-only.
  The PINS prose should be reconciled by its owner before a cell cites it.
  `PINS.lock` was not edited by the IR role.

### IR:F-PROV-001 — `twin/` is a moving target with no VCS pin

* **legs:** L
* **cell:** every L cell
* **symptom:** `twin/gen.py`, `twin/ops_ir.py`, and `twin/runtime.inc` changed
  during the run; at one point the checked-in `twin/build/twin.cpp` no longer
  matched the generator output and the drift gate failed. A later generator
  revision produced the same `twin.cpp`, and the final rebuild passed the
  gate with all three inputs snapshotted.
* **evidence:** `artifacts/twin-src/` (exact `gen.py`, `ops_ir.py`,
  `runtime.inc`, `twin.cpp`, `twin.ir.json`); hashes in `manifest.json`
  (`legs[L].source`); logs `artifacts/logs/twin-check-*.log`.
* **disposition:** open — TWIN/ORCHESTRATOR.
* **notes:** The L artifact is pinned by generator-input hashes, not by a
  repository commit. A cell that uses L must cite the snapshot hashes above.
  Rebuild only when `twin/` is quiescent; the drift gate will fail loudly
  otherwise. This is a provenance risk, not a semantic result.

### IR:F-DERIV-001 — R v20 artifact is a conversion, not the pin

* **legs:** R
* **cell:** any cell that uses the derivative
* **symptom:** the raw rustc LLVM-22 artifact is unreadable by LLVM-20 tools
  (IR:F-TOOL-001). The derivative removes exactly
  ` nocreateundeforpoison` (17 occurrences) and reassembles with `llvm-as-20`.
* **evidence:** `build_rust.sh`; `artifacts/logs/rust-llvm-diff.log` (empty
  output, exit 0); manifest entry `rust-consensus-O0-v20` with
  `kind: llvm20-normalised-derivative`.
* **disposition:** domain-restricted.
* **notes:** The pin artifact is `rust-consensus-O0.bc`
  (`e54b5c19…`). The derivative (`e39c1d29…`) may be used only for
  tool-capability smoke or for a cell that explicitly records the conversion
  as part of its trust assumptions. It must not be reported as unmodified
  R-at-pin. This does not override the “do not strip attributes to force
  ingestion” rule in global `F-TOOL-001`: no green cell may rely on the
  derivative as a proof input.

---

## 5. What is and is not established

**Established:**

* Reproducible byte-identical IR for the pinned C source, the generated L
  source, and the pinned R crate.
* The C module is the real script/interpreter TU closure with real
  libsecp256k1 declarations, not a stub build.
* The R module is a clean pin build with no FFI patch.
* Both tools can read the C and L bitcode (SAW loads them whole; Alive2
  parses and translates the listed functions). SAW can load the extracted R
  `verify_input` and `is_op_success` functions.
* Alive2 accepts the C `-O0` `CastToBool` and the R `is_op_success` leaf under
  its O2-pipeline check.
* All recorded artifact hashes match on re-hash; producer/triple/datalayout
  checks are clean.

**Not established:**

* C ⇔ L ⇔ R equivalence, refinement, or any cell verdict.
* Full-module Alive2 verification of Core, the twin, or rbitcoin.
* Whole-crate SAW verification of rbitcoin.
* That the R derivative is the pin artifact.
* That any Alive2 “incorrect” result is a source bug; the L and Core
  counterexamples are optimizer/tool observations that require triage.

## 6. Reproduction and next steps

From `spec/equiv/ir/`:

```sh
./build_core.sh
./build_twin.sh
./build_rust.sh
./smoke.sh
python3 make_manifest.py
```

`build_twin.sh` must be rerun only while `twin/` is stable; it snapshots the
generator inputs and refuses to publish if they change mid-build. Re-run
`smoke.sh` after any artifact rebuild; its JSON summary and the manifest embed
the raw results.

Next actions:

1. TWIN/REDTEAM: triage IR:F-OPT-001 (`cast_to_bool`, null/0).
2. CORE/REDTEAM: triage IR:F-OPT-002 (Core `-O1`, poison + external
   libsecp256k1 UB).
3. IR/TOOL: extract smaller call-graph closures for C and R so `alive-tv` and
   SAW do not have to ingest whole modules with `invoke`, `sret`, and opaque
   atomics.
4. ORCHESTRATOR/PIN owner: reconcile `PINS.lock` `[core.ir]` and
   `[rbitcoin] build` with the artifact identities in this manifest
   (IR:F-PIN-001, IR:F-PIN-002), and decide whether `spec/equiv/twin` gets a
   stable pin; until then L cells must cite `artifacts/twin-src/` hashes.
