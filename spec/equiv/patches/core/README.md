# CORE patch registry — `patches/core/`

**Status: PROPOSED.** These patches are prototypes for the IR lane. None has
been merged, committed, or accepted as behavior-preserving. The differential
runs required by `patches/README.md` §3 have **not** been executed in this
work session. Do not cite a cell as green while it depends on a patch marked
PROPOSED.

Pinned target: Bitcoin Core `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
(v32.99). All line numbers below are the **pinned upstream** lines, not
post-patch line numbers.

The three implemented patches are guarded by preprocessor macros and are
no-ops unless the macro is defined. The lane build defines all three:

```
-DBTC_EQUIV_NO_SCRIPTNUM_THROW -DBTC_EQUIV_HOIST_STATICS -DBTC_EQUIV_DEVIRT
```

Apply order used for the reproduced artifact: 01, 02, 03. Each patch also
passes `git apply --check` against the unmodified pin on its own (verified;
see `findings/core/commands.md`).

---

## Registry

| ID | Upstream file:line | Purpose | Evidence | Upstream status |
|---|---|---|---|---|
| **P-CORE-01** | `src/script/script.h:246-268`; `src/script/interpreter.cpp:67-71`, `:556`, `:584`, `:840`, `:939`, `:972-973`, `:1017-1019`, `:1103`, `:1126`, `:1140`, `:1236-1243` | Replace every throwing `CScriptNum(vector)` construction in `EvalScript` with a non-throwing return that sets `SCRIPT_ERR_SCRIPTNUM` at the original site; remove the `scriptnum_error`/catch-all edges | Prototype compiled; IR has no `scriptnum_error` landing pads; exception-erased IR ingests in Alive2/SAW. **Differential not run.** | Lane-only as written; the non-throwing helper is upstreamable in principle, the `assert`/catch removal is domain-restricting |
| **P-CORE-02** | `src/script/interpreter.h:275-298`, `:331-334`, `:348-364`; engine call sites `src/script/interpreter.cpp:349`, `:380`, `:565`, `:599`, `:1177`, `:1972` | Devirtualize `BaseSignatureChecker`: four `extern "C"` hooks replace vtable dispatch; subclasses keep compiling via empty `BTC_EQUIV_OVERRIDE` | Prototype compiled; **0 indirect call sites** in `EvalScript`, `VerifyWitnessProgram`, `EvalChecksigPreTapscript`, `EvalChecksigTapscript` at O0. **Differential not run.** | Lane-only; the hook seam is not an upstreamable Core change without a concrete checker ABI decision |
| **P-CORE-03** | `src/script/interpreter.cpp:423-426` (and hoist before `:417`) | Hoist `EvalScript`'s function-local constant statics (`bnZero`, `bnOne`, `vchFalse`, `vchTrue`) to namespace scope; removes `__cxa_guard_*` atomic loads/landing pads | Prototype compiled; `__cxa_guard` in the module falls 15→6 and `EvalScript` loses its guard path. **Differential not run.** | Refactor-only; upstreamable in principle, but it perturbs static-initialization timing |
| **P-CORE-04** | `src/script/interpreter.cpp:417-1249` (`EvalScript`), loop `:449-1234`, switch `:494-1229` | **Design only.** Extract the loop body into a `static bool EvalStep(EvalContext&)` so a tool can slice/unroll one dispatch step; then optionally split the switch into family helpers | No artifact; design below | Not upstreamable as-is (large refactor); lane-only until accepted as a mechanical refactor |
| **P-CORE-05** | `src/script/interpreter.cpp:46-61` (`CastToBool`), call sites `:638`, `:669`, `:782`, `:1004`, `:1878`, `:2039`, `:2085`; `src/script/script.cpp:373` (`CheckMinimalPush`), declaration `src/script/script.h:607` | **Design only.** Add `std::span<const unsigned char>` leaf overloads and make the vector forms forward to them; removes O1 `ptrtoint` from the leaves | `leaf.cpp` experiment (separate TU): span version has 0 `ptrtoint`/`inttoptr` at O0 and O1; vector version has 2 `ptrtoint` at O1 | Upstreamable as a small cleanup, but not yet prototyped inside Core |

---

## P-CORE-01 — non-throwing ScriptNum conversion

### Diff

`P-CORE-01-scriptnum-error-returns.patch` (15 hunks across two files).

1. `src/script/script.h`: adds a default constructor and
   `CScriptNum::from_vch(vch, fRequireMinimal, nMaxNumSize, out)`.
   `from_vch` copies the exact two rejection predicates from the throwing
   constructor (`vch.size() > nMaxNumSize`; non-minimal encoding test) and
   then calls the private `set_vch(vch)` — the same final step as the
   constructor.
2. `src/script/interpreter.cpp`: adds `GetScriptNum(...)`, which calls
   `from_vch`, sets `SCRIPT_ERR_SCRIPTNUM` on failure, and returns `false`.
3. All 12 engine call sites construct `CScriptNum` through `GetScriptNum` and
   `return false` on failure at the same program point where the old
   constructor would have thrown. The 12 sites are exactly:
   `:556`, `:584`, `:840`, `:939`, `:972`, `:973`, `:1017`, `:1018`,
   `:1019`, `:1103`, `:1126`, `:1140`.
4. `popstack` (`:67-71`) replaces its throw with `assert(!stack.empty())`.
5. The `try` at `:447` and the two catch blocks at `:1236`/`:1240` are
   compiled out.

### Behavior-preservation argument (on the non-buggy domain)

- The overflow/minimality decision and the produced `m_value` are identical:
  `from_vch` evaluates the same predicates in the same order and calls the
  same `set_vch`.
- The old `catch (const scriptnum_error&)` returned
  `set_error(serror, SCRIPT_ERR_SCRIPTNUM)`. The new path sets that exact
  error and returns at the same call site. No later opcode action is skipped
  or reordered because the old throw unwound directly to the catch.
- The `catch (...)` path (`SCRIPT_ERR_UNKNOWN_ERROR`) is now unreachable for
  ScriptNum errors. It remains a **domain restriction** for other exceptions:
  allocation failure in `std::vector`, `at()` out-of-range, etc. now
  propagate instead of mapping to `UNKNOWN_ERROR`.
- `popstack` empty-stack is a Core invariant violation. Old behavior was
  `throw runtime_error` → `catch (...)` → `SCRIPT_ERR_UNKNOWN_ERROR`; new
  behavior is an assertion abort. This is **not** equivalent on that bug
  path. It is treated as out-of-domain and must be fuzzed to show it is
  unreachable from the shim domain.

### Differential test plan (required before merge)

1. Build Core at the pin twice, same compiler/flags, differing only in
   `-DBTC_EQUIV_NO_SCRIPTNUM_THROW`: (a) unpatched reference binary;
   (b) patched binary. Build both the `equiv_entry` shim and a direct
   `EvalScript`/`VerifyScript` driver.
2. Corpus: all 1,258 `script_tests.json` rows (hash
   `7fb93dea245f68b627d214e0d51969c4f29fefaae1ac94ca1eba5fe8322f864c`),
   all 500 `sighash.json` rows
   (`52cf23c2076e7f129c71d5508631d3e5ae3be1b1cb0585c0e23bbb4bb373e924`),
   and the 1788 tier-G generated rows if available.
3. Fuzz lane: ≥1,000,000 generated scripts biased to numeric opcodes,
   `MINIMALDATA`, 4/5-byte operands, negative zero (`0x80`), and
   overflow-length operands; run both binaries on identical tapes.
4. Compare `(result, error_kind)` exactly, including error precedence.
   Zero divergences required.
5. Negative control: mutate one call site to return `SCRIPT_ERR_OK`; the
   harness must flag the corpus rows that expect `SCRIPT_ERR_SCRIPTNUM`.
6. Record the corpus hash, binary hashes, fuzz seed, and diff count in this
   registry before changing the status from PROPOSED.

---

## P-CORE-02 — checker devirtualization

### Diff

`P-CORE-02-devirtualize-checker.patch` (4 hunks, `src/script/interpreter.h`
only).

Under `BTC_EQUIV_DEVIRT`:

- `BaseSignatureChecker` becomes a concrete class holding `const void* m_ctx`.
  Its four methods call `btc_equiv_check_{ecdsa,schnorr,locktime,sequence}`.
- `BTC_EQUIV_OVERRIDE` expands to nothing, so
  `GenericTransactionSignatureChecker` and `DeferringSignatureChecker`
  declarations still parse.
- `~BaseSignatureChecker` is non-virtual in this mode.

The engine call sites are unchanged: `interpreter.cpp:349`, `:380`, `:565`,
`:599`, `:1177`, `:1972`. Because the methods are now non-virtual and the
engine receives `const BaseSignatureChecker&`, those calls bind statically to
the hooks.

### Behavior-preservation argument

At the harness boundary there is exactly **one** concrete checker,
`TransactionSignatureChecker` (see `shims/core/entry.cpp:140`), so the
devirtualized target is the same function the vtable selected. The hook
signatures preserve the arguments the virtual methods received:
`scriptSig`, `vchPubKey`, `scriptCode`, `sigversion`, Schnorr `execdata` and
`serror`, and `nLockTime`/`nSequence` as `int64_t` (the only state of
`CScriptNum`). The four hook bodies are the contract.

This is **not** a general-purpose devirtualization: a different checker
(e.g. a test mock passed as `BaseSignatureChecker`) would no longer dispatch
to its override. The lane's single-checker premise is part of the trust note.

### Required shim coupling (CONTRACT role, `shims/core/`)

`shims/core/entry.cpp` currently constructs
`TransactionSignatureChecker checker(&tx, input_index, amount, txdata,
MissingDataBehavior::FAIL)` at lines 137-149 and passes it to `VerifyScript`.
For a `BTC_EQUIV_DEVIRT` build it must instead:

1. Construct a `BaseSignatureChecker` whose `m_ctx` points at a context that
   owns the `CTransaction`, input index, amount, `PrecomputedTransactionData`,
   and `MissingDataBehavior` (or at the existing
   `TransactionSignatureChecker`).
2. Define the four `extern "C"` hooks in the shim TU, forwarding to the
   stored `TransactionSignatureChecker`'s methods.
3. Preserve the empty-script case: if `script_len == 0`, do not form a range
   from a possibly-null `script` pointer; use an empty `CScript`.
4. Keep the `equiv_entry` result/error mapping unchanged (result 0/1/2/3 and
   `error_kind`).

This is a source-level requirement only; it does not change the ABI. It is
recorded as a handoff in `findings/core/handoff-contract-pcore02.md`.

### Differential test plan

Same as P-CORE-01, plus a checker-focused lane:

- Corpus: all 90 `checksig` and 117 `cms` selections.
- Construct transactions with valid ECDSA (legacy and witness-v0), Schnorr
  key-path/script-path, `CHECKLOCKTIMEVERIFY`, and `CHECKSEQUENCEVERIFY`
  cases; both passing and failing signatures.
- Compare the hook-forwarded build against the unpatched virtual-dispatch
  build on `(result, error_kind)`.
- Negative control: make one hook return the opposite bool; the checksig
  corpus must diverge, proving the hooks are live.
- Fuzz lane: random 64-bit `nLockTime`/`nSequence` values around type
  boundaries and random DER/Schnorr encodings, including empty signatures.

---

## P-CORE-03 — hoist `EvalScript` statics

### Diff

`P-CORE-03-hoist-evalscript-statics.patch` (2 hunks).

- Adds namespace-scope `static const CScriptNum bnZero/bnOne` and
  `static const valtype vchFalse/vchTrue` immediately before `EvalScript`.
- Wraps the original function-local definitions at `:423-426` in
  `#ifndef BTC_EQUIV_HOIST_STATICS`.

