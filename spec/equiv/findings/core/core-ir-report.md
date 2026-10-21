# CORE-IR report — Bitcoin Core script engine to LLVM IR

**Role:** CORE-IR
**Pin:** Bitcoin Core v32.99 `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Date:** 2026-10-19
**Proof toolchain:** clang/LLVM **20.1.2** (the pin in `PINS.lock`)
**Status:** IR extraction and tool-ingest experiments complete; patches are
**PROPOSED**, not accepted. No differential behavior run has been executed.

This report supersedes the earlier clang 18.1.3 artifacts. The clang-18
hashes are listed in `NONPROOF-clang18.txt` and **must not be cited by any
cell**. Nothing here is a Lean-kernel theorem; results are evidence-tier.

---

## 1. Clone and pin verification

```sh
mkdir -p /tmp/opencode/equiv-work/bitcoin
cd /tmp/opencode/equiv-work/bitcoin
git init
git remote add origin https://github.com/bitcoin/bitcoin.git
git fetch --depth 1 origin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
git checkout FETCH_HEAD
git rev-parse HEAD
# cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
git status --porcelain   # empty
```

The primary IR lane is a **single-TU compile of `src/script/interpreter.cpp`**
plus the headers it includes, not a complete CMake build. CMake was used only
to produce `build-ir/src/bitcoin-build-config.h`; the final reproduction in a
fresh clone without that file produced the same bitcode hash, so the generated
header is not on the critical path for this TU.

## 2. Exact compile commands

Unpatched:

```sh
/usr/bin/clang++-20 -std=c++20 -O0 -g0 -emit-llvm -c \
  -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include \
  src/script/interpreter.cpp -o interpreter-O0.bc

/usr/bin/clang++-20 -std=c++20 -O1 -g0 -emit-llvm -c \
  -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include \
  src/script/interpreter.cpp -o interpreter-O1.bc

/usr/bin/clang++-20 -std=c++20 -O0 -g0 -ftrapv -emit-llvm -c \
  -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include \
  src/script/interpreter.cpp -o interpreter-O0-ftrapv.bc
```

Patched lane:

```sh
M='-DBTC_EQUIV_NO_SCRIPTNUM_THROW -DBTC_EQUIV_HOIST_STATICS -DBTC_EQUIV_DEVIRT'
/usr/bin/clang++-20 -std=c++20 -O0 -g0 $M -emit-llvm -c \
  -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include \
  src/script/interpreter.cpp -o interpreter-O0-patched.bc
