# Wave 16B / `02-e5-getscriptop` — B1 structural unblocker report

**Task:** attack E5 blocker **B1** — undefined `GetScriptOp` /
`CScript::GetOp` in the single-TU `interpreter.cpp` module — by
building/linking the real `script.cpp` parser bitcode and attempting real SAW
execution/proofs for non-empty scripts, or by producing a verified
`GetScriptOp` spec/override with exact parser semantics.

**Branch:** `wave16b/02-e5-getscriptop`, cut from PR #29 head `805c804`.
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (v32.99).
**IR lane:** pinned single-TU `interpreter-O0.bc`
`f5718af79c56ccfd5a5437a313d957573cb87c0de0cdf5641013991268801b2c`
(`PINS.lock [core.ir]`), clang/LLVM 20.1.2, `-O0 -g0`.
**Tools:** SAW 1.6 (`68eed5f`, release-1.6); `/usr/bin/clang++-20` 20.1.2.
**Deliverable type:** working prototype (with an explicit soundness/refinement
obligation), plus a precise next blocker. **Not** a green cell, **not** a Lean
theorem, **not** a ledger row.

---

## 1. Bottom line

**B1 is removed for the SAW-executable path, and the first non-empty-script
`VerifyScript` proofs in this lane now exist.**

- The real `src/script/script.cpp` parser TU was compiled at the pin
  (`script-O0.bc`, sha256 `657530a8...`, byte-identical to the E5 residual's
  artifact) and linked into the **pinned** interpreter module.
- `GetScriptOp` is now a defined function in the probe module, and SAW
  executes/proves it: concretely for `OP_1`, and symbolically for **all 256
  one-byte scripts** and for **all non-push opcodes with a 4-byte window**.
- `VerifyScript` is **proved** (return value *and* the error cell) for three
  real non-empty scripts on the linked probe: `OP_NOP` (1 byte),
  `OP_NOP OP_NOP` (2 bytes, two parser iterations), and `OP_RETURN`.
- A verified `GetScriptOp` summary is also consumed **compositionally** as an
  override inside a `VerifyScript` proof (`Applied override!` in the log).
- The matched *before* run on the pinned patched `roots.bc` (no parser) still
  fails with the exact B1 error; the *after* run on the linked probe for the
  same stack-effect input (`OP_1`) now fails at **B2 `_Znwm`** instead — the
  parser is no longer the stop.
- **No `llvm_unsafe_assume_spec`** is used anywhere. Negative controls
  (deliberately wrong postconditions) fail as required, so the obligations are
  non-vacuous.

What is still **not** proved: a symbolic whole-function `VerifyScript`
contract. Every `VerifyScript` result here is a singleton concrete input, and
every stack-effect opcode still stops at the heap allocator (B2). This report
does not promote any row.

---

## 2. What advanced (setup / execution / proof)

### Setup

- New pinned-lane module: `interp-script-roots3.bc`
  (`2795c02e...`), built from `ir20/interpreter-O0.bc` (`f5718af7...`, the
  **pin**) + `script-O0.bc` (`657530a8...`). The existing E5 "linked3" probe
  used the non-pin `/tmp/opencode/equiv-work/ir/interpreter-O0.bc`
  (`b8f17c1f...`); this prototype is derived from the pinned bitcode.
- `GetScriptOp` is defined in the final module
  (`T _Z11GetScriptOp...` in `llvm-nm`); `_Znwm`, SHA/RIPEMD, `memcmp`,
  `CheckMinimalPush`, the four checker hooks and `__assert_fail` stay
  undefined, as intended (real library calls, no stubs).
- Unpatched linked module `interp-script-O0.bc` (`f52f6a9d...`) was also built
  and tested: SAW loads it, but `llvm_verify` still rejects it at setup on the
  undefined C++ ABI global `_ZTVN10__cxxabiv120__si_class_type_infoE` (B4).
  **B1 cannot be isolated on the unpatched lane with SAW 1.6.**

