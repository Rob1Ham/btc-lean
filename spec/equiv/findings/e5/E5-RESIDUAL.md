# E5 residual — whole-function `VerifyScript` / `EvalScript`

**Role:** E5-WHOLE-FUNCTION
**Date:** 2026-10-19
**Core pin:** Bitcoin Core v32.99 `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**IR lane:** single-TU `src/script/interpreter.cpp`, clang/LLVM **20.1.2**, `-O0 -g0`
**Tools:** SAW **1.6** (`68eed5f`, release-1.6); Alive2 **v20.0** (`c0f5434`, LLVM 20.1.2)
**Verdict:** **NO whole-function proof was obtained.** A real but scoped SAW
result exists for one fully concrete empty-script input. Every symbolic or
non-empty path is blocked by named IR features below. This file is the E5
"scoped residual" deliverable; nothing here is a Lean-kernel theorem or an
equivalence claim.

> **Provenance caveat (orchestrator, post-run):** the raw E5 attempts used
> `/tmp/opencode/equiv-work/ir/interpreter-O0.ll` (sha256 `b8f17c1f...`), which
> is **not** the PINS `[core.ir]` single-TU carrier (`f5718af7...`) and not
> the `[ir]` 15-TU closure (`204cf671...`). The one green empty-script line
> is therefore a **concolic, non-pin** execution, not a pinned C result, and it
> is not used by any green ledger row. The structural blockers (GetScriptOp,
> heap, dispatch loop, exceptions) are independent of that scope. Do not cite
> the green line as a pinned equivalence artifact.

> **Prototype update (2026-10-20, no green row).** B1 and B2 now have bounded,
> machine-checked probes, but they do **not** form a ledger cell:
> `findings/wave16b/02-e5-getscriptop/` links the real `script.cpp` and proves
> concrete/symbolic `GetScriptOp` lemmas plus concrete non-empty
> `VerifyScript` inputs; `findings/wave16b/03-e5-heap/` supplies a bounded
> allocator model and proves OP_1 at capacity 41 (and failure at 40). The
> remaining E5 blockers are still B3 (symbolic dispatch-loop invariant), the
> allocator refinement/capacity proof, B4/B5/B7, and the non-pin probe
> provenance. `findings/wave16b/11-patch-evalstep/` evaluates P-CORE-04/05 and
> finds the loop still symbolic-trip. None of this is promoted.

---

## 1. What was run, and what happened

All SAW runs use `llvm_verify ... [] false <spec> z3`. **No
`llvm_unsafe_assume_spec` is present in any E5 spec.** `abc` is not installed
in this environment, so the bundle's `z3` 4.8.14 was used.

| # | Spec / module | Exact outcome |
|---|---|---|
| 1 | load `ir/interpreter-O0.bc` | loads (`E5_RAW_LOAD_OK`) |
| 2 | load `ir/interpreter-O1.bc` | loads (`E5_O1_LOAD_OK`) |
| 3 | load `ir20-proto/roots.bc` | loads (`E5_ROOTS_LOAD_OK`) |
| 4 | `llvm_verify` `VerifyScript`, raw O0, concrete empty scripts | **stops at setup**: `Global was not a compile-time constant: Symbol "_ZTVN10__cxxabiv120__si_class_type_infoE"` |
| 5 | same spec on `roots.bc` (patched+erased) | **`Proof succeeded!`** — return `false` |
| 6 | same spec on linked3 probe (unpatched interpreter + `script.cpp`) | **`Proof succeeded!`** — return `false` |
| 7 | `llvm_verify` `VerifyScript`, `scriptPubKey = 51` (OP_1), `roots.bc` | **stops in execution**: `Failed to load function handle: _Z11GetScriptOp... No implementation or override found for pointer` |
| 8 | OP_1, linked `script.cpp`, no ABI stub | **stops at setup**: undefined ABI vtable global |
| 9 | OP_1, linked + ABI stub | **stops in execution**: `Global symbol "_ZGVZ10EvalScript...E6bnZero" has no associated allocation` |
| 10 | OP_1, linked + ABI stub + guards pinned to 1 | **stops in execution**: `Failed to load function handle: _Znwm` (heap) |
| 11 | Alive2 `VerifyScript`, raw O0, `--passes=verify --skip-smt` | **fails to translate**: `ERROR: Unsupported instruction: %109 = invoke ... @_Z10EvalScript...` |
| 12 | Alive2 `VerifyScript`, `roots.bc`, `--passes=verify --skip-smt` | `Transformation seems to be correct! (syntactically equal)`; **not a proof** |
| 13 | Alive2 `VerifyScript`, `roots.bc`, SMT enabled (`--smt-to=5000`) | same `syntactically equal`; the pass generated no SMT obligation |

### 1.1 The one genuine scoped result

Spec `cells/e5-whole/saw/e5-verifyscript-empty-roots.saw` (and the linked3
variant) encodes a fully concrete empty-script call:

- `scriptSig`, `scriptPubKey`: 40-byte `CScript` (`prevector<36, unsigned
  char, unsigned int>`; 36-byte inline storage, 4-byte size at offset 36),
  size = 0, all bytes zero.
- witness pointer = null (Core substitutes the static `emptyWitness`), flags =
  `0`, checker = readable 8-byte object, error cell = readable 8-byte object.
- postcondition: `i1 0` (`false`).

SAW simulated `VerifyScript` through both `EvalScript` calls, through the
empty-stack check and `set_error`, and proved the return obligation. This
proves a **singleton input case**, not a function contract. It is useful
because it shows the SAW/Crucible LLVM-20 pipeline can execute the real
`VerifyScript`/`EvalScript` bodies up to the first heap or script-parsing
event, and it localises the first blockers.

`roots.bc` is the CORE-IR **patched** lane (P-CORE-01/02/03, all still
PROPOSED). The linked3 probe starts from the **unpatched**
`ir/interpreter-O0.bc`, links `script.cpp`, erases exceptions, stubs three ABI
globals and pins the three `__cxa_guard` bytes to "already initialized"; see
`cells/e5-whole/build/build-module.sh`. Both runs are labelled concolic.

---

## 2. Blocking IR features (with citations)

Line numbers are in `/tmp/opencode/equiv-work/ir/interpreter-O0.ll`
(SHA-256 `b8f17c1f...`). The pinned equivalent module is
`ir20/interpreter-O0.bc` (`f5718af7...`, per `findings/core/hashes.txt`); the
`ir/` copy differs only in C++ ABI type-layout metadata (e.g.
`_Rb_tree_impl`), and `ir20-proto/roots.bc` is derived from the pinned lane.

### B1. Undefined external `GetScriptOp` — first hard stop for any non-empty script

- Declaration: `interpreter-O0.ll:20190` —
  `declare ... @_Z11GetScriptOpRN9prevectorILj36EhjiE14const_iteratorES1_R10opcodetypePSt6vectorIhSaIhEE`.
  There is no definition in the single-TU module (`script.cpp` was not
  compiled into it).
- Reached from `EvalScript`'s dispatch loop via
  `CScript::GetOp` (`interpreter-O0.ll:4126` invoke of
  `_ZNK7CScript5GetOp...`; helper body at `:8480`, its `GetScriptOp` call at
  `:8499`).
- SAW output (`logs/e5-verifyscript-op1.raw.log`):
  `Failed to load function handle: _Z11GetScriptOp... No implementation or override found for pointer`.
- Closing it: link the real `script.cpp` bitcode (done in the probe; then B2
  becomes the stop) **or** provide a verified SAW override. An
  `llvm_unsafe_assume_spec` override would not be a proof and was not used.

### B2. Heap / allocator externals — next stop after linking `script.cpp`

- `_Znwm` declaration: `interpreter-O0.ll:19624`; also
  `free` `:20247`, `realloc` `:25046`, `malloc` `:25049`.
- SAW output (`logs/e5-verifyscript-op1-linked3.raw.log`):
  `internal: error: in _ZNSt15__new_allocatorIhE8allocateEmPKv` /
  `Failed to load function handle: _Znwm` /
  `No implementation or override found for pointer`.
- The allocation is reached by the first `std::vector` push in `EvalScript`
  (the stack value type is `std::vector<std::vector<unsigned char>>`; the
  stack begins empty).
- Closing it: verified specs / overrides for `operator new`, `malloc`,
  `free`, `realloc`, including allocation-failure behavior, or a
  `std::vector`/stack abstraction with a proved refinement. A "never fails"
  allocator would hide a real Core error path and is not acceptable without a
  domain argument.

### B3. Unbounded `EvalScript` dispatch loop

- Source: `interpreter.cpp:449-1234` (one loop over the script, opcode
  `switch` at `:494-1229`).
- IR: loop header label `%336` at `interpreter-O0.ll:4101`; backedge at
  `:8200` (`br label %336, !llvm.loop !14`). The loop has no IR trip count.
- `EvalScript` body: `interpreter-O0.ll:3651-8288` (4,638 lines), 336
  `invoke`s, 32 `landingpad`s, 0 `ptrtoint`.
- SAW has no supplied invariant. Even after B1/B2 are solved, a symbolic
  script length/contents will make SAW attempt unbounded unrolling and fail
  or diverge. A timeout is not a proof.
- Closing it: a loop invariant over `(pc, stack, altstack, condition stack,
  error, script-size limit)` at the `%336` header, or the P-CORE-04
  `EvalStep` slicing design plus bounded unrolling for a stated script-length
  bound.

### B4. C++ exception edges / ABI globals

- `VerifyScript`: `interpreter-O0.ll:15318-16195` (878 lines), 58 `invoke`s,
  6 `landingpad`s.
- `EvalScript`: 336 `invoke`s, 32 `landingpad`s (range above).
- Raw-module SAW setup fails on the undefined ABI global
  `@_ZTVN10__cxxabiv120__si_class_type_infoE`
  (`interpreter-O0.ll:2147`); Alive2 refuses the `invoke` instruction
  (log 11).
- `roots.bc` is the CORE-IR **erasure transform**: each `invoke` becomes a
  `call`, each landing-pad block becomes `unreachable`, personality attributes
  are dropped. That is **domain-restricting**: Core's uncaught-exception →
  `SCRIPT_ERR_UNKNOWN_ERROR` behavior is not modeled on erased paths.
- Closing it: either a no-throw proof for the analysed domain, or SAW
  overrides for `__cxa_throw`, `__cxa_begin_catch`, `__cxa_end_catch`,
  `__cxa_rethrow`, `__cxa_allocate_exception`, `__cxa_free_exception` that
  preserve the uncaught-exception result. Alive2 would still need the erased
  form (it has no exception support), so the policy has to be uniform.

### B5. `__cxa_guard` static initialization

- 20 `_ZGV*` guard uses in the raw module; `EvalScript` acquires three
  (`bnZero`, `bnOne`, `vchTrue`) at `interpreter-O0.ll:3887`, `:3906`,
  `:3925`.
- Linked probe without P-CORE-03: SAW aborts with
  `Global symbol "_ZGVZ10EvalScript...E6bnZero" has no associated allocation`
  (`logs/e5-verifyscript-op1-linked2.raw.log`).
- The linked3 probe sets the guard bytes to `internal constant i64 1`, i.e.
  **assumes the one-time static initialization has completed**.
- Closing it: accept P-CORE-03 (guard hoisting, still PROPOSED and without
  differential evidence) or specify `__cxa_guard_acquire/release` and the
  initialization state in SAW.

### B6. `ptrtoint` and STL memory model

- 104 `ptrtoint` module-wide at O0; **0 inside the engine bodies**, but 52
  statically reachable from `EvalScript` in 26 `std::vector` / iterator /
  `tinyformat` helpers (CORE-IR report §4).
- These helpers also model allocator pointer arithmetic and iterator
  provenance. The concrete empty path avoids them; any loop/stack growth
  reaches them.
- Closing it: prove/override the vector/iterator helpers (or use span-based
  leaves, cf. P-CORE-05), keeping the `ptrtoint`/`inttoptr` provenance model
  sound.

### B7. Crypto / hash / assertion externals

Reachable undefined externals include the four `btc_equiv_check_*` hooks,
SHA-1/SHA-256/RIPEMD-160 methods, `memcmp`, `CheckMinimalPush`,
`GetScriptOp`, `__assert_fail`, and the allocator. The engine claim therefore
remains **conditional on same-crypto** (`docs/DECISION-lax-ecdsa.md`); the
checker seam is only usable once CONTRACT implements the P-CORE-02 hooks in
`shims/core/entry.cpp`.

---

## 3. Alive2

Alive2 v20.0 was used only as a translation / self-pipeline check:

```sh
alive-tv ir/interpreter-O0.bc \
  --func='_Z12VerifyScriptRK7CScriptS1_PK14CScriptWitness19script_verify_flagsRK20BaseSignatureCheckerP13ScriptError_t' \
  --passes=verify --skip-smt
