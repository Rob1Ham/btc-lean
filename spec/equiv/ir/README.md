# `spec/equiv/ir/` — canonical LLVM IR for the three-leg workstream

This directory owns the **IR artifacts** used by Alive2 v20.0 and SAW 1.6, not
any equivalence claim. It contains reproducible build scripts, the provenance
manifest, raw smoke output, and the symbol lists for every artifact.

Built 2026-10-19 against:

| leg | source | producer |
|---|---|---|
| C | Bitcoin Core v32.99 @ `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` | clang++ 20.1.2 (LLVM 20.1.2) |
| L | `spec/equiv/twin` generator (see §4) | clang++ 20.1.2 (LLVM 20.1.2) |
| R | rbitcoin @ `ae47aa98174e04d0d8c493f13041daf65e4ac1d3` | rustc 1.95.0 (LLVM 22.1.2) |

Both C and L are emitted at `-O0` (primary) and `-O1` (robustness). R is a
`dev`-profile (`opt-level=0`) build.

> **No equivalence is claimed here.** These artifacts are inputs to proof
> cells. `alive-tv` smoke runs below are self-refinement checks or ingestion
> checks, not C ⇔ L ⇔ R proofs. See `findings/ir/report.md` for what failed
> and why.

---

## 1. Contents

| path | role |
|---|---|
| `build_core.sh` | configure Core (CMake, no node build), compile the script-layer TUs, link + disassemble IR |
| `build_twin.sh` | run the twin drift gate, generate to scratch, re-check, compile |
| `build_rust.sh` | clean rbitcoin clone, `cargo rustc` with `--emit=llvm-ir,llvm-bc`, nm lookup, LLVM-20 normalisation |
| `smoke.sh` | `alive-tv` and `saw llvm_load_module` on every artifact; raw logs |
| `make_manifest.py` | merge provenance fragments, re-hash every file, write `manifest.json` |
| `manifest.json` | authoritative pins, commands, source/output hashes, per-artifact functions |
| `symbols/*.txt` | complete defined/undefined symbol lists per artifact |
| `findings/ir/report.md` | build log, failures, findings, tool-capability results |

Artifacts themselves are written outside the repository (the repo's
`.gitignore` excludes `*.bc` and treats build output as regenerable):

```
/tmp/opencode/ir-pipeline/artifacts/
  core-interpreter-O0.bc / .ll
  core-interpreter-O1.bc / .ll
  twin-O0.bc / .ll
  twin-O1.bc / .ll
  rust-consensus-O0.bc / .ll              raw rustc 1.95 (pin producer)
  rust-consensus-O0-v20.bc / .ll          LLVM-20-normalised derivative
  rust-verify-input-O0.bc / .ll           extracted single-input verifier
  rust-is-op-success-O0.bc / .ll          extracted smoke leaf
  twin-src/                               exact twin generator snapshot
  fragments/                              per-leg provenance
  smoke/                                  raw tool output
```

`IR_BUILD_ROOT`, `ARTIFACTS_DIR`, `CORE_SRC`, `RBTC_SRC` override the defaults.

---

## 2. Canonical outputs

Full sha256 values are in `manifest.json` (`legs[].artifacts[]`); the first 16
hex digits are shown here for orientation.

| artifact | leg | bytes (.bc/.ll) | sha256 (.bc, prefix) | contains |
|---|---|---|---:|---|
| `core-interpreter-O0` | C | 717,624 / 4,155,864 | `204cf6711ca56738` | `VerifyScript`, both `EvalScript` overloads, `CastToBool`, `CheckSignatureEncoding`, `FindAndDelete`, sighash helpers, script/crypto TUs |
| `core-interpreter-O1` | C | 458,892 / 2,291,851 | `586da352f64b9396` | same public entry points, inlined internals |
| `twin-O0` | L | 70,024 / 491,541 | `81af359c2e3d045a` | `equiv_entry`, `entry`, `twin_entry`, op handlers, parser, stack |
| `twin-O1` | L | 62,368 / 362,701 | `654e1180798bb59f` | `equiv_entry`, `entry`, `twin_entry` (internals inlined) |
| `rust-consensus-O0` | R | 1,639,992 / 7,282,473 | `e54b5c1976c20d44` | whole `rbitcoin-consensus` crate (2,635 defined functions), LLVM 22 bitcode |
| `rust-consensus-O0-v20` | R | 1,653,192 / 6,462,187 | `e39c1d29d8f0ef09` | same module re-assembled by LLVM 20 (derivative, not pin) |
| `rust-verify-input-O0` | R | 9,440 / 27,539 | `c329983c36b60f4b` | single-input verifier `script::verify_input` |
| `rust-is-op-success-O0` | R | 2,696 / 2,903 | `84205f25deea1751` | `script::interpreter::is_op_success` (smoke leaf) |