### Execution

- SAW executed the real `GetScriptOp` body through:
  - the direct parser calls (concrete + symbolic),
  - `CScript::GetOp` inside `EvalScript`, inside `VerifyScript`, on the linked
    probe,
  - two consecutive dispatch-loop iterations (`OP_NOP OP_NOP`).
- The parser's `pvchRet->clear()` and the non-push branch (no `assign`) are
  heap-free and execute fully.
- Push opcodes enter `std::vector::assign`; there the run stops at `_Znwm`
  (B2) when the vector is empty, or at `llvm.is.constant.i32` (SAW gap, §6)
  when capacity is preallocated.

### Proof

- `Proof succeeded!` for:
  - `GetScriptOp` OP_1 concrete (parser TU),
  - `GetScriptOp` symbolic over all 256 one-byte scripts (parser TU),
  - `GetScriptOp` symbolic over `b0 >= 79`, 4-byte window (parser TU),
  - `GetScriptOp` OP_NOP lemma in the exact 40-byte CScript state
    (linked probe),
  - `VerifyScript(OP_NOP)` = `false`, `SCRIPT_ERR_EVAL_FALSE` (2)
    (linked probe, **no override**),
  - `VerifyScript(OP_NOP OP_NOP)` = `false`, error 2 (linked probe, no
    override),
  - `VerifyScript(OP_RETURN)` = `false`, `SCRIPT_ERR_OP_RETURN` (3)
    (linked probe, no override),
  - `VerifyScript(OP_NOP)` using the proved `GetScriptOp` spec as an override
    (linked probe).
- Negative controls (wrong opcode, wrong error) both end in `Proof failed.`

The `VerifyScript` specs assert **both** the `i1` return and the 8-byte
`ScriptError_t` cell, which is stronger than the earlier E5 empty-script
result (return only).

---

## 3. Evidence (exact commands, outcomes)

All commands run from the prototype directory:

```sh
cd spec/equiv/cells/e5-whole/PROTO-w16b-getscriptop
./builder/build-pinned-linked.sh      # -> logs/build-pinned-linked.raw.log
./run-all.sh                        # -> logs/*.raw.log + logs/RUN-EXIT-CODES.txt
for f in neg/*.saw; do /opt/equiv-tools/saw-1.6/bin/saw "$f"; done
```

| Run | Spec | Module | Outcome |
|---|---|---|---|
| 1 | `saw/e5b-gso-op1-concrete.saw` | `script-O0.bc` | **Proof succeeded** |
| 2 | `saw/e5b-gso-symbolic-1byte.saw` | `script-O0.bc` | **Proof succeeded** (all 256) |
| 3 | `saw/e5b-gso-symbolic-nonpush-4byte.saw` | `script-O0.bc` | **Proof succeeded** (`b0 >= 79`) |
| 4 | `saw/e5b-gso-nop-in-linked3pin.saw` | linked probe | **Proof succeeded** |
| 5 | `saw/e5b-verifyscript-nop-linked3pin.saw` | linked probe | **Proof succeeded** |
| 6 | `saw/e5b-verifyscript-nop2-linked3pin.saw` | linked probe | **Proof succeeded** |
| 7 | `saw/e5b-verifyscript-opreturn-linked3pin.saw` | linked probe | **Proof succeeded** |
| 8 | `saw/e5b-verifyscript-nop-with-gso-override.saw` | linked probe | **Proof succeeded**, `Applied override!` |
| 9 | `saw/e5b-verifyscript-op1-linked3pin.saw` | linked probe | **stops at `_Znwm`** (B2) |
| 10 | `saw/e5b-verifyscript-op1-patchedroots.saw` | `ir20-proto/roots.bc` | **stops at `GetScriptOp`** (B1, before) |
| 11 | `saw/e5b-verifyscript-op1-rawlinked.saw` | linked, unpatched | **setup fails** on ABI global (B4) |
| 12 | `saw/e5b-gso-push2-empty.saw` | `script-O0.bc` | **stops at `_Znwm`** (B2) |
| 13 | `saw/e5b-gso-push2-capacity.saw` | `script-O0.bc` | **stops at `llvm.is.constant.i32`** (SAW gap) |
| 14 | `neg/e5b-neg-gso-op1-wrong-opcode.saw` | `script-O0.bc` | **Proof failed** (control) |
| 15 | `neg/e5b-neg-nop-wrong-error.saw` | linked probe | **Proof failed** (control) |

