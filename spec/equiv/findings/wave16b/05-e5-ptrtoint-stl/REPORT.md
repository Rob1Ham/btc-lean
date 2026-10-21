# B6 — `ptrtoint` / `inttoptr` and the STL helpers reachable from `EvalScript`

**Task:** wave16b `05-e5-ptrtoint-stl` (structural unblocker for PR #29)
**Role:** E5 sub-investigation, adversarial
**Core pin:** Bitcoin Core v32.99 `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**IR lane:** `ir20/interpreter-O0.ll`, sha256 `fecf7db1…`, pinned bitcode
`f5718af7…`, clang/LLVM 20.1.2, `-O0 -g0`
**Tools:** SAW 1.6 (`68eed5f`), Alive2 v20.0 (`c0f5434`), clang 20.1.2
**Date:** 2026-10-20
**Verdict:** **B6 is smaller than stated, and its SAW-side treatment is a
data-structure invariant, not a pointer-provenance encoding.** Prototype only;
no whole-function or ledger claim. Full engine still blocked by B1–B5, B7.

---

## 0. One-paragraph result

The residual says 104 module-wide `ptrtoint` sites and 52 reachable from
`EvalScript` in 26 STL helpers, needing a sound "provenance model". That count
is right, but the **shape** is much narrower: every one of the 104 `ptrtoint`
results in the entire pinned module is used *exactly once*, as an operand of a
single `sub` whose other operand is a second `ptrtoint`. There is no
`inttoptr` at O0, and no absolute address is ever returned, stored, compared or
passed to a call. The only remaining side condition is the C++ rule that both
operands are in the same live allocation — a `std::vector` data-structure
invariant, not per-pointer provenance bits. SAW's existing LLVM memory model
already enforces it (a violated invariant is reported as UB, not abstracted
away), and the two real reachable `size()` helpers verify against an explicit
points-to invariant with no override and no `llvm_unsafe_assume_spec`. Alive2
SMT-proves the abstraction lemma and finds a counterexample for the negative
control. What still blocks an E5 green cell is B1/B2/B3/B4/B5/B7 and the fact
that the invariant is only stated, not proved, for symbolic vector states.

---

## 1. What was run

All commands are reproducible from the prototype cell
`spec/equiv/cells/e5-whole/P-w2b-05-ptrtoint-diff/`; raw output is in
`logs/` and in the cell's `result*.txt`.

| # | Probe | Command | Outcome |
|---|---|---|---|
| P1 | real `vector<u8>::size()` (26-site helper #2) on a 3-element vector in one allocation | `saw saw/p-diff.saw` | **Proof succeeded**, `size()==3` |
| P2 | real `vector<vector<u8>>::size()` (helper #1, `sdiv exact 24`) on 3×24-byte vector | same | **Proof succeeded**, `size()==3` |
| P1-neg | P1 setup, expectation `4` | `sh saw/run-negative.sh` (2nd probe) | **fails**: postcondition `4` vs `3` — the positive spec is non-vacuous |
| P3 | real `vector<u8>::size()` with `begin`/`end` in two different live allocations | `sh saw/run-negative.sh` (1st probe) | **fails with UB**: *"Subtraction of pointers from different allocations"* |
| P4-A | toy: `sub(ptrtoint(gep g,3), ptrtoint(gep g,0))` | `sh saw/run-toy-global.sh` | **Proof succeeded** (`3`) |
| P4-B | same with symbolic in-bounds GEP index `n` | same | **Proof succeeded** (`n`) |
| P4-C | toy: `ptrtoint @g - ptrtoint @h == 0` | same | **fails with UB** (negative control) |
| L1 | Alive2: `src` = GEP/ptrtoint/sub byte distance (concrete), `tgt` = `n` (abstract) | `sh alive2/run.sh` | **correct transformation** (SMT): the abstract model is defined wherever the concrete code is and agrees |
| L2 | Alive2: same + `sdiv exact 24` → element count | same | **correct transformation** (SMT) |
| L3 | Alive2 negative control: `ptrtoint @g & 1` vs `0` | same | **incorrect**, concrete counterexample |
| S1 | P-CORE-05 measurement: verbatim `CastToBool`/`CheckMinimalPush`, vector vs span, O0/O1 | `sh span/run.sh` | O0: 2 `ptrtoint` (both in `vector<u8>::size()`), O1: 4 (2 in each leaf); span overloads: **0 at both** |

`alive2/run.sh` parses the summary line and requires exactly
`2 correct / 1 incorrect / 0 failed-to-prove / 0 Alive2 errors`, so an SMT
timeout cannot be reported as a proof.

Tool versions (logged):

```
saw  1.6 (68eed5f release-1.6)
alive-tv  v20.0 (c0f5434), Ubuntu LLVM 20.1.2
clang  Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)
```

---

## 2. Reachable-site inventory

Full tables (26 + 11 + 12 rows, with mangled names, IR lines, shape, observable
and transitive external obligations) are in
[`reachable-sites.md`](reachable-sites.md); machine-readable:
[`site-census.tsv`](site-census.tsv).

### 2.1 Census

| module | roots | `ptrtoint` | `inttoptr` | helpers | distance-only helpers | violations |
|---|---|---:|---:|---:|---:|---:|
| `ir20/interpreter-O0.ll` (pinned, unpatched) | `EvalScript` | 52 | 0 | 26 | 26 | 0 |
| `ir20/interpreter-O0.ll` | all engine entry points | 78 | 0 | 37 | 37 | 0 |
| `ir20/interpreter-O0.ll` | module-wide | 104 | 0 | 49 | 49 | 0 |
| `ir20-proto/roots.bc.ll` (patched+erased) | `EvalScript` | 48 | 0 | 24 | 24 | 0 |
| `ir20-proto/roots.bc.ll` | all engine entry points | 74 | 0 | 35 | 35 | 0 |
| `ir20-proto/roots.bc.ll` | module-wide | 78 | 0 | 37 | 37 | 0 |
| `ir20/interpreter-O1.ll` | `EvalScript` | 330 | 2 | 21 | 15 | 8 |
| `ir20/interpreter-O1.ll` | all engine entry points | 447 | 2 | 37 | 28 | 12 |
| `ir20/interpreter-O1.ll` | module-wide | 559 | 4 | 57 | 44 | 20 |

"distance-only helper" = every `ptrtoint` result in the function has exactly
one use, an operand of a `sub` whose other operand is another `ptrtoint`.
"violation" = an escaped result (second use, store, compare, call argument,
non-`sub` arithmetic, or `inttoptr` involved).

Source: `logs/census.log`, `logs/inventory-*.log`, `logs/defuse-O0.log`,
`logs/defuse-O1.log`.

### 2.2 The sharper invariant (the actual finding)

```
ptrtoint definitions: 104
ptrtoint results used exactly once, as an operand of one `sub`: 104/104
```

Consumers of the resulting **byte distance** (not the address):
`returned` 10 + `sdiv exact` 52 + `trunc i32` 6 + passed as a size argument 18
+ stored as a count 18 (a `sub` result can have several consumers).

Consequence: at `-O0` there is **no observable absolute address anywhere in the
module**. The 52 reachable sites are 52 pairs; each pair is one
`end - begin`-style distance. Nothing needs to know *what* the base address is.

### 2.3 Split of the 26 `EvalScript`-reachable helpers

| obligation | count | helpers |
|---|---:|---|
| **pure** — zero external callees, distance only | 14 | `vector<u8>::size`, `vector<vector<u8>>::size`, 6 `__normal_iterator` `operator-`, 2 `prevector::operator-`, `__niter_wrap<T*>`, `__relocate_a_1<u8>`, `__fill_a1<u8>`, `__copy_m<const u8,u8>` |
| allocation (`_Znwm`/`malloc`/`realloc`) — **B2** | 5 | the three `_M_realloc_insert` instantiations, `basic_string::_M_construct`, `prevector::insert(input_iterator)` |
| deallocation only (`_ZdlPvm`) — B2-adjacent | 5 | both `_Vector_base` dtors, `_M_erase_at_end`, `__copy_m<vector<u8>*>` (move), `__copy_move_backward` |
| `memcmp` — **B7** | 1 | `__equal<true>::equal<u8>` |
| `std::terminate` only (exception path) | 1 | `basic_string::_S_copy_chars` |

So **B6 is separable from B2**: the `ptrtoint` itself adds no obligation beyond
the allocation invariant, and 14 of the 26 helpers need no heap model at all.
The heap-needing ones need B2 for their `operator new`/`delete`, not for their
`ptrtoint`.

### 2.4 The real blocker is not provenance, it is the vector invariant

For a pair `p = _M_start`, `q = _M_finish` (or any iterator pair) the IR
computes `sub i64 (ptrtoint q), (ptrtoint p)`. That is well defined **iff**
`p` and `q` point into the same live allocation. This is `[expr.add]` in C++,
it is what the compiler assumed, and it cannot be established from the two
pointer values alone:

```
INV_vec(v) :=  ∃ block b, cap:
   v._M_start, v._M_finish, v._M_end_of_storage ∈ {null} ∪ [b, b+cap)