### Behavior-preservation argument

The four objects are immutable after construction and have the same values
(`0`, `1`, empty vector, `{1}`). Reads are identical. The only observable
difference is initialization timing and failure mode: a `std::bad_alloc`
during global initialization terminates before `main`, whereas the original
first-call initialization would propagate through `EvalScript`'s caller.
This is a domain restriction; it is acceptable only if the differential lane
shows no allocation failure at startup and the cell trust note records it.

### Differential test plan

Same corpus/fuzz as P-CORE-01. Add a startup-order test: run the patched
binary under a constrained allocator/`LD_PRELOAD` failure injection for the
first N allocations and confirm the reference and patched builds both fail
at the boundary (or record the divergence as a domain restriction). Do not
claim behavior preservation on the allocation-failure path.

---

## P-CORE-04 — split `EvalScript` (design only)

**Why.** At O0 the `EvalScript` body is 4,570 IR instructions, 339 `invoke`s
in the patched build before exception erasure, 25 landing pads, and one
unbounded dispatch loop (`interpreter.cpp:449-1234`). Alive2 cannot prove a
loop without unrolling; SAW needs invariants over the whole stack machine. A
step function gives both tools a bounded unit.

**Design.** Introduce a `ScriptEvalState` holding the references/values the
loop mutates (`stack`, `altstack`, `vfExec`, `execdata`, `nOpCount`,
`opcode_pos`, `pbegincodehash`, `pc`, `pend`, `fRequireMinimal`, `sigversion`,
`flags`, `checker`, `serror`). Extract the body of the `for` into
`static bool EvalStep(ScriptEvalState&)`: return `false` only for the paths
that currently `return set_error(...)`, return `true` after the size-limit
check. The loop becomes:

```
while (s.pc < s.pend) {
    if (!EvalStep(s)) return false;
    ++s.opcode_pos;
}
```

The switch stays in `EvalStep` initially, preserving order and fallthrough.
Only after that mechanical extraction is proven equivalent should the switch
be split into family helpers (flow `:613-686`, stack `:687-928`, numeric
`:929-1031`, hash `:1032-1068`, checksig `:1069-1114`, multisig
`:1115-1229`, locktime/sequence `:553-612`).

**Behavior-preservation argument.** The extraction does not change any
predicate, error code, or evaluation order; `return`/`break` semantics are
preserved by returning `false` only from the old error returns and keeping
the `switch` intact. The loop increment moves from the `for` header to the
bottom of the while body, after the size check, which is the same order.

**Differential test plan.** Full corpus/fuzz as above, plus an IR-level
check: compare `EvalStep` calls for a fixed bounded trace against the
unpatched loop on the same inputs; assert identical stack/altstack/error
after each step. Upstream status: **not upstreamable as-is**; flag as a
lane refactor unless Core maintainers accept the mechanical split.

---

## P-CORE-05 — span leaf overloads (design only)

**Why.** At O1, `CastToBool` contains 2 `ptrtoint`s (and the vector
helpers around it add more); `ptrtoint` is an Alive2 hard block and a SAW
memory-model complication. A separate `leaf.cpp` experiment with identical
logic over `std::span<const unsigned char>` produced **0**
`ptrtoint`/`inttoptr` at both O0 and O1, while the `std::vector` version
produced 2 `ptrtoint` at O1.