Raw logs, including the SAW version line and exit code, are in
`cells/e5-whole/PROTO-w16b-getscriptop/logs/`; hashes in `SHA256SUMS`.

---

## 4. Exact errors (verbatim, from the raw logs)

### Before (B1, no parser): `e5b-verifyscript-op1-patchedroots.raw.log`

```
internal: error: in _ZNK7CScript5GetOpERN9prevectorILj36EhjiE14const_iteratorER10opcodetypeRSt6vectorIhSaIhEE
  Failed to load function handle: _Z11GetScriptOpRN9prevectorILj36EhjiE14const_iteratorES1_R10opcodetypePSt6vectorIhSaIhEE
  Details:
    No implementation or override found for pointer
```

### After (B1 removed, B2 next): `e5b-verifyscript-op1-linked3pin.raw.log`

```
internal: error: in _ZNSt15__new_allocatorIhE8allocateEmPKv
  Failed to load function handle: _Znwm
  Details:
    No implementation or override found for pointer
```

The allocation is `CScriptNum::getvch()` returning a `std::vector<unsigned
char>` for `stack.push_back(bn.getvch())` (OP_1 case), i.e. B2, not B1.

### Unpatched linked module (B4): `e5b-verifyscript-op1-rawlinked.raw.log`

```
Global was not a compile-time constant:Symbol "_ZTVN10__cxxabiv120__si_class_type_infoE"
```

### Parser push path, preallocated capacity: `e5b-gso-push2-capacity.raw.log`

```
internal: error: in _ZSt9__advanceIN9prevectorILj36EhjiE14const_iteratorEiEvRT_T0_St26random_access_iterator_tag
  Failed to load function handle: llvm.is.constant.i32
  Details:
    No implementation or override found for pointer
```

### Parser push path, empty vector: `e5b-gso-push2-empty.raw.log`

```
internal: error: in _ZNSt15__new_allocatorIhE8allocateEmPKv
  Failed to load function handle: _Znwm
```

---

## 5. Module hashes

| Artifact | SHA-256 |
|---|---|
| pinned `interpreter-O0.bc` (input, `PINS.lock [core.ir]`) | `f5718af79c56ccfd5a5437a313d957573cb87c0de0cdf5641013991268801b2c` |
| `script-O0.bc` (real `script.cpp`, clang++-20 `-O0 -g0`) | `657530a8d18741b40e09653a681c5d11438ed453bcccf8bde14f0b2037a6d51c` |
| `interp-script-O0.bc` (unpatched linked) | `f52f6a9d26ea176fa6b1c4de1cf8b12dea626320d51762574de8f0bae9c998aa` |
| `interp-script-O0-noexc-s.bc` (erased + simplifycfg) | `03714b5fb4e5962fcd82903c6400f16d79840273bdc48c1374f85b6d38fa738c` |
| `interp-script-roots.bc` (internalized) | `47a83dc561717df93322262e2dfb14e2fce6ae05e7540656c42e9333039004e9` |
| `interp-script-roots3.bc` (probe used by the proofs) | `2795c02ea67c77ff3674d16da074b1f8b884861fc6f157b6274feba9d8227ae1` |
| `ir20-proto/roots.bc` (patched, compared) | `2b9f683c4fdd3550e4eab43083a4c528ce785d37956f0f24b75311ec756f04a8` |