∧  off(_M_start) ≤ off(_M_finish) ≤ off(_M_end_of_storage)
```

Under `INV_vec`, each site's distance is `sizeof(T) · (i_finish − i_start)`.
That is the whole of B6 at `-O0`.

`std::vector` maintains `INV_vec` by construction, but a *proof* of an engine
function must either (a) carry `INV_vec` as a points-to precondition for every
vector it touches, or (b) prove it as part of the stack-machine invariant that
B3 already needs. It is not free, but it is an ordinary separation-logic style
data-structure invariant — far cheaper than a provenance encoding, and it is
shared with B2/B3 rather than extra.

---

## 3. The smallest sound abstraction (prototype)

**Statement.** Do not abstract `ptrtoint`. Keep the real bitcode. Interpret it
in a byte-addressed, block-partitioned memory model where each live allocation
has a distinct base and each pointer is `(block, byte-offset)`. Then:

> **Lemma P-DIFF.** For any execution in which every reachable `ptrtoint` pair
> `(p, q)` satisfies `same_alloc(p, q)` and both offsets are in `[0, size)`,
> the value of `sub (ptrtoint p), (ptrtoint q)` equals `off(p) − off(q)`,
> and every consumer of that value observes only an element/byte count.

**Refinement obligation, stated exactly.**

1. *Shape obligation (machine-checked, O0 module).* All 104 `ptrtoint` results
   are single-use `sub` operands (`logs/defuse-O0.log`). If a future re-pin or
   patch introduces a use that observes the absolute value — store, compare,
   hash, call argument, `inttoptr` — the abstraction is **unsound** and must be
   re-derived. This obligation is per-module and must be re-run on every
   re-pin; `scripts/defuse_ptrtoint.py` + `scripts/census.py` are the check.
2. *Allocation obligation.* `INV_vec` (above) at every site. This is the only
   obligation not discharged here. It is discharged per concrete vector state
   by the points-to precondition (P1/P2) and, for symbolic states, must become
   part of the B3 stack invariant.
3. *Arithmetic obligation (machine-checked, Alive2).* L1 and L2 put the
   concrete `ptrtoint` code in `src` and the address-free model in `tgt`;
   Alive2's `correct` then means the abstract model is **defined wherever the
   concrete code is defined and returns the same value**, which is the
   soundness direction needed for an abstraction. (The opposite arrangement is
   rejected by Alive2 with *"Source is more defined than target"*; we ran it,
   recorded in the cell's `notes.md`.) L3 shows the obligation is load-bearing: with an observable
   absolute address bit the same check produces a concrete counterexample
   (`ptrtoint g & 1 = 1` vs `0`).
4. *No provenance bits.* Because of (1), a model with `(block, offset)` and no
   per-pointer provenance metadata is sufficient. Adding provenance bits would
   be sound but strictly unnecessary at O0.

**What SAW contributes.** Its LLVM memory model already implements exactly
this: pointer subtraction across allocations is UB, which fails the proof
rather than silently assuming aliasing. P3 is the direct evidence:

```
Subgoal failed: _ZNKSt6vectorIhSaIhEE4sizeEv internal: error: ...
Undefined behavior encountered
Details: Subtraction of pointers from different allocations
```

So the abstraction is *not* an override; it is "the real helper + a points-to
invariant". That is the smallest thing that is sound.

**What about `inttoptr`?** Zero at O0, four at O1. Nothing to model on the
proof lane.

---

## 4. What was actually proved, and what was not

Proved (evidence tier, prototype cell, **not** ledger rows):

- P1/P2: the two real `size()` helpers return the correct count for a concrete
  3-element vector whose triple points into one live array, under SAW, with no
  override and no unsafe assume. Non-vacuous (P1-neg).
- P4-A/B: same-allocation GEP difference is exactly the offset difference,
  concrete and symbolic, under SAW.
- P3/P4-C: SAW enforces allocation provenance; cross-allocation distance is UB.
- L1/L2: Alive2 SMT-proves the abstraction lemma for the two observable shapes
  (byte distance; element count via `sdiv exact`). L3 refutes the
  absolute-address leak.

Not proved / not claimed:

- **No whole-function `VerifyScript`/`EvalScript` result.** B1 (GetScriptOp),
  B2 (heap), B3 (loop invariant), B4 (exceptions), B5 (guards), B7 (crypto)
  are untouched.
- **No symbolic vector state in SAW.** `llvm_elem` takes a concrete index, so a
  symbolic `begin`/`end` offset cannot be written in a SAW setup. Symbolic
  coverage is the Alive2 lemma over the arithmetic, not the helper body.
- **No heap model.** `_M_realloc_insert*` and the `_Znwm`/`_ZdlPvm` paths stay
  blocked.
- **`roots.bc` caveat.** SAW cannot load the unpatched pinned lane (B4 ABI
  global), so P1–P3 use the CORE-IR patched+erased lane. Its `std::vector`
  bodies are instruction-identical, but the lane carries still-PROPOSED
  P-CORE-01/02/03.
- **No claim about `tinyformat`, ECDSA/Schnorr/SHA/RIPEMD internals**, or the
  checker seam.

---

## 5. Corrections to the existing evidence

Three precise corrections, all reproducible from the logs:

1. **§B6 says "26 `std::vector` / iterator / `tinyformat` helpers".** At `-O0`
   no `tinyformat` `ptrtoint` is reachable from `EvalScript` — or from any
   engine entry point. The 4 `printFormatStringLiteral` sites are in the
   unreachable set (12 helpers / 26 sites). The 26 helpers are all
   `std::vector` / `std::span` / `prevector` / `basic_string`; there are no
   `tinyformat` ones. Fix the wording, keep the count.
2. **The reachable surface is larger than 26/52 for anything beyond an
   `EvalScript`-only claim.** `VerifyScript`, `VerifyWitnessProgram`,
   `ExecuteWitnessScript` and `EvalChecksig*` add 11 helpers / 26 sites
   (78/37 engine-wide). The 52/26 figure is correct *only* for the stated
   `EvalScript` scope.
3. **P-CORE-05 (span leaf overloads) does not retire B6 at `-O0`.** Measured
   with verbatim leaf bodies (S1): at `-O0` the two leaf functions contain
   **no** `ptrtoint`; the pair sits in the shared out-of-line
   `std::vector<unsigned char>::size()`, which stays reachable through 17
   callers (`EvalScript` itself, `CScriptNum`, the signature-encoding checks,
   …). Span overloads remove 0 of the 52 reachable sites at O0. They remove
   `ptrtoint` from the leaves at `-O1` (4 sites) and remove vector/heap use
   from the leaves — useful for the O1 lane and for B2, **not** a B6 fix on the
   proof lane. `patches/core/README.md` P-CORE-05 should not be cited as a
   B6 remedy for the O0 lane.

Also worth recording for the ledger owner: **O1 is not merely "more
expensive", it is a different model.** At `-O1` there are 559 `ptrtoint` and 4
`inttoptr`, and 20 of the 559 results escape the pure-distance pattern:
13 have two or three uses, 2 are stored to memory, 2 are `xor`ed with `-1`
(pointer tagging), 2 are added to another integer, and 1 feeds a
`getelementptr` whose base is `inttoptr (i64 -1 to ptr)`. Absolute addresses
and integer-derived pointers *are* observable at O1. Any O1 claim needs a
genuine pointer/provenance model; the O0 argument above does not transfer.

---

## 6. Next experiment

**Single next step:** turn `INV_vec` from a stated precondition into a proved
stack-machine invariant for one bounded prefix of `EvalScript`, and re-run the
same checks on it.

Concretely, in the prototype cell:

1. Write a SAW spec for `std::vector<std::vector<unsigned char>>::push_back`
   (`_ZSt...push_back...` → `_M_realloc_insert`) with a *bounded* backing
   allocation (`cap = 4`) and the triple invariant, using the same
   pointer-slot + `llvm_cast_pointer` technique as `p-diff.saw`.
2. Verify a 4-element `push_back`/`pop_back` sequence (the stack's own
   operations) and assert that `size()` after the sequence is the expected
   count. This exercises `vector<vector<u8>>::size()`,
   `vector<u8>::size()`, both `_M_realloc_insert` instantiations and
   `__niter_wrap` together.
3. If (2) needs `_Znwm`, that is the B2 boundary — record the exact stop and
   hand the allocator spec to the B2 task rather than faking a never-failing
   allocator.
4. Re-run `scripts/census.py` + `scripts/defuse_ptrtoint.py` on the next
   re-pinned module as a gate. A single escaped `ptrtoint` result invalidates
   the abstraction and must fail the gate.

Secondary, cheap: extend the Alive2 lemma set to `sizeof(T) ∈ {1,24,32,48,112}`
and to a symbolic allocation size (the widths actually present in the table).
This is a few lines in `alive2/refine.ll`, not a new model.

---

## 7. Artifacts

Prototype cell: `spec/equiv/cells/e5-whole/P-w2b-05-ptrtoint-diff/`

| file | sha256 | what |
|---|---|---|
| `spec.md` | `7adc560f429badf6b4b615c744cc118fd373b4a74a0e41ab0ff46a5f61e89d33` | cell record (prototype) |
| `notes.md` | `cffb553ae8580425e91aa9368051c98bf6032fb1a2d1eeb9ac52bef43fa303d4` | gaps, weaknesses, direction experiment |
| `saw/p-diff.saw` | `ece8b58473663fef0e7317de622bb8dfa14056f2f5d62ea6c4751ff820a27c52` | P1/P2 |
| `saw/p-diff-cross-alloc.saw` | `5efeaf9967990986527da611a34691273539faa31c0de5f1a9f93cfb08f98f83` | P3 |
| `saw/p-diff-neg-expectation.saw` | `c0f4321b59d517098e6152778fc9f6a83677e7f139c6e10da2df6b6b1ffc7c67` | P1-neg |
| `saw/toy-global.ll` | `cbedb82b8a58d23b1129915239b3712aec669f6a70d5cb5c3e5408218b056d8a` | P4 IR |
| `saw/toy-global.saw` | `c097871e9c13c22ef556864530e4ecef88839aaebf7f640c3d6bb93d0bb6f113` | P4 |
| `alive2/refine.ll` | `581a6772303e162418d98db8d1d413f026688131952cade0f0703af82905ef6c` | L1/L2/L3 |
| `span/leaf-span.cpp` | `da7badbe422943f281bfb6658cc29d3e0d355f3f8ad4a05da8bf30879bfe238d` | S1 source |
| `saw/result.txt` | `8c4cadecaba5185073f39c0f1a100288857c5a796d5c2c6cc1d19120d3fec5d3` | P1/P2 raw |
| `saw/result-negative.txt` | `ab5d54da5f9b5d8780383a8a4e0e18ef946e740e71fddfbff8acfc19f0e4bbb4` | P1-neg + P3 raw |
| `saw/result-toy-global.txt` | `063a32ade398ca7097d05e89ddb93efcbc99a4d9ff21ce764e6b61db5e1b33a4` | P4 raw |
| `alive2/result.txt` | `ee27b5e6bb52c985ebca7f668890549cba94393a6af3a3b68dd9c667f62a6078` | L1/L2/L3 raw |
| `span/result.txt` | `e804c5093e71faec7ec59d61e7a8ba1c253bcd59c764df19411d4ffa3084d238` | S1 raw |

Input modules (outside the repo, as for all existing cells):

| module | sha256 |
|---|---|
| `ir20/interpreter-O0.ll` | `fecf7db1a0cb3f4b98f214b6211a206ff5cc267bb1cb0b1b73cd159945c18fec` |
| `ir20/interpreter-O0.bc` | `f5718af79c56ccfd5a5437a313d957573cb87c0de0cdf5641013991268801b2c` |
| `ir20-proto/roots.bc` | `2b9f683c4fdd3550e4eab43083a4c528ce785d37956f0f24b75311ec756f04a8` |
| `ir20/interpreter-O1.ll` | `2bb05718f5f090fdb7297aa0350bab6378f7b98c2f84e1e771d7ec5d77b7cb2f` |

Analysis scripts (run from `/tmp/opencode/equiv-work`):
`scripts/census.py`, `scripts/defuse_ptrtoint.py`, `scripts/inv_ptrtoint.py`,
`scripts/site_table.py`, `scripts/mk_sites_md.py`.

---

## 8. Honest limitations

- The prototype is concrete-input on the SAW side. It is the same concolic
  style as the existing `e5-whole` green lines and is **not** a contract.
- `roots.bc` carries still-PROPOSED patches; the `std::vector` bodies are
  unchanged but the lane is not the unpatched pin.
- The Alive2 lemma is stated in Alive2's block+offset memory model. It does not
  claim the x86-64 numeric layout, only that the address-free model is a
  refinement in the model the abstraction is expressed in.
- Nothing here is a Lean-kernel theorem; it is evidence-tier.
- B6 is **narrowed, not closed**: the remaining piece is proving `INV_vec` for
  symbolic vector states (shared with B3), and the heap-needing helpers still
  wait on B2.