```

`-DDEBUG`, `-DDEBUG_LOCKORDER`, `-DDEBUG_LOCKCONTENTION`,
`-DABORT_ON_FAILED_ASSUME` do not change the O0 hash. `-fno-exceptions` is
**not viable**: the clang-20 run emitted **20 errors** before the default
error limit stopped it, all `cannot use 'throw' with exceptions disabled`,
across `util/check.h`, `serialize.h`, `util/string.h`,
`util/strencodings.h`, and `uint256.h` (log: `logs/fno-exceptions.log`).
The count is a lower bound because compilation aborted at the limit. Exception
removal is therefore a derived IR transform (§5), not a source flag.

## 3. Artifact hashes (proof lane)

Bitcode files are regenerable and remain under
`/tmp/opencode/equiv-work/` (`.gitignore` excludes `*.bc`). Exact commands
are in `commands.md`.

| Artifact | sha256 |
|---|---|
| `interpreter-O0.bc` (unpatched, clang 20.1.2) | `f5718af79c56ccfd5a5437a313d957573cb87c0de0cdf5641013991268801b2c` |
| `interpreter-O1.bc` (unpatched) | `01003ec095441bad8ada96ed1effa860f84bda23802841c7d7eb15b2e554537f` |
| `interpreter-O0-ftrapv.bc` (unpatched) | `714ad532b43be61c0f4fdc8f0ef9e45d36cae0b538e9f67cd8665511a6b5c576` |
| `interpreter-O0-hoistonly.bc` (P-CORE-03 only) | `984177bd7a04ca402e0e3b6dbb60626b2be8c22abf2e5e3d2176678558b71819` |
| `interpreter-O0-patched.bc` (01+02+03) | `5993460463314028bf1225784bbbcaa28dab7ab6fec979a17907a369cba302c7` |
| `interpreter-O1-patched.bc` (01+02+03) | `deebc447a4c2665efb6f83065420a099abdbaea1577d1c14b7822bfe003bfe6f` |
| `interpreter-O0-patched-noexc-s.bc` (erased + simplifycfg) | `3bfeecfb06cbecf41aa9edbf6cfe3c2c448f8e8df58d877e7936e4f965a33003` |
| `roots.bc` (erased + `internalize,globaldce`) | `2b9f683c4fdd3550e4eab43083a4c528ce785d37956f0f24b75311ec756f04a8` |

The patched hash was reproduced from a **fresh clone** of the pin:
`P-CORE-01`, `P-CORE-02`, `P-CORE-03` applied in order, all three modified
files byte-identical to the prototype tree, recompiled with the three macros:
`verify-tree-O0-patched.bc = 5993460…302c7`, identical to the prototype.
Each patch also passes `git apply --check` against the unmodified pin alone.

## 4. IR feature inventory

Full table: `ir-features.tsv`. Module-level counts:

| Variant | defines | invoke | landingpad | resume | ptrtoint | inttoptr | indirect sites | cxa_guard |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| unpatched O0 | 1026 | 686 | 213 | 58 | 104 | 0 | 12 | 15 |
| unpatched O1 | 124 | 345 | 228 | 36 | 559 | 4 | 22 | 13 |
| unpatched O0 `-ftrapv` | 1026 | 686 | 213 | 58 | 104 | 0 | 12 | 15 |
| P-CORE-03 only | 1029 | 684 | 211 | 59 | 104 | 0 | 12 | 6 |
| patched O0 | 1016 | 683 | 202 | 57 | 104 | 0 | **6** | 6 |
| patched O1 | 120 | 296 | 205 | 34 | 567 | 4 | 16 | 6 |
| patched O0 erased | 1016 | **0** | **0** | **0** | 104 | 0 | 6 | 6 |
| erased + internalized | 616 | 0 | 0 | 0 | 78 | 0 | 0 | 0 |

### Engine functions at O0 (unpatched → patched)

| Function | body lines | invoke | landingpad | indirect | ptrtoint |
|---|---:|---:|---:|---:|---:|
| `EvalScript` (7-arg) | 4637 → 4570 | 336 → 339 | 32 → 25 | 3 → **0** | 0 |
| `VerifyScript` | 877 | 58 | 6 | 0 | 0 |
| `VerifyWitnessProgram` | 605 → 602 | 35 | 1 | 1 → **0** | 0 |
| `EvalChecksigPreTapscript` | 255 → 252 | 9 | 2 | 1 → **0** | 0 |
| `EvalChecksigTapscript` | 180 → 177 | 0 | 0 | 1 → **0** | 0 |
| `ExecuteWitnessScript` | 290 | 8 | 2 | 0 | 0 |
| `CastToBool` | 69 | 0 | 0 | 0 | 0 |
| `CScriptNum` vector ctor | 193 | 6 | 4 | 0 | 0 |

The 6 indirect call sites in the unpatched engine IR are:

| IR line | Enclosing function | Source call |
|---:|---|---|
| 4606 | `EvalScript` | `CheckLockTime` (`interpreter.cpp:565`) |
| 4730 | `EvalScript` | `CheckSequence` (`interpreter.cpp:599`) |
| 7863 | `EvalScript` | `CheckECDSASignature` (`interpreter.cpp:1177`) |
| 16791 | `VerifyWitnessProgram` | `CheckSchnorrSignature` (`interpreter.cpp:1972`) |
| 24074 | `EvalChecksigPreTapscript` | `CheckECDSASignature` (`interpreter.cpp:349`) |
| 24278 | `EvalChecksigTapscript` | `CheckSchnorrSignature` (`interpreter.cpp:380`) |

After P-CORE-02 all six are direct hook calls. The remaining 6 module-level
indirect sites are in the concrete `GenericTransactionSignatureChecker`
templates and `tinyformat`; they are outside the engine functions.

### `ptrtoint`, loops, heap, externals

- **`ptrtoint`:** 104 module-wide at O0, **0 in every engine function body**.
  Statically reachable from `EvalScript`: 52 sites in 26 `std::vector` /
  iterator / `tinyformat` helpers (unpatched), 48 in 24 after erasure. O1
  raises the module count to 559 and puts 223 in `EvalScript`; O1 is a
  robustness lane, not the primary proof lane.
- **Loop:** `EvalScript` has one unbounded dispatch loop
  (`interpreter.cpp:449-1234`), with the opcode switch at `:494-1229`. Alive2
  can translate the function after erasure but cannot prove it without
  unrolling; SAW needs a loop invariant over the stack machine.
- **Heap:** the reachable call graph contains `malloc`, `free`, `realloc`,
  `operator new`/`delete`, and the `std::vector` reallocation helpers.
- **Undefined externals (32, erased patched O0):** `GetScriptOp`,
  `CheckMinimalPush`, `CPubKey::CheckLowS`, RIPEMD160/SHA1/SHA256
  constructors/Write/Finalize, `memcmp`, `malloc/free/realloc`, four
  `btc_equiv_check_*` hooks, `__assert_fail`, `__cxa_begin_catch`,
  `__cxa_end_catch`, `__cxa_rethrow`, and `std::__throw_*` / `std::terminate`.
  Several `__cxa_*` entries are only in unreachable handler blocks left by
  the erasure transform; the static call graph over-approximates.

## 5. Derived exception-erasure transform (not a source patch)

`../scripts/erase_exceptions.py` rewrites textual IR:

- `invoke X to label %ok unwind label %unwind` → `call X; br label %ok`
- every landing-pad block → `unreachable`
- `resume` → `unreachable`
- function `personality` attributes dropped

Result: 683 invokes and 202 landing pads become 0. A following
`opt -passes=simplifycfg` removes the now-dead edges. This is
**domain-restricting**: unwind paths become `unreachable`; the shim still
maps result 3 at the boundary, but Core's old `catch (...)` →
`SCRIPT_ERR_UNKNOWN_ERROR` behavior differs on out-of-domain paths. This is
a residual requiring differential evidence, not a proof of exception
equivalence.

`internalize,globaldce` with a five-symbol public API
(`CastToBool`, `operator|(script_verify_flags)`, 7-arg `EvalScript`,
`CScriptNum::getint`, `VerifyScript`) reduces the module from 1016 to 616
defines and removes the undefined C++ ABI vtable globals
(`_ZTVN10__cxxabiv117__class_type_infoE` etc.) that SAW rejects with
`Global was not a compile-time constant`. `roots.bc` has 0 ABI globals.

## 6. Tool ingest verdict

### Alive2 v20.0

| Input | Command shape | Result |
|---|---|---|
| unpatched O0, `EvalScript` | `--func=… --passes=verify --skip-smt` | **fails to translate**: `load atomic i8, ptr @_ZGVZ10EvalScript…` (`__cxa_guard` guard variable) |
| P-CORE-03 only, `EvalScript` | same | **fails to translate**: `invoke … @_ZN12_GLOBAL__N_19set_error…` |
| patched (01+02+03), `EvalScript` | same | **fails to translate**: same `invoke set_error` |
| patched + erased, `EvalScript` | same | **translates**; summary 1 correct / 0 errors (self-comparison, `--skip-smt`, so *not* a semantic proof) |
| patched + erased, `VerifyScript` | same | **translates** |
| patched + erased, `VerifyWitnessProgram` | same | **translates** |
| leaf `CastToBool` | `--func=… --always-verify --smt-to=60000` | **proved correct** (1 correct, 0 errors) |

The leaf proof log is `logs/alive2-leaf-casttobool.log`. The unpatched and
patched translation failures are preserved verbatim in
`logs/alive2-{unpatched,patched,hoistonly}-evalscript.log`.

### SAW 1.6

- Loads `roots.bc` (LLVM-20 bitcode) successfully (`logs/saw20-load.log`).
- Proves `_Zor19script_verify_flagsS_` correct:
  `logs/saw20-leaf-ok.log`.
- Rejects a deliberately wrong spec with a counterexample:
  `x = 9222246136947933183`, `y = 1125899906842624` (`logs/saw20-leaf-bad.log`).
- SAW **has not** been asked to prove `EvalScript`/`VerifyScript`. The
  unbounded loop, heap traffic, and 32 undefined externals are the blockers;
  an override/invariant development is required first.

Feeding LLVM-20 text to SAW/Alive2 is required, or `.bc` directly:
`llvm-dis-18` emits `inrange` syntax that LLVM 20's text parser rejects.

## 7. Patches

Registry and full arguments: `../../patches/core/README.md`.

| ID | Status | Effect measured |
|---|---|---|
| P-CORE-01 | PROPOSED, prototyped | Removes all 12 throwing `CScriptNum(vector)` sites and the `scriptnum_error`/catch-all edges; sets `SCRIPT_ERR_SCRIPTNUM` at each original site |
| P-CORE-02 | PROPOSED, prototyped | Engine indirect calls 6 → 0; four `extern "C"` checker hooks |
| P-CORE-03 | PROPOSED, prototyped | `__cxa_guard` module count 15 → 6; `EvalScript` guard path removed |
| P-CORE-04 | design only | Split `EvalScript` loop into `EvalStep` for bounded slicing |
| P-CORE-05 | design only | `std::span` leaf overloads to remove O1 `ptrtoint` from `CastToBool`/`CheckMinimalPush` |

None is behavior-preserving evidence-complete. P-CORE-01/03 have explicit
out-of-domain differences (empty-stack `popstack` abort; static-init
allocation failure); P-CORE-02 assumes the single-checker harness premise.
The differential plans are in the registry, including corpus hashes, fuzz
lane, and negative controls.

## 8. Residual blockers (ranked)

Findings IDs and dispositions are in `findings-ledger.md`.

1. **Exceptions / unwinding.** Source `-fno-exceptions` is impossible (20
   errors before the error limit). The erasure transform is domain-restricting
   and must be either justified by a no-throw proof for the corpus domain or
   replaced by a checker-visible error-return refactor.
2. **Whole-function loop.** `EvalScript`'s dispatch loop has no bound in the
   IR. P-CORE-04 is the proposed slicing design; until then only leaves and
   translation/ingest are available.
3. **Heap and STL memory model.** `std::vector` operations, `malloc/free`,
   and `ptrtoint` in iterator helpers require SAW overrides or a memory
   abstraction. `ptrtoint` is absent from engine bodies but present in 24–26
   reachable helpers.
4. **Undefined externals.** `GetScriptOp`, `CheckMinimalPush`, crypto,
   `memcmp`, allocator, and the C++ ABI helpers need overrides or real
   bitcode.
5. **Checker seam.** P-CORE-02's hooks must be implemented in
   `shims/core/entry.cpp` by CONTRACT; see
   `handoff-contract-pcore02.md`. This is a hard dependency for any cell that
   uses the devirtualized engine.
6. **No differential evidence.** Patch status stays PROPOSED until the
   corpus + fuzz runs in the registry are executed with zero divergences.
7. **Whole-function SMT cost.** Alive2 has only translated the erased
   `EvalScript`; no SMT proof was attempted. SAW has not been given an
   `EvalScript` spec.

## 9. Pins and next actions

Proposed `PINS.lock` values are in `pins-proposal.md` (CORE-IR cannot edit
`PINS.lock`). The existing `[llvm]` clang 20.1.2 entry is correct and was
used; the earlier clang-18 artifacts were a pin violation and are retired.

Next actions, in order:

1. CONTRACT implements the P-CORE-02 hook seam in `shims/core/entry.cpp`
   (lines 137-149) and returns a linked `equiv_entry`.
2. CORE-IR executes the differential plans for P-CORE-01/02/03 on the 1,258
   script vectors + 500 sighash vectors + fuzz lane; files results in
   `patches/core/README.md`.
3. TOOLS/CELLS decide whether the erasure transform is accepted as a
   domain restriction or replaced by P-CORE-01 + a no-throw proof.
4. Prototype P-CORE-04 `EvalStep` and P-CORE-05 span leaves; re-run Alive2
   leaf proofs and SAW load.
5. Re-pin the patched IR hashes only after the differential evidence lands.

## 10. Honest limitations

- The patched hash proves **reproducibility of the patched tree**, not
  semantic equivalence to the unpatched engine.
- Alive2's erased `EvalScript` result is translation/self-comparison only.
- SAW's green result is one leaf (`operator|`), not the interpreter.
- The single-TU compile does not include link-time objects; undefined
  externals remain undefined by design.
- Clang 20.1.2 at `-O1` is materially worse for `ptrtoint` than O0; no O1
  proof claim is made.