`script-O0.bc` is byte-identical to the artifact recorded in
`findings/e5/E5-RESIDUAL.md` §4, so this is the same parser TU.

Build transforms (assumptions, per `logs/build-pinned-linked.raw.log`):
825 `invoke`s converted to `call`s, 343 landingpad blocks neutralised,
3 `__cxa_guard` variables pinned to 1.

---

## 6. New observation: SAW 1.6 lacks `llvm.is.constant.i32`

The parser's push path calls `std::vector<unsigned char>::assign`, whose
libstdc++ implementation reaches `std::__advance`, which clang lowers with
`llvm.is.constant.i32` (`__builtin_is_constant_evaluated()` guards). SAW 1.6
has no model for that intrinsic and aborts even when the output vector has
enough capacity for the push.

This is independent of B2 and blocks a precise push-path parser proof. In
this specific `__advance` body the guarded constant branches are behaviourally
identical to the fallback (`++`/`--` vs `+= 1`/`+= -1`), so an LLVM pass that
lowers `llvm.is.constant.*` to `false` would be a *candidate* proposal — but it
would need a per-intrinsic refinement argument and is **not** claimed here.
The empty-vector shape (what `EvalScript` actually uses) hits B2 first, so this
gap is not on the currently-blocking path.

---

## 7. Soundness / refinement obligations (do not overclaim)

1. **Singleton inputs.** All `VerifyScript` proofs use fully concrete
   `scriptSig`/`scriptPubKey`/flags/witness/checker bytes. They establish
   Core's result for those exact inputs only.
2. **Bounded parser lemmas.** The symbolic `GetScriptOp` results are for a
   1-byte window (all bytes) and a 4-byte window with `b0 > OP_PUSHDATA4`.
   They are not a whole-parser contract and do not cover pushes.
3. **Module transforms are assumptions**, not Core properties: exception
   erasure is domain-restricting (`findings/core/findings-ledger.md`, F-TOOL-006), the three ABI
   globals are stubbed, and the one-time static initialisation is assumed
   complete (`__cxa_guard = 1`). The unpatched lane cannot be verified by SAW
   1.6 at all (B4).
4. **ABI layout assumptions** are stated, not proved: `prevector<36,u8,u32>`
   layout (36-byte inline storage + 4-byte size), `const_iterator` = one
   pointer, by-value iterator passed as its pointer field, libstdc++
   `std::vector` = 3 pointers.
5. **No overrides** in the direct proofs; the one override proof first proves
   its own `GetScriptOp` summary. No `llvm_unsafe_assume_spec` anywhere.
6. **Not a ledger cell.** Nothing here is registered in
   `spec/db/equiv-cells.yaml`, and the prototype README repeats this.

---

## 8. Recommended next step

1. **B2 heap model** (the new first stop for every stack-effect opcode):
   verified specs/overrides for `_Znwm`/`_ZdlPv`/`malloc`/`free`/`realloc`
   including allocation failure, or a `std::vector`/stack abstraction with a
   proved refinement. Until that exists, `OP_1`-class scripts cannot be
   proved.
2. **B3 loop invariant** after B2, reusing the parser lemmas here at the
   `%336`-style header.
3. Optional tooling proposal: a sound lowering/model for
   `llvm.is.constant.i32` so the parser push path can be proved with
   preallocated capacity (needed if the B2 model abstracts allocation rather
   than modelling `operator new`).
4. Discharge the erasure/guard policies (B4/B5) before any of this is cited
   by a green cell.

---

## 9. Files

- `cells/e5-whole/PROTO-w16b-getscriptop/` — prototype cell: specs, build
  script, raw logs, `SHA256SUMS`, `run-all.sh`, negative controls.
- `findings/wave16b/02-e5-getscriptop/README.md` — this report.
- `findings/wave16b/02-e5-getscriptop/commands.md` — copy-paste commands.
- `findings/wave16b/02-e5-getscriptop/hashes.txt` — module/log hashes.
