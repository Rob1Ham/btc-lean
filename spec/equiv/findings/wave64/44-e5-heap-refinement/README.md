# wave64/44-e5-heap-refinement — E5 B2 allocator/vector-growth refinement

**Task:** advance the E5 **B2** (heap/allocator) obligation by building a bounded
allocator/vector-growth model or a precise refinement obligation for the
**pinned** heap calls, testing it with real tools, and stating the allocation-
success domain instead of assuming it.

**Branch:** `wave64/44-e5-heap-refinement`, base `5946c02`
**Predecessor:** `findings/wave16b/03-e5-heap` (prototype on the **non-pin**
linked3 probe)
**Core pin:** Bitcoin Core v32.99 `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**PINS carrier:** `ir20/interpreter-O0.bc`, sha256
`f5718af7…01b2c` (PINS.lock `[core.ir]`)
**Tools:** SAW 1.6 (`68eed5f`, release-1.6); clang/LLVM 20.1.2; z3 bundled
**Deliverable type:** machine-checked prototype + explicit refinement
obligations. **Not** a green ledger row, **not** a Lean theorem, **not** a
whole-function contract, and **not** a proof about glibc.

---

## 0. Bottom line

1. **The wave16b allocator result is now reproduced on the pinned carrier.**
   `VerifyScript(OP_1)` on `interp-script-roots3.bc` (derived from the PINS
   `interpreter-O0.bc` `f5718af7…`, not the old `b8f17c1f…` lane) is proved
   with the bounded allocator model **M2** at CAP = 41 bytes:

   ```
   Proof succeeded! _Z12VerifyScript...
   ```

   The SAW post-state **pins the allocation trace** for this path:
   `calls = 2`, first request `1` byte, last request `24` bytes,
   `off = hw = 41`, `failed = 0`. At **CAP = 40 the same spec stops** in
   `_Znwm` at the uninterpreted `_ZSt17__throw_bad_allocv`. Allocation success
   is therefore a *resolved concrete fact for this input*, not an assumption.
   This removes wave16b residual **R4** for the allocator step (the probe's
   exception-erasure/guard-pinning assumptions B4/B5 remain).

2. **A bounded vector-growth refinement now has cumulative-capacity bounds.**
   For `std::vector<std::vector<unsigned char>>` — the exact `EvalScript`
   stack shape — SAW proves, for every `K ∈ {1,2,3,5,8,16,64,256,1000}`:
   `size == K`, `capacity == next_pow2(K)`, every element byte
   `v[i] == seed+i` (symbolic `seed`), and cumulative arena use
   `off <= B(K)` where `B(K)` is a **closed-form prediction computed outside
   the execution**. Negative controls with bound `B(K)-1` fail for every `K`,
   so the bounds are exact and non-vacuous. `B(1000) = 65,282` bytes
   (96.1 % of the first 64 KiB; examples: `B(5)=481`, `B(64)=4,162`).

3. **Failure is visible in every model layer.** The C++ `new` path throws an
   external; `malloc`/`realloc` return `NULL`; a failed request increments
   `w64_failed` (proved). With CAP = 41, five vector pushes stop at the throw
   external; with CAP = 40, OP_1 stops there. No `llvm_unsafe_assume_spec` is
   used anywhere.

4. **The E5-domain side condition is stated, not discharged.** Model M2 only
   proves no failure inside its finite arena. The residual obligation is

   ```
   O-CAP:  cumulative allocator requests on every executed VerifyScript path
           <= CAP
   ```

   A conservative counting envelope (Core limits 10,000 / 1,000 / 520 / 201,
   four `EvalScript` calls, no recycling) is **30,187,776 bytes vs CAP =
   67,108,864 → 2.22× headroom**. That is a *counting argument*, not a proof;
   the B3 loop invariant must discharge it. It is also conditional on the real
   process allocator satisfying the requests (O6).

---

## 1. What the pinned heap calls are

`build/inventory_heap_calls.py` disassembles the PINS carrier and inventories
the allocator surface. The pinned single-TU module declares exactly five
allocator symbols:

| Symbol | Declaration line in `pinned-interpreter-O0.ll` | Role |
|---|---|---|
| `_Znwm` | 19621 | `operator new(size_t)`; `std::__new_allocator<T>::allocate` |
| `_ZdlPvm` | 19997 (sized delete) | `std::__new_allocator<T>::deallocate` |
| `malloc` | 25050 | `prevector<36,…>::change_capacity` |
| `realloc` | 25047 | `prevector<36,…>::change_capacity` |
| `free` | 20246 | `prevector` destructor/assignment |

There are **22 direct call/invoke sites in 20 helper functions** (JSON:
`logs/heap-call-sites.json`). `EvalScript` reaches them indirectly through the
standard containers; the two OP_1 requests correspond to
`_ZNSt15__new_allocatorIhE8allocateEmPKv` (inner `valtype`, 1 byte) and
`_ZNSt15__new_allocatorISt6vectorIhSaIhEEE8allocateEmPKv` (outer stack
array, 24 bytes). After linking M2 the build script asserts that none of the
five symbols is undefined and that `_ZSt17__throw_bad_allocv` **is** still
undefined (`build/build-heap-pinned.sh`, stage 6).

## 2. Model M2

`models/heap-model.ll.tmpl`, generated per CAP by
`build/gen_heap_model.py`:

* one 16-aligned global arena `[CAP x i8]`, bump cursor `w64_off`, high-water
  `w64_hw`, request/failure counters, first/last request sizes;
* `_Znwm`/`_Znam`: non-null on success; on exhaustion call the external
  `_ZSt17__throw_bad_allocv` (C++ contract — never a silent `NULL`);
* `malloc`: 16-byte size header, `NULL` on failure; `calloc`: overflow-guarded
  zero fill; `realloc`: header-aware copy of `min(old,new)`, original block
  untouched on `NULL`;
* `free`/`_ZdlPv`/`_ZdlPvm`/`_ZdaPv`: non-recycling no-ops;
* no `ptrtoint`/`inttoptr`.

M2 refines wave16b's model in three ways that matter for a *refinement
obligation*: CAP is a build parameter (threshold runs are cheap), the cursor
and failure state are observable globals (SAW can pin traces), and the
alignment/capacity invariants are stated as proof wrappers rather than prose.

### Proved model lemmas (all `Proof succeeded!`)

`specs/heap-lemmas.saw` over `cap64/lemmas-linked.bc`:

| Lemma | Statement |
|---|---|
| `w64_lemma_nonnull` | `1 ≤ n ≤ CAP-1` on a fresh arena ⇒ non-NULL |
| `w64_lemma_oversize` | `n ≥ CAP` ⇒ NULL |
| `w64_lemma_disjoint` | two successful requests ⇒ distinct addresses |
| `w64_lemma_three_distinct` | three successful requests ⇒ pairwise distinct |
| `w64_lemma_alignment` | after three successes, last GEP index ≡ 0 mod 16 and `off ≤ CAP` |
| `w64_lemma_malloc_nonnull` | `1 ≤ n ≤ CAP-17` ⇒ `malloc` non-NULL |
| `w64_lemma_failed_counted` | full arena ⇒ NULL **and** `w64_failed == 1` |
| `w64_lemma_malloc_full_null` | full arena ⇒ `malloc` returns NULL |
| `w64_lemma_realloc_preserve` | `malloc(8)` pattern → `realloc(16)` preserves 8 bytes |

`specs/heap-lemmas-negative.saw` proves the nonnull lemma is non-vacuous: the
same postcondition with `n ≥ CAP` ends in `Proof failed.`

## 3. Bounded vector-growth refinement

`models/vec-growth.cpp.tmpl` is ordinary C++ over the **real libstdc++**
`std::vector` at `-O0 -fno-exceptions`, linked under M2. Per `K` it checks
size, final capacity, every byte, and `off <= B(K)`; `B(K)` comes from
`build/gen_vec_growth.py`, which mirrors the request/alignment accounting
(inner 1-byte vectors; outer 24-byte elements; capacity doubling; no
recycling).

Observed cumulative bytes (native run `build/measure_growth.cpp`) equal the
prediction exactly for every K:

| K | final capacity | B(K) | native observed |
|---:|---:|---:|---:|
| 1 | 1 | 41 | 41 |
| 2 | 2 | 113 | 113 |
| 3 | 4 | 241 | 241 |
| 5 | 8 | 481 | 481 |
| 8 | 8 | 530 | 530 |
| 16 | 16 | 1,058 | 1,058 |
| 64 | 64 | 4,162 | 4,162 |
| 256 | 256 | 16,482 | 16,482 |
| 1,000 | 1,024 | 65,282 | 65,282 |

SAW proves `off ≤ B(K)` for all nine K, and the companion `B(K)-1` leaf fails
for all nine. This is a **bounded-family** refinement, not a theorem for
symbolic K: the general-K obligation is O5 (needs the same invariant work as
B3). At CAP = 41 the K=5 leaf stops at the throw external, so the bound is
also shown to bite at a real capacity boundary.

## 4. Domain (do not read this as "allocation cannot fail")

M2 defines failure by capacity: a request succeeds iff
`align16(off) + n + 1 ≤ CAP`. The proved statements are therefore of the form

> **If** the analysed execution's cumulative requests fit CAP (and the real
> process allocator can satisfy them), **then** the stated value/refinement
> property holds; otherwise execution reaches the explicit `bad_alloc` edge.

* OP_1 is **inside** the domain at CAP = 41 because its two requests cost
  exactly 41 bytes; the CAP = 40 run is the outside-domain witness.
* The K ≤ 1000 vector-growth family is inside a 64 MiB domain with ≥ 1,000×
  headroom, but each leaf is conditional on its own bound.
* Full E5 is **not** proved inside the domain. The counting envelope is
  30.2 MB (2.22× headroom); O-CAP remains open until B3 supplies
  `off ≤ CAP` as a loop invariant.

Two further honest restrictions: M2 is not glibc (O6), and its no-recycle
`free` is only unobservable for a UAF-free execution (A2 in
`REFINEMENT.md`). The OP_1 and vector results inherit the pinned probe's
exception-erasure and `__cxa_guard` pinning (B4/B5), though not the old
non-pin provenance (R4).

## 5. Evidence and reproduction

All outputs are under
`/tmp/opencode/wave64/44-e5-heap-refinement-scratch` (never in another agent's
tree). Raw logs are committed under `logs/`.

```sh
# build (hash-checks the PINS carrier and the pinned B1 probe first)
spec/equiv/findings/wave64/44-e5-heap-refinement/build/build-heap-pinned.sh