# ERROR: Unsupported instruction: %109 = invoke ...
# ERROR: Could not translate ... to Alive IR
# 1 Alive2 errors

alive-tv ir20-proto/roots.bc \
  --func='_Z12VerifyScriptRK7CScriptS1_PK14CScriptWitness19script_verify_flagsRK20BaseSignatureCheckerP13ScriptError_t' \
  --passes=verify --skip-smt
# Transformation seems to be correct! (syntactically equal)
# 1 correct, 0 incorrect, 0 failed-to-prove, 0 errors
```

The second result means the module's optimization pipeline produced
*syntactically identical* IR for this function; it is **not** a semantic
equivalence result and says nothing about `VerifyScript`'s behavior. Running
with SMT enabled (`--smt-to=5000`, no `--skip-smt`) produced the same
syntactically-equal outcome because no transformation was applied. No claim
is made beyond translation.

---

## 4. Reproduction

```sh
# tool versions
/opt/equiv-tools/saw-1.6/bin/saw --version       # 1.6 (68eed5f release-1.6)
/usr/local/bin/alive-tv --version                # v20.0 (c0f5434), LLVM 20.1.2

# scoped green result (concrete empty scripts)
/opt/equiv-tools/saw-1.6/bin/saw \
  /home/ubuntu/btc-lean-public/spec/equiv/cells/e5-whole/saw/e5-verifyscript-empty-roots.saw

