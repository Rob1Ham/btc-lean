# wave65/28 — E5 B5 (`__cxa_guard`) removed with a cell-local ABI model

**Status: machine-checked, cell-local, advisory. Not a ledger cell, not a
promotion, not a whole-`EvalScript` proof.**
**Base:** `76dbfe5e42f8a337e41a7308158b0de078afafd9` (branch
`wave65/28-e5-heap`).
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (v32.99).
**Tools:** clang/LLVM 20.1.2, SAW 1.6 (`68eed5f`), Alive2 v20.0 (`c0f5434`).

---

## 1. Bottom line

1. **One blocker is removed: B5, the `__cxa_guard` static-initialization
   assumption, on three concrete `VerifyScript` paths.** The wave16b/64 probe
   rewrote the three `EvalScript` guard variables to `constant i64 1`, i.e. it
   *assumed the static initializers had run*. This wave instead **executes the
   real initializers** under a cell-local Itanium-ABI guard model, with the
   guard bytes starting at 0, and proves the post-state guard bytes are 2.

2. **The old shortcut is not behavior-preserving, and we exhibit the
   divergence.** On `OP_1SUB` (`51 8c`) Core must return **false** (1 − 1 = 0).
   With the guards pinned to 1 the initializer never runs, `bnOne` stays 0, and
   `VerifyScript` returns **true**. SAW proves both outcomes on the respective
   modules; the "false" spec fails on the pinned module and the "true" spec
   fails on the modelled module. This is a concrete counterexample, not a
   theoretical objection: **a pinned-guard result for a numeric opcode is
   wrong**.

3. **The engine proofs now run on the pinned artifacts with no IR rewrite, no
   exception erasure, and no guard pinning.** They are on
   (a) the `[core.ir]` single-TU carrier `f5718af7…` plus `script.cpp` at the
   pin (B1 closed by linking), and (b) the canonical `[ir]` 15-TU closure
   `204cf671…` (B1 already closed there). The only additions are
   *cell-local models* (heap + guards) and six ABI typeinfo globals that no
   proved path reads.

4. **Exact capacity boundary.** `OP_1ADD` on the closure proves at `CAP = 66`
   and stops at `uninterpreted _ZSt17__throw_bad_allocv` at `CAP = 65`. The
   allocation trace is pinned by the postcondition
   (`calls = 4, first = 1, last = 1, off = hw = 66, failed = 0`). Allocation
   failure is still visible; nothing assumes "allocation always succeeds".

5. **What is *not* removed:** B3 (`EvalScript` loop invariant), B4 (exception
   no-throw), B6 (symbolic vector/`ptrtoint` invariant), B7 (crypto/checker
   seam), and the prevector `malloc/realloc` heap path for scripts > 36 bytes.
   See `INVENTORY.md` for the exact objects. In particular this wave does
   **not** claim a whole-`EvalScript` proof: `EvalScript` itself is still
   symbolic-trip and the proofs here are concrete-script executions.

---

## 2. The reduction and why it is behavior-preserving

The three `EvalScript` static locals and their guards are, at the pin:

```
static const CScriptNum bnZero(0);      // guard _ZGV…E6bnZero
static const CScriptNum bnOne(1);       // guard _ZGV…E5bnOne
static const valtype   vchTrue(1, 1);   // guard _ZGV…E7vchTrue (+ __cxa_atexit)
```

`EvalScript` entry (IR lines 3881–3941) runs, for each object:

```
  %g  = load atomic i8, ptr @guard acquire
  if (%g == 0) {
    if (__cxa_guard_acquire(&guard) != 0) {
        <initializer stores>
        __cxa_guard_release(&guard)
    }
  }
```

`models/cell-model.ll.tmpl` supplies:

| external | model | justification |
|---|---|---|
| `__cxa_guard_acquire` | byte 0 → 1, returns 1; otherwise returns 0 | the ABI state machine `0=uninit, 1=in-progress, 2=init` for a race-free single-threaded run |
| `__cxa_guard_release` | byte 1 → 2 | same |
| `__cxa_guard_abort` | byte 1 → 0 | same (only on an exception edge; not taken here) |
| `__cxa_atexit` | returns 0, handler dropped | static-local destructors run at process exit and cannot affect the value of a `VerifyScript` call |
| `_Znwm` / `_Znam` | 16-aligned bump allocation over a `[CAP x i8]` arena; exhaustion calls the **external** `_ZSt17__throw_bad_allocv` | M2 charge rule from `wave64/44`; failure stays visible |
| `_ZdlPv` / `_ZdlPvm` / `_ZdaPv` | no-ops (non-recycling) | value-unobservable for a UAF-free run (A2 of `wave64/44`) |

No instruction of the pinned module is changed; the models are separate
linked modules. `malloc/realloc/free/calloc` are deliberately left undefined:
they are the prevector path for scripts > 36 bytes, not reached here, and an
unproved model of them would be worse than stopping.