# run all 26 SAW obligation runs and assert expected outcomes
spec/equiv/findings/wave64/44-e5-heap-refinement/build/run-all.sh
```

| Run | Spec | Outcome |
|---|---|---|
| lemmas | `specs/heap-lemmas.saw` | 9 × `Proof succeeded!` |
| lemma negative control | `specs/heap-lemmas-negative.saw` | `Proof failed.` (required) |
| OP_1, pinned, CAP=64 MiB | `e5-op1-pinned-heap-64.saw` | `Proof succeeded!`, trace 2/1/24/41 |
| OP_1, pinned, CAP=41 | `e5-op1-pinned-heap-41.saw` | `Proof succeeded!`, trace 2/1/24/41 |
| OP_1, pinned, CAP=40 | `e5-op1-pinned-heap-40.saw` | stops in `_Znwm` → `_ZSt17__throw_bad_allocv` |
| OP_1 negative control | `e5-op1-pinned-heap-negative.saw` | `Proof failed.` (required) |
| full-arena `new` | `specs/fail-new-full.saw` | stops at throw external (required) |
| K=5 at CAP=41 | `vec-5-cap41-good.saw` | stops at throw external (required) |
| vector bounds, 9 × K | `vec-K-good.saw` | 9 × `Proof succeeded!` |
| vector bound controls, 9 × K | `vec-K-bad.saw` | 9 × `Proof failed.` (required) |

`logs/RUN-EXIT-CODES.txt` records every exit code and the assertion result.

Module hashes (final build; full list in `logs/build-hashes.txt`):

| Artifact | SHA-256 |
|---|---|
| PINS `interpreter-O0.bc` (input) | `f5718af79c56ccfd5a5437a313d957573cb87c0de0cdf5641013991268801b2c` |
| pinned B1 probe `interp-script-roots3.bc` | `2795c02ea67c77ff3674d16da074b1f8b884861fc6f157b6274feba9d8227ae1` |
| M2 model, CAP=64 MiB | see `logs/build-hashes.txt` |
| `pinned-probe-heap-41.bc` | `2a8d1d938d541df72d7be59e4c4d5f95c8332ec4c3cd900f1103d1e483419df6` |
| `pinned-probe-heap-40.bc` | `0d6ef3a142f4cd79e8a63f57f321a5b741aacce125b22a0f80e4f3e355fac266` |
| `vec-1000-linked.bc` | `b3168ea85bf8aab29db5e25c62b8e9939894d6b48ecd1bb0df6434258a299d48` |

## 6. Residual obligations (precise)

See `REFINEMENT.md` for statements, assumptions and status. Summary:

| # | Obligation | Status |
|---|---|---|
| O1 | M2 defines every pinned allocator symbol; throw stays external | **mechanical** (build stage 6) |
| O2 | non-null/aligned/distinct/capacity/failure-observable contract | **proved** (9 lemmas, CAP=64 MiB; threshold runs at 41/40) |
| O3 | realloc/calloc semantics | realloc **proved** (8→16); calloc not reached by E5, **stated only** |
| O4 | real-libstdc++ vector growth refines the stack abstraction for K ≤ 1000 | **proved** (bounded family + exact bounds) |
| O5 | vector growth for symbolic K, and E5 `EvalScript` stack loop | **open** (B3 invariant) |
| O6 | M2's contract is implemented by glibc/libstdc++ on the analysed domain | **open** (external assumption; not mechanized) |
| O7 | O-CAP: cumulative requests ≤ CAP on every executed path | **open**; envelope 30.2 MB vs 64 MiB (2.22×) |
| O8 | UAF-free execution (so no-recycle free is unobservable) | **assumption A2** |
| O9 | pinned probe still carries B4 exception erasure / B5 guard pinning | **inherited**, unchanged |

## 7. Overclaim guards

* This is **not** a whole-function `VerifyScript` contract: OP_1 has concrete
  script bytes, null witness, flags 0 and a null-ish checker; the symbolic
  vector leaves are not engine executions.
* It is **not** a proof that `operator new` never fails in a real process; it
  is a proof that the analysed requests fit a stated finite arena, with the
  failure edge executable and separately exercised.
* It is **not** a green `SCR` row and does not promote the wave16b prototype.
* The pinned lane removes R4 for the allocator step only; B3, B4/B5, B7 and
  the checker seam remain.

## 8. Next step

Discharge O-CAP by adding the capacity conjunct to the B3 invariant at
`%336`, then instantiate the general-K vector bound for
`K ≤ MAX_STACK_SIZE`. If the mechanised bound exceeds CAP, either enlarge the
arena (parameter is already in the build) or add a recycling allocator with a
proved capacity theorem — do **not** weaken the failure branch.
