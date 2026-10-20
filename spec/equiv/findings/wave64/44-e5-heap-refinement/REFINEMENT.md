# Refinement obligation — E5 B2 pinned heap calls

This file states, precisely and in one place, what allocator model **M2**
claims, what was proved, what is assumed, and what remains open. It is the
deliverable "precise refinement obligation" for the B2 heap step; the
machine-checked half is in `README.md` and `logs/`.

Notation: `CAP` is the arena size in bytes; `off` is the bump cursor;
`align16(x) = (x + 15) & ~15`; a request of `n` bytes is charged
`cost(n,off) = align16(off) - off + (n + 1)` (the `+1` keeps size-0 requests
address-distinct). `off' = off + cost(n,off)`.

---

## 1. The pinned surface

At Core `cce32b168` the PINS `[core.ir]` O0 carrier declares exactly
`_Znwm`, `_ZdlPvm`, `malloc`, `realloc`, `free`, with 22 direct call sites in
20 helper functions (`build/inventory_heap_calls.py`,
`logs/heap-call-sites.json`). `_Znam`/`_ZdaPv`/`calloc` are *not* declared in
this module; M2 defines them anyway so the model is closed under the allocator
API that the linked `script.cpp` TU and libstdc++ can introduce.

**O1 (coverage).** Every allocator symbol reachable from the probe is defined
by M2, and the failure helper stays undefined.

*Status: checked mechanically.* Stage 6 of `build/build-heap-pinned.sh` fails
if any of the eight symbols is undefined or if
`_ZSt17__throw_bad_allocv` is not external.

## 2. Abstract contract

M2 is claimed to implement, for every request on an execution inside the
domain of §5:

* **C1 (raw success):** `n ≥ 1 ∧ off = 0 ∧ n+1 ≤ CAP` ⇒ a non-NULL block.
* **C2 (raw failure):** `n ≥ CAP` ⇒ NULL, and the failure counter advances.
* **C3 (size):** a successful raw block has at least `n` usable bytes
  (`n+1` are charged and reserved).
* **C4 (alignment):** every raw block starts at `@w64_heap + align16(off_prev)`;
  `@w64_heap` has `align 16`, so the block is 16-aligned.
* **C5 (separation):** blocks are pairwise distinct while live. M2 never
  recycles, so this holds for *all* blocks ever returned, not just live ones.
* **C6 (C++ failure):** `_Znwm`/`_Znam` never return NULL; exhaustion calls
  `_ZSt17__throw_bad_allocv`.
* **C7 (C failure):** `malloc`/`calloc`/`realloc` return NULL on exhaustion;
  `realloc(NULL,n) = malloc(n)`; `realloc` success preserves
  `min(old,new)` bytes; `realloc` failure leaves the original block valid and
  unchanged.
* **C8 (free):** `free`/`_ZdlPv`/`_ZdlPvm`/`_ZdaPv` do not alter the
  value-visible contents of any block.

## 3. What was proved about M2

| Obligation | Statement | Evidence |
|---|---|---|
| **P1** | C1 for `1 ≤ n ≤ CAP-1` on a fresh arena | `w64_lemma_nonnull` |
| **P2** | C2 for `n ≥ CAP` (NULL) | `w64_lemma_oversize` |
| **P3** | C5 for two and three requests | `w64_lemma_disjoint`, `w64_lemma_three_distinct` |
| **P4** | C4 structural form: last GEP index ≡ 0 (mod 16); cursor `off ≤ CAP` | `w64_lemma_alignment` |
| **P5** | `malloc` non-NULL for `1 ≤ n ≤ CAP-17` | `w64_lemma_malloc_nonnull` |
| **P6** | failure is observable: full arena ⇒ NULL **and** `w64_failed == 1` | `w64_lemma_failed_counted` |
| **P7** | C7 failure leg: full arena ⇒ `malloc` NULL | `w64_lemma_malloc_full_null` |
| **P8** | C7 copy leg for shape 8→16 | `w64_lemma_realloc_preserve` |
| **P9** | C6 failure leg: full arena reaches `_ZSt17__throw_bad_allocv` | `specs/fail-new-full.saw` (stops at external) |

**Non-vacuity.** `specs/heap-lemmas-negative.saw` states P1 with `n ≥ CAP` and
ends in `Proof failed.` Every vector bound also has a `B(K)-1` companion that
fails.

