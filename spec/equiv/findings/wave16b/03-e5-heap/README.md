# wave16b/03-e5-heap — B2 heap/allocator unblock for E5

**Role:** wave16b task `03-e5-heap` (structural unblocker for PR #29)
**Date:** 2026-10-20
**Base:** PR #29 head `805c804` (`equiv/llvm-three-leg`)
**Core pin:** Bitcoin Core v32.99 `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**IR lane:** LLVM 20.1.2, `-O0 -g0`
**Tools:** SAW 1.6 (`68eed5f`, release-1.6, bundled z3 4.8.14); clang++-20 20.1.2;
llvm-link/llvm-as 20.1.2
**Status:** **prototype / concolic result, not a pinned whole-function theorem**

---

## 0. Bottom line

**Yes: a non-empty `EvalScript` path now gets past the allocator.**

The existing OP_1 probe (`scriptPubKey = 0x51`) stopped at
`Failed to load function handle: _Znwm`
(`logs/01-baseline-b2-znwm-stop.raw.log`, reproduced from
`cells/e5-whole/saw/e5-verifyscript-op1-linked3.saw`). With a bounded,
explicit-failure bump-arena model linked under the same probe module, SAW now
proves the OP_1 call of `VerifyScript` returns `true`:

```
Proof succeeded! _Z12VerifyScriptRK7CScriptS1_PK14CScriptWitness19script_verify_flagsRK20BaseSignatureCheckerP13ScriptError_t
```

(`logs/02-op1-heapmodel-proof.log`, exit 0.)

At this base (`805c804`) this is the first *non-empty* script path in the E5
lane to pass a SAW proof obligation; the E5 residual recorded every non-empty
attempt as blocked at `GetScriptOp` and then `_Znwm`.
It is **concolic** (concrete script bytes and flags), on the **linked3 probe
module** (not the PINS carrier) and under a **prototype allocator**, so it is
not a green ledger row. What it does establish mechanically is that B2 is not a
fundamental SAW/Crucible limit: the vector-growth path is executable, the
allocation sizes are concrete, and the real `std::vector` code can be driven
through the model.

No `llvm_unsafe_assume_spec` is used anywhere in this directory. The
allocation-failure branch is present, executable, and demonstrably *not*
hidden (see §5).

---

## 1. What was run

All SAW runs are `llvm_verify m <fn> [] false <spec> z3` (empty override list,
no unsafe assume). Inputs and hashes are in §9.

| # | Run | Module | Outcome | Log |
|---|---|---|---|---|
| 1 | baseline OP_1, unmodified linked3 probe | `e5-interp-script-roots3.bc` | stops: `_Znwm` has no implementation/override (B2 reproduced) | `01-baseline-b2-znwm-stop.raw.log` |
| 2 | OP_1 `VerifyScript` through the allocator model | `e5-interp-script-roots3-heap.bc` | **`Proof succeeded!`**, returns `true` | `02-op1-heapmodel-proof.log` |
| 3 | allocator model lemmas + vector refinement | `vec-probe-linked.bc` | 6/6 `Proof succeeded!` | `03-alloc-vector-lemmas.log` |
| 4 | `_Znwm` when the arena is already full | `vec-probe-linked.bc` | stops at external `_ZSt17__throw_bad_allocv` (failure visible) | `04-fail-new-throw-visible.log` |
| 5 | `vector::resize(100000000)` | `vec-probe-linked.bc` | stops at the same throw external | `05-fail-resize-throw-visible.log` |
| 6 | OP_1 with CAP = 41 bytes | rebuilt module | `Proof succeeded!` | `06-cap41-proof.log` |
| 7 | OP_1 with CAP = 40 bytes | rebuilt module | allocation fails, reaches throw external | `07-cap40-throw.log` |
| 8 | OP_1 with allocation-size instrumentation | instrumented model | `Proof succeeded!` with `first_n = 1`, `last_n = 24` asserted | `08-instrumented-alloc-trace.log` |

Tool environment: `logs/00-tool-versions.log`.

The first attempt at run 2 failed at setup with
`Global symbol "wave16b_off" has no associated allocation`: SAW 1.6 does not
auto-allocate non-constant globals. The specs call `llvm_alloc_global` for the
model's three globals and initialise the two counters to 0. That is a harness
requirement, not a semantic assumption about the engine.

---

## 2. The model

`models/alloc-model.ll` (canonical; `build/build-heap-probe.sh` parameterises
its capacity). It replaces the four external allocator symbols that are
statically reachable from `EvalScript` at this pin:

| Symbol | Reached from | Model |
|---|---|---|
| `_Znwm` (`operator new(size_t)`) | `std::__new_allocator<T>::allocate` for `unsigned char` and `vector<unsigned char>` | bump-allocate; on exhaustion call `_ZSt17__throw_bad_allocv()` (left **external**) |
| `_ZdlPv` / `_ZdlPvm` (`operator delete`) | `std::__new_allocator<T>::deallocate` | no-op (arena never recycles) |
| `malloc` / `free` / `realloc` | `prevector<36,...>::change_capacity` (scripts > 36 bytes) | `malloc` = 16-byte-header block or `NULL`; `free` = no-op; `realloc` = header-aware copy or `NULL` |

Design points that matter for soundness:

1. **Failure is a first-class branch.** `_Znwm` has the C++ contract: it never
   returns null; if the arena cannot satisfy the request it calls the
   uninterpreted `_ZSt17__throw_bad_allocv`. Therefore a successful proof that
   does not reach that symbol is a proof that **the concrete requests fit**,
   not an assumption that `new` cannot fail. `malloc` returns `NULL` on
   failure, as C requires.
2. **No `ptrtoint`.** The bump cursor is an integer offset and blocks are
   `getelementptr i8, ptr @wave16b_heap, i64 offset`. Alignment is 16 bytes;
   every request is bumped by at least one byte, so distinct live objects get
   distinct addresses even for size 0. This avoids adding new B6
   (`ptrtoint`) surface.
3. **Explicit capacity.** The arena is a single global array of `CAP` bytes;
   `CAP` is parameterised (default 67,108,864 = 64 MiB).
4. **No recycling.** `free`/`delete` are no-ops. This is *conservative* for
   allocation failure (it uses more memory than a real allocator) and it cannot
   mask a use-after-free: a deallocated block is never reused, so a stale
   pointer still points at the old (leaked) contents rather than at a new
   object.

### What SAW caught in the model

The model was debugged with SAW, not by inspection:

* `logs/09-model-bug-overflow-counterexample.log`: the first oversize lemma
  failed with counterexample `n = 2^64-1`; the guard `n+1 > CAP` wrapped. Fixed
  to `n >= CAP`.
* `logs/10-model-bug-overlap-memory-error.log`: the model stored the request
  size instead of the new bump cursor, so blocks overlapped. SAW surfaced this
  as `Error during memory load` in `_Vector_impl_dataC2EOS2_` while moving
  vector elements. After storing `aligned + size`, all vector probes pass.
  This is evidence that the model is checked by execution, not assumed.

---

## 3. What was proved (machine-checked facts)

### 3.1 OP_1 engine path

* Spec: `specs/e5-verifyscript-op1-heapmodel.saw` (same concrete input as the
  E5 OP_1 spec: 40-byte `CScript` objects, `scriptSig` size 0, `scriptPubKey`
  size 1 with byte `0x51`, null witness, flags 0, readable checker/error).
* Result: `VerifyScript` returns `1` (`true`) on
  `e5-interp-script-roots3-heap.bc`.
* Instrumented run (`specs/e5-op1-instrumented.saw`, model
  `models/alloc-instrumented.ll`):
  * exactly **2** allocator calls;
  * first request **1 byte**, last request **24 bytes**;
  * final bump offset **41 bytes**.

  1 byte is the pushed `valtype` (`{1}`), 24 bytes is the outer
  `std::vector<std::vector<unsigned char>>` element array — i.e. the first
  `EvalScript` stack growth plus its payload, which is exactly the B2 event.
* Capacity threshold: the same proof succeeds with `CAP = 41` and fails (at
  the throw external) with `CAP = 40`. **The OP_1 proof therefore relies only
  on 41 bytes of arena, not on the 64 MiB default.** For this input,
  allocation failure is excluded by the concrete request sizes.

### 3.2 Allocator model lemmas (symbolic)

`specs/alloc-and-vector-lemmas.saw`, all `Proof succeeded!`:

| Lemma | Statement proved |
|---|---|
| `w16b_lemma_nonnull` | for symbolic `n` with `1 <= n <= 4096`, a fresh arena returns a non-null block |
| `w16b_lemma_oversize` | for symbolic `n >= CAP+1`, the model returns `NULL` (failure is observable) |
| `w16b_lemma_disjoint` | two symbolic requests in `[1,4096]` on a fresh arena both succeed and return **distinct** addresses |

### 3.3 Vector-growth refinement (real libstdc++ code)

`models/vec-probe.cpp` is ordinary C++ using `std::vector`; it is compiled at
`-O0` and linked with the allocator model. The proofs are over the **real
libstdc++ vector implementation**, not a re-implementation:

| Leaf | Property proved |
|---|---|
| `w16b_vec_push1` | `push_back` on an empty `vector<unsigned char>` with a **symbolic** byte yields `size == 1`, `capacity >= 1`, `v[0] == b` (packed return) |
| `w16b_stack_grow` | five `push_back`s on `vector<vector<unsigned char>>` (capacity 1→2→4→8, element moves, delete of old blocks) preserve the exact five pushed bytes and size 5 |
| `w16b_vec_resize64` | `resize(64, v)` fills and returns size 64 with `x[0] == x[63] == v` |

These are the unit-level refinement obligations for the "bounded vector/stack
abstraction" option: the abstract sequence semantics holds for the concrete
libstdc++ containers when the allocator model is underneath, for the tested
shapes. They do **not** prove the EvalScript loop (B3).

---

## 4. Allocation failure and the domain argument

The task forbids assuming `operator new` never fails. Three things are
separated here:

1. **On the proved OP_1 path, failure is not assumed away.** The model's
   failure branch was executed in runs 4, 5, 7 and stops at the
   uninterpreted throw helper. On the proved path the branch is *resolved* by
   concrete sizes (1 and 24 bytes, 41 bytes total). If those sizes had
   exceeded the arena, the proof would have failed exactly as run 7 does.
2. **The model does not claim glibc behaviour.** It claims: non-null blocks of
   at least the requested size, 16-byte aligned, pairwise distinct while live,
   contents preserved by `realloc`, and a `NULL`/throw failure observable. That
   is the abstract allocator contract Core's script code can observe. The
   refinement obligation (model ⇒ glibc/libstdc++) is stated in §6.
3. **For the full consensus domain, an informal capacity bound.** At the pin
   (`src/script/script.h`): `MAX_SCRIPT_SIZE = 10,000`,
   `MAX_STACK_SIZE = 1000`, `MAX_SCRIPT_ELEMENT_SIZE = 520`,
   `MAX_OPS_PER_SCRIPT = 201`. A single `EvalScript` stack can hold at most
   1000 × 520 B = 520 KB of payload plus 24 KB of outer vector control
   (capacity doubling adds < 2× churn). With the second stack, repeated
   push/pop over a 10 KB script and the absence of recycling, cumulative
   allocation is on the order of 10–25 MB for the nested
   scriptSig/scriptPubKey/redeem/witness `EvalScript` calls. The 64 MiB arena
   leaves ~3× headroom. This is a **counting argument, not a mechanised
   bound**: it becomes a proof only once the B3 loop invariant supplies the
   cumulative-allocation bound.

Note that Core's reaction to a real `std::bad_alloc` escaping `EvalScript` is
not a script error; it propagates out of validation. The model leaves that
path as an external on purpose, so any future proof that reaches it must say
what the contract does, rather than silently returning false.

---

## 5. What is *not* proved / remaining obligations

| # | Obligation | Why it remains |
|---|---|---|
| R1 | **Allocator refinement**: model ⇒ real libc/libstdc++ | The model is linked IR, not glibc. It must be shown to implement the abstract contract above (sizes, alignment, distinct live blocks, content preservation, failure observable). `free` being a no-op is conservative for capacity but must be justified as unobservable in the value semantics. |
| R2 | **Cumulative-capacity bound** | §4's 10–25 MB argument is informal; mechanising it needs the B3 invariant. The OP_1 result is capacity-independent above 41 bytes, but a symbolic-script result will need the bound. |
| R3 | **B3 loop invariant** | OP_1 executes one loop iteration with concrete bytes. A symbolic script still hits the unbounded `%336` loop. Unchanged by this work. |
| R4 | **Pinned-carrier provenance** | The probe module is the E5 `linked3` probe: derived from the **non-pin** `ir/interpreter-O0.bc` (`b8f17c1f…`, per `E5-RESIDUAL.md` §"Provenance caveat"), with exception erasure, ABI-global stubs and `__cxa_guard` pinning. The allocator step itself is independent of those transforms, but the OP_1 proof inherits them. Rebuild on the PINS `[core.ir]` carrier (`f5718af7…`) before citing a pinned result. |
| R5 | **Exception/guard policy** | Same assumptions as the existing E5 empty-script result (B4/B5). |
| R6 | **Symbolic inputs** | Concolic only: concrete script, flags, witness pointer and checker. No contract over all scripts. |
| R7 | **Other allocator users** | Only the statically reachable allocator entry points were modelled. `memcmp`, crypto and the checker seam are still external (B7); OP_1 does not reach them. |

Overclaim guard: this is **not** a green SCR row and not a whole-function
equivalence proof. The honest statement is: *on the linked3 probe lane, for
the concrete OP_1 input, with allocator model M, `VerifyScript` returns true;
and M's own failure path is explicit and separately exercised.*

---

## 6. Why the model is the right shape (design note)

Alternatives considered:

* **SAW override spec for `_Znwm`.** SAW 1.6 has no way to give a
  declaration-only function a spec without `llvm_unsafe_assume_spec`
  (forbidden), and its setup language cannot create a fresh symbolic-size
  allocation in a post-state. A linked, executable model is the only
  sound-by-construction option available in this toolchain.
* **`llvm_unsafe_assume_spec` that `_Znwm` returns a fresh block.** Rejected:
  it would hide the failure path, exactly what the task forbids.
* **Domain argument alone ("OOM is not in the domain").** Insufficient on its
  own: it would be an assumption. It is used only for capacity sizing; the
  proof itself resolves the branch on concrete sizes.

The model also deliberately keeps the arena global and the cursor global
visible, so a future proof can state capacity/bound postconditions over them.

---

## 7. Reproduction

```sh
# 1. build probe modules (writes only under the scratch OUT)
spec/equiv/findings/wave16b/03-e5-heap/build/build-heap-probe.sh

# 2. OP_1 through the allocator
/opt/equiv-tools/saw-1.6/bin/saw \
  spec/equiv/findings/wave16b/03-e5-heap/specs/e5-verifyscript-op1-heapmodel.saw

# 3. allocator + vector lemmas
/opt/equiv-tools/saw-1.6/bin/saw \
  spec/equiv/findings/wave16b/03-e5-heap/specs/alloc-and-vector-lemmas.saw

# 4. failure disclosure (expected exit 2, throw external)
/opt/equiv-tools/saw-1.6/bin/saw \
  spec/equiv/findings/wave16b/03-e5-heap/specs/fail-new-after-full.saw
/opt/equiv-tools/saw-1.6/bin/saw \
  spec/equiv/findings/wave16b/03-e5-heap/specs/fail-resize-big.saw

# 5. capacity threshold
CAP=41 OUT=/tmp/opencode/wave16b-scratch/03-e5-heap/cap41 \
  spec/equiv/findings/wave16b/03-e5-heap/build/build-heap-probe.sh
# then point the spec's llvm_load_module at .../cap41/...bc
```

The SAW specs contain the absolute module path
`/tmp/opencode/wave16b-scratch/03-e5-heap/...`; substitute if `OUT` differs.
The build script prints the SHA-256 of every input and output. Bitcode hashes are stable across different `OUT` paths (assembler/linker run with relative names); `alloc-model.bc` also depends on `CAP`.

Instrumented trace (run 8):

```sh
/usr/lib/llvm-20/bin/llvm-as models/alloc-instrumented.ll -o $OUT/alloc-instrumented.bc
/usr/lib/llvm-20/bin/llvm-link $ROOTS3 $OUT/alloc-instrumented.bc -o $OUT/probe-instr.bc
/opt/equiv-tools/saw-1.6/bin/saw specs/e5-op1-instrumented.saw
```

---

## 8. Recommended next step

1. **Rebuild the same probe from the PINS `[core.ir]` carrier and 15-TU
   closure** (`f5718af7…`, `204cf671…`) by restoring the missing E5
   `build-module.sh` transforms (exception erasure, internalisation, ABI
   stubs, guard pinning). This removes R4 and the E5 provenance caveat; the
   allocator model and specs are unchanged.
2. **Turn the model into a re-usable SAW cell**: lift `w16b_lemma_*` into a
   `heap-model` spec bundle and have E5 consume it as the standard allocator
   environment.
3. **Proceed to B3** (loop invariant at `%336`) with the capacity bound as a
   conjunct; then a symbolic OP_1-like script becomes a real contract.
4. For a ledger row, do not register `C-W16B-heap` as green: it is a
   prototype on a non-pin lane. Row promotion stays with Wave 16.

---

## 9. Artifacts

```
findings/wave16b/03-e5-heap/
  README.md                  this report
  models/alloc-model.ll      bounded explicit-failure allocator (canonical)
  models/alloc-instrumented.ll  alloc-model + per-call size capture (measurement)
  models/alloc-lemmas.ll     proof wrappers (nonnull / oversize / disjoint)
  models/vec-probe.cpp       real-libstdc++ vector leaves
  specs/e5-verifyscript-op1-heapmodel.saw
  specs/e5-op1-instrumented.saw
  specs/alloc-and-vector-lemmas.saw
  specs/fail-new-after-full.saw
  specs/fail-resize-big.saw
  build/build-heap-probe.sh  reproducible build, prints hashes
  logs/                      raw SAW stdout/stderr, tool versions
  SHA256SUMS
```

Module hashes (this run):

| Artifact | SHA-256 |
|---|---|
| `e5-interp-script-roots3.bc` (input, E5 linked3 probe) | `d287d14216fc1d1b5ed3461aad2ca96cf65bb00884b6abc85e9d90f9a74016a2` |
| `alloc-model.bc` (CAP=64 MiB) | `5d3e75635be7096daadc723aea3fdeeb56a9853208edfdfd6db3f75dfe9884bc` |
| `alloc-lemmas.bc` | `1f0b8ab3f8b1e2de35f6ab5a5d63d4566ad823737b88643e009b0590ef6a6cdb` |
| `vec-probe.bc` | `2bc44687038dc07638fbd9a91dd08c84d37161b3d764e6df90749500324e4735` |
| `e5-interp-script-roots3-heap.bc` | `24fb1e454d9864574a95bbffd7e89d609440cd4c802f8069c63806be210cd912` |
| `vec-probe-linked.bc` | `f375b4dbc5d846e2022c597ca986b7e94c5f2f012c7a4abea459d86abb699d32` |