**Design.** In `src/script/interpreter.cpp:46-61`, add:

```cpp
static bool CastToBoolSpan(std::span<const unsigned char> vch);
bool CastToBool(const valtype& vch) { return CastToBoolSpan(vch); }
```

and route the engine's seven internal calls (`:638`, `:669`, `:782`,
`:1004`, `:1878`, `:2039`, `:2085`) to `CastToBoolSpan`. The body is the
same indexed loop and the same negative-zero rule. Optionally do the same
for `CheckMinimalPush` (`src/script/script.cpp:373`, declaration
`src/script/script.h:607`) with a span overload that the vector form
forwards to.

**Behavior-preservation argument.** `std::span` construction from
`std::vector` reads the same `data()`/`size()` pair; the loop and predicates
are byte-for-byte the same. No ownership or lifetime change: the span does
not outlive the vector at any call site.

**Differential test plan.** Full corpus/fuzz; additionally compare the
extracted leaf functions with Alive2 (`--always-verify`) and SAW on
symbolic byte arrays, including empty input, all-zero input, `0x80`
negative zero, and multi-byte values. Upstream status: upstreamable in
principle as a readability/IR-cleanup patch.

---

## Reproduction of the patch artifacts

The patched artifact was reproduced from a **fresh clone** of the pin. The
three patches applied in order, the three modified files matched the
prototype tree byte-for-byte, and recompiling at O0 with the three macros
produced the identical bitcode hash:

```
5993460463314028bf1225784bbbcaa28dab7ab6fec979a17907a369cba302c7  interpreter-O0-patched.bc
```

Exact commands and hashes: `findings/core/commands.md` and
`findings/core/hashes.txt`.

## What this registry does **not** claim

- No patch is behavior-preserving yet; differential evidence is absent.
- No patch changes consensus behavior by design, but P-CORE-01/03 have
  documented out-of-domain exception/allocation differences.
- The patched bitcode hash is a reproducibility pin, not a proof of
  equivalence to the unpatched bitcode.
- The `-fno-exceptions` source flag is **not** used and is not viable:
  compiling Core with it emitted 20 errors before the compiler's error limit,
  across `util/check.h`, `serialize.h`, `util/string.h`,
  `util/strencodings.h`, and `uint256.h` (see
  `findings/core/logs/fno-exceptions.log`).