Every artifact has `target datalayout =
"e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"`.
Triples: C/L `x86_64-pc-linux-gnu`, R `x86_64-unknown-linux-gnu` (as pinned).
`make_manifest.py` fails on any producer/triple/datalayout divergence.

`symbols/<id>.defined.txt` is the complete function/symbol list; the manifest
also records a short `key_functions` list and demangled names.

> **Artifact-identity note.** `PINS.lock` `[core.ir]` names a different,
> single-TU C artifact, and `[rbitcoin] build` still describes an advisory
> rustc 1.88 IR lane. This directory’s C artifact is the 15-TU closure above,
> and R is the raw rustc 1.95/LLVM 22.1.2 build. No PINS file was edited here;
> cells must cite these manifest hashes and their exact scope. See
> `findings/ir/report.md` IR:F-PIN-001 and IR:F-PIN-002.

---

## 3. Reproduce

Prerequisites (all present on this host):

```
/usr/bin/clang++-20                  # Ubuntu clang 20.1.2
/usr/lib/llvm-20/bin/{llvm-link,llvm-dis,llvm-nm,llvm-as,llvm-extract,llvm-diff}
rustup toolchain 1.95.0              # rustc 1.95.0, LLVM 22.1.2
cmake 3.28.3                         # Core configure only
/opt/equiv-tools/alive-tv-v20.0
/opt/equiv-tools/saw-1.6/bin/saw
```

Clean clones at the pins (the scripts verify HEAD and an empty `git status`):

```sh
mkdir -p /tmp/opencode/ir-pipeline
git clone --no-hardlinks /tmp/opencode/equiv-work/bitcoin /tmp/opencode/ir-pipeline/bitcoin
git -C /tmp/opencode/ir-pipeline/bitcoin checkout --detach cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66

git clone --no-hardlinks /tmp/opencode/equiv-work/rbitcoin /tmp/opencode/ir-pipeline/rbitcoin
git -C /tmp/opencode/ir-pipeline/rbitcoin checkout --detach ae47aa98174e04d0d8c493f13041daf65e4ac1d3
```

Then:

```sh
cd spec/equiv/ir
./build_core.sh
./build_twin.sh
./build_rust.sh
./smoke.sh                    # ~8 min: three whole-module runs hit the timeout
python3 make_manifest.py      # exits non-zero on hash / producer mismatch
```

The scripts abort on:

* a source tree not at the pin or not clean (C and R);
* a clang/rustc version other than the pin;
* an FFI file or `equiv_entry` in the R clone;
* twin drift (`gen.py --check`) or twin generator inputs changing mid-build.

---

## 4. Exact commands and trust assumptions

### C leg — real Core objects, no stubs

Core's CMake is configured but **not built**; it is used only to generate
`bitcoin-build-config.h` and `compile_commands.json`:

```
cmake -S <core> -B <core>/build-ir -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DBUILD_TESTS=OFF -DBUILD_BENCH=OFF -DBUILD_FUZZ_BINARY=OFF \
  -DENABLE_WALLET=OFF -DBUILD_DAEMON=OFF -DBUILD_CLI=OFF \
  -DBUILD_BITCOIN_BIN=OFF -DBUILD_TX=OFF -DBUILD_UTIL=OFF -DENABLE_IPC=OFF \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DCMAKE_C_COMPILER=/usr/bin/clang-20 -DCMAKE_CXX_COMPILER=/usr/bin/clang++-20
```