# first hard blocker for one real opcode
/opt/equiv-tools/saw-1.6/bin/saw \
  /home/ubuntu/btc-lean-public/spec/equiv/cells/e5-whole/saw/e5-verifyscript-op1.saw

# linked-module chain (writes only under /tmp/opencode/equiv-work)
/home/ubuntu/btc-lean-public/spec/equiv/cells/e5-whole/build/build-module.sh
```

Raw logs are in `cells/e5-whole/logs/`; their SHA-256 values are in
`cells/e5-whole/SHA256SUMS`.

Module hashes used above:

| Artifact | SHA-256 |
|---|---|
| `ir/interpreter-O0.ll` | `b8f17c1f94569aa6e4ddc1f9776092ea83584f4aace192169cc32fba25a9ed4d` |
| `ir/interpreter-O0.bc` | `ff8b4028f3fa8afb05b609a3008fab3655176a085bc86f132ff4d475c76d4101` |
| `ir20/interpreter-O0.bc` (pinned lane) | `f5718af79c56ccfd5a5437a313d957573cb87c0de0cdf5641013991268801b2c` |
| `ir/interpreter-O1.ll` | `860e711f2b3d2f3217567b706119d58ad8f18ae3bf9a78d1a846aeb28afe9f88` |
| `ir/interpreter-O1.bc` | `114e84075243920fab85c4c1323cb345cc190edabb402edf5fda6dfbdff94c0c` |
| `ir20-proto/roots.bc` (patched + erased) | `2b9f683c4fdd3550e4eab43083a4c528ce785d37956f0f24b75311ec756f04a8` |
| `ir/script-O0.bc` (linked probe) | `657530a8d18741b40e09653a681c5d11438ed453bcccf8bde14f0b2037a6d51c` |
| `ir/e5-interp-script-roots3.bc` (probe) | `d287d14216fc1d1b5ed3461aad2ca96cf65bb00884b6abc85e9d90f9a74016a2` |

---

## 5. Honest scope

- **No whole-function `VerifyScript` proof exists.** The green SAW runs are
  concrete-input executions, not a contract over symbolic scripts/flags/
  witness/checker.
- The EvalScript loop is not proved, sliced, or bounded in this work.
- The erasure transform and guard pinning are assumptions, not Core
  properties. The `roots.bc` lane also carries the still-PROPOSED
  P-CORE-01/02/03 patches.
- `ptrtoint`, the heap, crypto, and the checker seam are untouched beyond
  naming them.
- B1+B2 have bounded prototype probes (above), but not a pinned refinement;
  the next concrete engineering step is the B3 symbolic-loop invariant on the
  pinned lane, followed by allocator refinement and the remaining externals. Until
  all three exist, an E5 green cell would be dishonest.