**P4 caveat.** SAW 1.6 has no `ptrtoint`-free way to state "the returned
pointer is 16-aligned" as a pointer predicate. P4 proves the GEP index is a
multiple of 16 and the arena global is declared `align 16`; the pointer-level
corollary is the LLVM object-model implication, not a separately computed
address. This is deliberate: adding `ptrtoint` would enlarge B6.

Not proved about M2: `calloc` zeroing (the leaf is not reached by E5; it is
stated in the model and no proof consumes it), and the full
`realloc`-preserves-`n`-for-symbolic-`n` theorem (only 8→16 is proved).

## 4. Vector-growth refinement

For the E5 stack shape `std::vector<std::vector<unsigned char>>` the real
libstdc++ code at `-O0` refines the abstract sequence for the tested shapes:

* `w64_growth_bound_K`, `K ∈ {1,2,3,5,8,16,64,256,1000}`, with symbolic seed:
  size `K`, capacity `next_pow2(K)`, every byte `seed+i`, cumulative arena
  charge exactly `B(K)` (proved as `≤ B(K)` with the `B(K)-1` control failing),
  and at least one allocation.
* `B(K)` is computed by `build/gen_vec_growth.py` from request sizes,
  alignment and doubling — independently of the trace — and matches the
  native observed bytes exactly for all nine K.

**O4 (bounded refinement).** *Status: proved for the nine K above.*
**O5 (symbolic K / EvalScript loop).** *Status: open.* The general statement

```
for all K ≤ MAX_STACK_SIZE:
  size = K ∧ capacity = next_pow2(K) ∧ (∀i<K. v[i] = seed_i)
  ∧ off_final = B(K) ∧ B(K) ≤ CAP
```

needs a loop invariant; it is the same missing ingredient as B3 and is not
obtained by the finite family. The nine K are boundary representatives
(1, 2, 3, 5 cross the 1→2→4→8 growth edges; 1000 is `MAX_STACK_SIZE`), not a
substitute.

## 5. The domain, and why OP_1 is inside it

Define, for a fixed CAP,

```
D(CAP) = { executions e : Σ_{requests r in e} cost(r) ≤ CAP }
```

M2's transition system splits every request into "fits" (success) and "does
not fit" (NULL or throw). Therefore:

> **Transfer lemma (semantic, not yet mechanised as a theorem about Core):**
> if `e ∈ D(CAP)`, M2's execution of `e` never takes a failure edge, and any
> SAW proof whose post-state is reached on that execution is a proof about
> `e`. If `e ∉ D(CAP)`, M2 stops at a visible failure edge and says nothing
> about the script result.

For pinned OP_1 the request sequence is forced and was **measured by the
proof itself**:

```
request 1: inner std::vector<unsigned char>(1, 0x01)    n = 1   cost = 2
request 2: outer std::vector<vector<unsigned char>>      n = 24  cost = 39
                                                        total = 41
```

Hence OP_1 ∈ D(41), and the proof succeeds at CAP = 41. At CAP = 40 the
second request fails and SAW stops in `_Znwm` at the throw external: the
outside-domain witness. The result is **capacity-independent for CAP ≥ 41**
(the CAP = 64 MiB run has the same 41-byte trace).

**Important:** D(CAP) is a property of the *model*, not of the machine. A real
glibc process can fail even when `Σ cost ≤ CAP`. The OP_1 proof is therefore
conditional on the environmental assumption in O6, not an unconditional
"allocation succeeds" theorem. That is the honest reading of "do not assume
allocation success silently": the assumption is named, bounded, and its
negation is executable.

## 6. Remaining obligations, precisely

### O6 — M2 is implemented by the real allocator (open)

Required statement: for the request sequences in the analysed executions,
glibc/libstdc++ returns non-NULL blocks satisfying C3–C5, preserves contents
across `realloc`, and fails (throw/NULL) only outside D(CAP). This is **not**
mechanised and is not a consequence of M2. It decomposes into:

* **A0 (capacity availability):** the process can supply the cumulative
  requests; M2's CAP is a stand-in for this, not a proof of it.
* **A1 (growth law):** libstdc++ `vector` doubles capacity and requests
  exactly `capacity * sizeof(element)` bytes. This *was* checked for K ≤ 1000
  by the SAW leaves and the native measurement, for this toolchain/ABI; it is
  not a proof about every libstdc++ version.