Flags for `interpreter.cpp` are taken verbatim from that
`compile_commands.json` (Core's own flags), with only `-O`/`-g`/`-o`/`-c`
replaced. The resulting base flags are stored in
`artifacts/core-base-flags.txt` and in the manifest:

```
-I<build>/src -I<core>/src -I<core>/src/secp256k1/include
-std=c++20 -fPIC -fmacro-prefix-map=<core>/src=.
-Wstack-protector -fstack-protector-all -fcf-protection=full
-fstack-clash-protection -Wall -Wextra ... (remaining Core warning flags)
```

Translation units (15):

```
script/interpreter.cpp  script/script.cpp  script/script_error.cpp
hash.cpp  uint256.cpp  arith_uint256.cpp  pubkey.cpp
crypto/{sha1,sha256,sha256_sse4,sha512,ripemd160,siphash,hex_base}.cpp
util/strencodings.cpp
```

Each TU is compiled from inside the Core tree with relative paths:

```
clang++-20 <base_flags> -O{0|1} -g0 -emit-llvm -c <tu> -o tu/<tu>-O{0|1}.bc
llvm-link tu/*-O{0|1}.bc -o core-interpreter-O{0|1}.bc
llvm-dis  core-interpreter-O{0|1}.bc -o core-interpreter-O{0|1}.ll
```

No `bitcoind`/node build, no test binary, and no test-only
`FileCommit`/`TruncateFile` stubs are linked. Thirteen Core-internal calls are
closed by the TU list; the only remaining externals are libc/libstdc++ and
the **real** libsecp256k1 C API (`secp256k1_ecdsa_verify`, `…schnorrsig_verify`,
`…xonly_pubkey_parse`, etc., 17 symbols). Those calls are not stubbed: they
are declarations to be satisfied by the real library at link time.

The artifact is the script/interpreter layer. The reviewed
`equiv_entry` shim from `shims/` is **not** part of it; a cell that needs the
ABI links the reviewed shim against this module. This keeps shim trust
separate from compiler provenance.

*Trust assumptions:* Core source at the pin, unmodified; Core's own build
configuration for defines/includes; clang 20.1.2; no source is hand-edited
after emission. Hashes of all 15 TU sources are in the manifest, and the
source commit pins every header.

### L leg — generated, never hand-edited

```sh
python3 twin/gen.py --check twin/build/twin.cpp          # drift gate (repo)
python3 twin/gen.py --out <scratch>/twin.cpp --dump-ir <scratch>/twin.ir.json
python3 twin/gen.py --check <scratch>/twin.cpp           # drift gate (generated)
clang++-20 -std=c++17 -O{0|1} -fno-strict-aliasing -g0 \
  -I spec/equiv/contract -emit-llvm -c twin.cpp -o twin-O{0|1}.bc
llvm-dis twin-O{0|1}.bc -o twin-O{0|1}.ll
```

The generated file is compiled from its own directory with a relative name
(`source_filename = "twin.cpp"`), so the artifact hash does not depend on the
scratch path.

`twin/` is owned by another role and was edited several times while this
pipeline ran (`runtime.inc` and `gen.py` mtimes moved; the checked-in
`build/twin.cpp` was regenerated). The manifest therefore pins the L artifact
by **generator-input hashes**, not by a repository commit:

* `gen.py` `b3f2aeb9048e0ed1…`
* `ops_ir.py` `6f0d5531c7f7df91…`
* `runtime.inc` `465388db548f053b…`
* generated/checked-in `twin.cpp` `39ab7c66ea112ea0…`
* `contract/error_kind.h` `7a5f778f4aed8947…`

Exact copies of `gen.py`, `ops_ir.py`, `runtime.inc`, `twin.cpp`, and
`twin.ir.json` from that build are in `artifacts/twin-src/`. The generator changed twice during
the run; the final rebuild was made after `twin/` stabilised and both drift
gates passed. Later twin edits do not change the artifact; rebuild only once
`twin/` is quiescent again (the drift gate fails loudly otherwise).

*Trust assumptions:* the generator emits the reviewed IR table verbatim; the
Lean→IR transcription is hand-written and line-anchored
(`twin/generator.md` §1, §15). The twin is the **base-script stack subset**
only; anything outside the subset returns 3, not a verdict. It is not a full
`VerifyScript`.

### R leg — clean clone, no FFI patch

```sh
cd <rbtc>   # HEAD = pin, git status empty
CARGO_TARGET_DIR=<target> RUSTUP_TOOLCHAIN=1.95.0 CARGO_NET_OFFLINE=true \
cargo rustc --offline -p rbitcoin-consensus --lib --profile dev -- \
  -C codegen-units=1 -C debuginfo=0 --emit=llvm-ir,llvm-bc
```

* `equiv-ffi` is **not** enabled; `ffi.rs` is absent; no `equiv_entry` exists
  in the crate source (the script asserts both).
* Dependencies come from the local cargo cache; `--offline` prevents silent
  network substitution. `Cargo.lock` is pinned by hash.
* `codegen-units=1` gives one module for the whole crate; `debuginfo=0` keeps
  the IR free of build paths.
* `llvm-nm-20` cannot read the raw LLVM-22 bitcode. Symbols are located from
  the textual IR and, for the derivative, with `llvm-nm` on the LLVM-20
  bitcode. The single-input verifier is
  `_ZN18rbitcoin_consensus6script12verify_input17hbf7966be323ade2eE`
  (`script/mod.rs::verify_input`), extracted with `llvm-extract`.

**Normalisation (derivative, not the pin artifact).** LLVM 20 readers reject
the raw module with `Unknown attribute kind (105)`: LLVM 22 emits
`nocreateundeforpoison` (17 occurrences). The derivative removes exactly that
token and reassembles with `llvm-as-20`:

```sh
sed 's/ nocreateundeforpoison//g' rust-consensus-O0.ll > normalised.ll
llvm-as  normalised.ll -o rust-consensus-O0-v20.bc
llvm-dis rust-consensus-O0-v20.bc -o rust-consensus-O0-v20.ll
```

`llvm-diff-20 normalised.ll rust-consensus-O0-v20.ll` reports no structural
difference. The transform is textual and semantics-preserving as far as
LLVM 20 can express; it is still a conversion, so cells that use the
derivative must cite it as such. The **pin artifact remains the raw
`rust-consensus-O0.bc`**.

*Trust assumptions:* clean pin, unmodified crate, rustc 1.95.0/LLVM 22.1.2,
offline dependency resolution. Panics/allocations and the thread pool are
inside the crate; this pipeline does not abstract them.

---

## 5. Tool-ingestion results (summary)

Raw logs: `artifacts/smoke/`, machine-readable summary:
`artifacts/smoke/smoke.json` (also embedded in `manifest.json`).

| artifact | `alive-tv` | SAW `llvm_load_module` |
|---|---|---|
| C `-O0` | targeted `CastToBool` **passes**; whole module times out (invokes + size) | **loads** |
| C `-O1` | targeted `CastToBool` fails to translate (`nocapture`); whole module: 9 correct, 2 incorrect, 1 unproven, 256 Alive2 errors | **loads** |
| L `-O0` | whole module times out; targeted `cast_to_bool` reports **1 incorrect** (see report) | **loads** |
| L `-O1` | 4 correct, 1 unproven, 45 Alive2 errors (whole module) | **loads** |
| R raw | **cannot read** LLVM-22 bitcode (`Unknown attribute kind (105)`) | **cannot load** (`atomicrmw` opaque pointer) |
| R v20 | parses; whole module times out / hits `invoke`; `verify_input` translates poorly (`sret([24 x i8])` unsupported) | whole crate **fails**; `verify_input` and `is_op_success` **load** |
| R leaf | `is_op_success` **passes** self-refinement | **loads** |

A load failure or translation error is a capability result, never a proof.
The `alive-tv` "incorrect" results (two Core `-O1` `VerifySchnorrSignature`
transformations and the twin `cast_to_bool`) need triage; they are reported
verbatim and not adjudicated here.

---

## 6. Non-claims

* No claim that C, L, and R are equivalent, or that any artifact refines
  another.
* No claim that the C artifact is all of Bitcoin Core: it is the script
  interpreter TU closure, with libsecp256k1 external.
* No claim that the L skeleton covers the full engine.
* No claim that the R derivative is the pin artifact; it is a documented
  LLVM-20 conversion.
* A hash identifies bytes, not meaning. The manifest's trust section is part
  of the evidence.