**Residual of this reduction (named, not hidden): O-GUARD.** The guard model is
the sequential restriction of the ABI. In a program where the three statics are
first-initialized concurrently by another thread, libstdc++'s atomic
acquire/release could make a second thread wait; the model would instead return
0 (already-initialized) as soon as byte 1 is observed. Core's script validation
does not require supporting that scenario for a *value* theorem (the object
contents after a completed initialization are identical), but the refinement
statement is single-threaded. SAW is sequential, so this is the strongest
statement obtainable with the tool.

---

## 3. Proof matrix (11 SAW runs, all expectations met)

Logs in `logs/`, specs in `specs/`, driver `harness/run-all.sh`.

| # | spec | module | script | outcome |
|---|---|---|---|---|
| 1 | `singletu-op1` | single-TU + `script.cpp`, CAP=128 | `51` | **proved** true; trace `calls=3, first=1, last=24, off=hw=57`; guards=2 |
| 2 | `singletu-op1add` | same | `51 8b` | **proved** true; trace `4/1/1/66/66` |
| 3 | `singletu-op1sub` | same | `51 8c` | **proved** false; trace `3/1/24/57/57` |
| 4 | `closure-op1add` | `[ir]` closure, CAP=128 | `51 8b` | **proved** true; `4/1/1/66/66` |
| 5 | `closure-op1sub` | closure, CAP=128 | `51 8c` | **proved** false; `3/1/24/57/57` |
| 6 | `closure-op1add-cap66` | closure, CAP=**66** | `51 8b` | **proved** true (exact boundary) |
| 7 | `neg-singletu-op1sub-expect-true` | single-TU, CAP=128 | `51 8c` | **Proof failed** (non-vacuity: correct result is false) |
| 8 | `neg-closure-op1add-cap65` | closure, CAP=**65** | `51 8b` | stops at external `_ZSt17__throw_bad_allocv` (one byte short) |
| 9 | `neg-closure-pinned-op1sub-expect-false` | guards pinned to 1 | `51 8c` | **Proof failed** (pinned module cannot return false) |
| 10 | `pinned-singletu-op1sub` | guards pinned to 1 | `51 8c` | **proved true** — divergence witness |
| 11 | `pinned-closure-op1sub` | guards pinned to 1 | `51 8c` | **proved true** — divergence witness |

Rows 10–11 are *not* results to use: they are the machine-checked proof that
the old assumption changes consensus behavior. Rows 1–6 are the sound result.

All runs are `llvm_verify … [] false <setup> z3`; no
`llvm_unsafe_assume_spec` appears in any spec.

### 3.1 What the trace post-conditions establish

* `calls = 3` on `OP_1` vs `calls = 2` in the old pinned module (`wave64/44`
  measured 2 requests / 41 bytes). The extra call is `vchTrue(1, 1)`, i.e. the
  static initializer really ran. On `OP_1ADD` it is `calls = 4`: the extra one
  past `OP_1` is `bn.getvch()` for the result 2.
* `failed = 0` and `off ≤ CAP` throughout; `off` is the exact cumulative charge.
* guard bytes `= 2` after the call, so all three are in the initialized state.
* `OP_1SUB` needs no `getvch()` allocation (result 0 → empty vector), which is
  why its `calls` is 3 and not 4 — the trace is discriminating, not a
  fixed guess.

---

## 4. Independent ingest checks

| check | result | log |
|---|---|---|
| Alive2 `VerifyScript`, closure + model | **rejected**: `Unsupported instruction: invoke`; 1 Alive2 error | `logs/alive2-verifyScript-closure.log` |
| Alive2 `_Znwm` leaf (self-comparison) | 1 correct, 0 errors — *translation only* | `logs/alive2-leaf-_Znwm.log` |
| Alive2 `__cxa_guard_acquire` leaf | 1 correct, 0 errors — *translation only* | `logs/alive2-leaf-__cxa_guard_acquire.log` |
| Alive2 `__cxa_guard_release` leaf | 1 correct, 0 errors — *translation only* | `logs/alive2-leaf-__cxa_guard_release.log` |

So the result is **SAW-ingestible and SAW-proved; Alive2 does not ingest the
engine**. The Alive2 leaf lines are not equivalence claims: a self-comparison
is Alive2's syntactic fast path.

### 4.1 SAW's `invoke` semantics (why B4 is not removed)

Micro-probe (not committed as a spec; harness in `harness/probe-invoke.sh`,
logs `logs/probe-invoke-{normal,unwind}.log`): a function

```
invoke void @may_throw() to label %ok unwind label %lp
ok: ret i32 1
lp: landingpad … ; ret i32 2
```