* **A2 (UAF-freedom):** the analysed Core path has no use-after-free or
  double-free. Under A2, M2's non-recycling `free` is unobservable in the
  value domain and over-approximates capacity use. Without A2, a no-recycle
  model is not a refinement of glibc (it can keep a stale block readable where
  glibc would reuse it); this assumption must be discharged by a Core memory-
  safety argument or by a recycling model with a capacity theorem.

### O7 — O-CAP for E5 (open)

Required statement: for every `VerifyScript` execution admitted by the E5
contract, cumulative requests ≤ CAP. A conservative envelope under Core
v32.99 limits and A1/A2 (`build/domain_bound.py`):

| Term | Bytes |
|---|---:|
| outer stack growth churn (2 vectors, capacities 1…1024, 24 B) | 98,608 |
| inner element churn (10,000 ops × ≤ 520 B + alignment) | 5,360,000 |
| parser `prevector` allocations (≤ 10,000 pushed bytes) | 14,336 |
| `CScript` copies for signature ops (201 × 10,000) | 2,010,000 |
| small temporaries (1,000 × 64) | 64,000 |
| **per `EvalScript` call** | **7,546,944** |
| × 4 calls (scriptSig, scriptPubKey, redeem, witness) | **30,187,776** |
| CAP | 67,108,864 |
| headroom | **2.22×** |

This is a counting argument, not a proof. It is also pessimistic (counts
10,000 stack-producing ops even where the script-byte bound is tighter). The
B3 invariant at `%336` must carry `off ≤ CAP` and the per-iteration bound as a
conjunct; that is where O7 is discharged. If the mechanised bound exceeds CAP,
enlarge CAP (already a build parameter) or add a recycling allocator — not
weaken the failure branch.

### O8 — pinned-probe assumptions (inherited, unchanged)

The OP_1 proof runs on `interp-script-roots3.bc` (`2795c02e…`), built from the
PINS carrier `f5718af7…` plus `script-O0.bc` (`657530a8…`) with three
transformations: exception erasure (`invoke`→`call`, landing pads
`unreachable`), internalisation/`globaldce`, and ABI globals stubbed with
`__cxa_guard` bytes pinned to 1. These are the B4/B5 assumptions of the E5
residual and are **not** removed here. What *is* removed is wave16b R4: the
allocator proof no longer rests on the non-pin `b8f17c1f…` module.

### O9 — promotion (out of scope)

No ledger row, no Lean theorem, no whole-function contract. The OP_1 input is
concrete; `EvalScript`'s symbolic loop (B3) is untouched. The vector leaves
are not engine executions. Promotion remains with the E5/ledger owners.

## 7. Why the model shape is sound (design notes)

* A linked executable model is the only sound option in SAW 1.6 for
  `_Znwm`: declaration-only functions cannot get a spec without
  `llvm_unsafe_assume_spec`, which is forbidden. An override returning a fresh
  block would hide failure; M2 instead leaves the throw external.
* The bump cursor is an integer offset and blocks are `getelementptr` from a
  single global. No `ptrtoint`/`inttoptr` is introduced, so B6 is not enlarged.
* `off` stores `aligned + n + 1`, not the next aligned start. This was a real
  bug in the wave16b model (overlapping blocks, surfaced by SAW as a memory
  error); the corrected invariant `off ≤ CAP` is now itself a proved lemma.
* Charging `n+1` makes size-0 requests distinct, so C5 holds without a special
  case. The `+1` is visible in the B(K) table (e.g. K=1 is 41 bytes, not 40).

## 8. Reproduction map

| Obligation | Artifact |
|---|---|
| O1 | `build/build-heap-pinned.sh` stage 6; `logs/build.log` |
| P1–P8 | `specs/heap-lemmas.saw`; `logs/heap-lemmas.log` |
| non-vacuity | `specs/heap-lemmas-negative.saw`; `logs/heap-lemmas-negative.log` |
| P9 | `specs/fail-new-full.saw`; `logs/fail-new-full.log` |
| O4 | `specs/vec-growth-*.saw` (generated), `logs/vec-K-{good,bad}.log` |
| OP_1 pinned | `specs/e5-op1-pinned-heap.saw.tmpl`, CAP 64/41/40 logs |
| O6/O7 | `build/domain_bound.py`; `logs/domain-bound.txt` |
| pinned surface | `build/inventory_heap_calls.py`; `logs/heap-call-inventory.txt` |