proves `return == 1` and **fails** `return == 2`. SAW 1.6 therefore executes
`invoke` as a non-unwinding call: the landing pad is not part of the semantics.
This is exactly what `erase_exceptions.py` achieved by rewriting `invoke` to
`call`; dropping the rewrite does not weaken the assumption, it only keeps the
artifact closer to the pin. **B4 remains an open obligation**: a no-throw proof
for the analysed domain, or `__cxa_*` overrides that preserve the
uncaught-exception result.

For the three concrete scripts, no throw *can* occur inside the model: the only
throwing site is `_Znwm` exhaustion, and `failed = 0` is proved together with
`off ≤ CAP`; `length_error` branches are concrete-false at these sizes. That is
a proof about the model's executions, not a semantics for `invoke`.

---

## 5. Relation to predecessor work

* `findings/wave64/44-e5-heap-refinement` proved the M2 allocator and pinned
  the `OP_1` trace at `calls=2, off=41`, but had to assume the guards were
  initialized. This wave reuses the M2 charge rule, adds the guard model, and
  removes that assumption. The allocator obligations O6/O7/O8 of that document
  apply unchanged here (model ≠ glibc; UAF-free reading; CAP is not a statement
  about the machine).
* `findings/wave16b/07-r-sanitize` documents the R-lane Alive2 walls. The C
  engine has only 4 atomic instructions, all guard acquire-loads; SAW ingests
  them. Alive2's `invoke` rejection is the C-side analogue of the R-side
  atomic/`sret` walls: Alive2 v20 has no exception semantics, so no engine-level
  Alive2 proof exists for either lane at this version.
* `findings/e5/E5-RESIDUAL.md` listed B5 as "accept P-CORE-03 or specify
  `__cxa_guard_acquire/release` and the initialization state in SAW". This wave
  does the second option and shows that the first (or the probe's guard
  pinning) would change behavior on `OP_1SUB`.

---

## 6. Reproduction

```sh
# 1. build modules into $OUT (default /tmp/opencode/wave65/28-e5-heap-scratch)
#    hash-checks f5718af7…, 204cf671…, script.cpp 657530a8…, and Core HEAD
spec/equiv/findings/wave65/28-e5-heap/harness/build.sh

# 2. regenerate the committed specs (absolute $OUT paths)
python3 spec/equiv/findings/wave65/28-e5-heap/models/gen-specs.py \
  /tmp/opencode/wave65/28-e5-heap-scratch \
  spec/equiv/findings/wave65/28-e5-heap/specs

# 3. run 11 SAW obligations and assert outcomes
spec/equiv/findings/wave65/28-e5-heap/harness/run-all.sh

# 4. Alive2 ingest checks
spec/equiv/findings/wave65/28-e5-heap/harness/alive2.sh

# 4b. SAW `invoke` micro-probe (B4 stays open)
spec/equiv/findings/wave65/28-e5-heap/harness/probe-invoke.sh

# 5. blocked-surface inventory
llvm-dis-20 /tmp/opencode/equiv-work/ir20/interpreter-O0.bc -o /tmp/opencode/wave65/28-e5-heap-scratch/pinned-interpreter-O0.ll
python3 spec/equiv/findings/wave65/28-e5-heap/harness/inventory.py /tmp/opencode/wave65/28-e5-heap-scratch/pinned-interpreter-O0.ll
```

Exact commands and hashes: `COMMANDS.md`, `logs/build-hashes.txt`.
Integrity of this directory: `cd` here and run `sha256sum -c SHA256SUMS`
(43 files: prose, models, specs, build harness, logs).

---

## 7. Honest scope and next experiment

* **Not** a whole-`EvalScript` proof: every proved script is concrete
  (`51`, `51 8b`, `51 8c`), 1–2 bytes, flags 0, no witness. The loop is
  unrolled once by construction.
* **Not** a green cell and not P-CORE. No Core patch is proposed here; the
  guard model lives entirely in this findings directory. Nothing in
  `PINS.lock`, `contract/`, `spec/db/`, `results/`, `docs/`, `spec/proofs/` or
  the twin/runtime was touched.
* The reachable call graph still contains 542 invokes / 111 landingpads
  (single-TU) whose unwind semantics SAW does not model; do not read this as an
  exception-safety result.

**Proposed next experiment (E5-B3):** instantiate the `%336` loop invariant for
a *bounded* script-length class, carrying
`off ≤ CAP` and the guard/static state as conjuncts, and use the guard model
from this wave as the entry-state lemma. Concretely: prove
`EvalScript` for all scripts of length ≤ N over the opcode set
`{OP_1, OP_1ADD, OP_1SUB}` with the same heap/guard model, then raise N until
the `getvch` allocation pattern forces the first `std::vector` growth edge.
That would turn the concrete trace into a length-indexed family and is the
smallest step that starts on B3 without pretending to handle symbolic scripts.
