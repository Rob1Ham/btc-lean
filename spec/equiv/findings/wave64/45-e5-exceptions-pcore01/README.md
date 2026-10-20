# wave64 / 45-e5-exceptions-pcore01 — P-CORE-01 amendment re-audit

**Status: advisory prototype. P-CORE-01 remains PROPOSED. Not promoted, not a
green cell, not a proof.** This directory re-audits the P-CORE-01 prototype and
the E5 exception model, and validates the amendment proposal that keeps both
`catch` blocks and reverts the `popstack` assert.

- Base repo commit: `5946c02`
- Bitcoin Core pin: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (v32.99)
- Toolchain: clang/LLVM `20.1.2`, SAW `1.6 (68eed5f)`, Alive2 `v20.0 (c0f5434)`
- Inputs (P-CORE-01 as committed): `P-CORE-01-scriptnum-error-returns.patch`,
  sha256 `107ef2ede2816d58793ab1ad5ad2293b7a1f25e54ce1bac16f73bcae94e0c3ea`
- Amendment proposal: `P-CORE-01-amendment.proposal.patch`, sha256
  `9aee2de3890e1a616fcb2336c4a3337954efb4d5ac7cfc667783252f1619136e`
- Apply-form amendment (comment header stripped): `P-CORE-01-amendment.patch`,
  sha256 `cc48da52cf14af7542d9c7e207022f84f9c8110ff9f5da204e2f96e8f39ea4a8`

---

## 1. Verdict

1. **The two defects are removed.** The amended source restores the `try`, both
   `catch` blocks (`scriptnum_error` and `...`) and the `popstack` throw
   byte-for-byte (comments stripped) to upstream. The scriptnum lowering is the
   only semantic change.
2. **It compiles at the pin** with the exact registry command. The bitcode hash
   is `4583a46dd76bfe2ed2b63393c071a21a53986e7e38c873c9b11b8163d358af5b`,
   reproducing the prior amendment artifact exactly; the linked `m3a.bc` hash
   is `78b1b47f2d03fed464480acd7e006310857997d5963116858730f45ad88f1ad5`.
   No new warnings vs upstream, and without the macro the IR is identical to
   upstream modulo `__assert_fail` source line numbers.
3. **No behavioral divergence was found** on the tested domain: 1,258/1,258
   `script_tests.json` rows, 1,000,000/1,000,000 generated cases, 11 directed
   call-site cases, and 11,700,356 `from_vch`/constructor predicate checks.
   The injected external-throw and `bad_alloc` tests show the amendment restores
   Core's `catch(...)` result, while P-CORE-01 as written propagates both.
4. **Bounded cell use: yes for a concrete EvalScript scriptnum path; not yet for
   a VerifyScript path that exercises it.** SAW proves the amended `EvalScript`
   case (`5`-byte stack operand, `OP_1ADD` -> `false`,
   `SCRIPT_ERR_SCRIPTNUM`) and the empty `VerifyScript` case. A `VerifyScript`
   case that pushes a numeric operand stops at `_Znwm` (B2 heap), and Alive2
   still refuses the amended module on `invoke` (and on the atomic guard load
   for `EvalScript`). Keeping the catches is exactly what gives back the
   catch-all semantics and exactly what re-exposes the exception edges.
5. **Do not promote P-CORE-01, amended or not.** The evidence is differential
   and bounded, not a refinement proof. The remaining blockers are in §6.

---

## 2. Exact diffs

All diffs are in `diffs/`.

| Diff | Size | Content |
|---|---:|---|
| `upstream-vs-amended-interpreter.diff` | 12 hunks, 185 lines | the amended patch against the pin |
| `upstream-vs-amended-script-h.diff` | 1 hunk, 30 lines | only `from_vch` + default constructor |
| `upstream-vs-p1-interpreter.diff` | 14 hunks, 203 lines | P-CORE-01 as committed, for comparison |
| `p1-vs-amended-interpreter.diff` | 3 hunks, 51 lines | the amendment itself |
| `upstream-vs-p1-script-h.diff` | 1 hunk, 30 lines | identical to the amended header |

The amendment delta (`p1-vs-amended-interpreter.diff`) is exactly:

1. `popstack` — the `#ifdef BTC_EQUIV_NO_SCRIPTNUM_THROW`/`assert(!stack.empty())`
   branch is deleted; the original `throw std::runtime_error("popstack(): stack
   empty")` remains, with a comment. Comments stripped, this region is
   token-identical to upstream.
2. `EvalScript` — the `#ifndef` around `try` is deleted; `try` is unconditional.
3. End of `EvalScript` — the `#ifndef` around `catch (const scriptnum_error&)` /
   `catch (...)` is deleted; both catches are unconditional, with comments.
   Comments stripped, the two catch blocks are token-identical to upstream.

Mechanical checks:

- `assert(!stack.empty())` is **absent** from the amended tree and present
  exactly once in the P-CORE-01 tree (the defect).
- Preprocessed amended `EvalScript` with `-DBTC_EQUIV_NO_SCRIPTNUM_THROW`:
  **12** `GetScriptNum(...)` sites, **0** remaining
  `CScriptNum(stacktop.../vch...)` constructions, **2** catches, `try` present.
- P-CORE-01 (as written) preprocessed: 12 sites, 0 constructions, **0**
  catches, no `try`, and the popstack assert.
- Without `-DBTC_EQUIV_NO_SCRIPTNUM_THROW`, amended IR equals upstream IR after
  normalizing only the `__assert_fail` line-number operands (the patch shifts
  source lines). This is the lane-only no-op check.

---

## 3. Compile results

Exact build of `src/script/interpreter.cpp` from the amended tree root:

```sh
cd <amended-core>
/usr/bin/clang++-20 -O0 -g0 -std=c++20 -fexceptions \
  -DBTC_EQUIV_NO_SCRIPTNUM_THROW -emit-llvm -c \
  src/script/interpreter.cpp -I src -o interp-p1amend.bc
sha256sum interp-p1amend.bc
# 4583a46dd76bfe2ed2b63393c071a21a53986e7e38c873c9b11b8163d358af5b
```

- Upstream pin bitcode from the same tree: `f5718af79c56ccfd5a5437a313d957573cb87c0de0cdf5641013991268801b2c`
  (matches `PINS.lock`).
- P-CORE-01 as written: `2c23631fbe4970de8dd44a7ca05033c4781eb73b85098532db26e1e5fa749a41`
  (matches the prior artifact).
- Amended: `4583a46dd76bfe2ed2b63393c071a21a53986e7e38c873c9b11b8163d358af5b`
  (matches the prior artifact).
- Full C-leg shared libraries (baseline/P-CORE-01/amended) build with the
  registry's Core file set and shim; hashes are in `hashes.txt`.
- `-Wall -Wextra -fsyntax-only`: 44 warnings for upstream, 44 for P-CORE-01,
  44 for amended; the warning sets are identical. No new diagnostics.
- Composition: applying P-CORE-01, P-CORE-02, P-CORE-03 (in registry order) and
  then the amendment succeeds (`patch -p1`, offsets 12–21 lines) and compiles
  with all three macros
  (`ea878eae7cbf7d542b62821650f67aeea71b3edf1fd7133146dc673a44b573db`).
  The amendment does not conflict with P-CORE-03's statics hoist.
- **Fresh-tree check:** a clean copy of the pin was patched with only the two
  committed artifacts (the registry P-CORE-01 patch and
  `P-CORE-01-amendment.patch`, `patch -p1` from the Core tree root) and compiled
  with the command above. It reproduces `4583a46d…` exactly, so the amendment is
  reproducible from committed files alone, with no scratch-tree state.

---

## 4. Behavior differential

### 4.1 Predicate equivalence (`from_vch`)

`predcheck.cpp` (compiled against the amended header, `-DBTC_EQUIV_NO_SCRIPTNUM_THROW`)
compares the real throwing `CScriptNum(vector)` constructor with the real
`from_vch` over sizes 0–8, sign/minimality edge bytes, exhaustive small
vectors, and 2,000,000 pseudorandom vectors:

```
checks=11700356 failures=0
```

This is a bounded machine check, not a proof; the predicates are syntactically
the same condition in both functions.

### 4.2 Corpus and fuzz

| Lane | Cases | Divergent | Evidence |
|---|---:|---:|---|
| `script_tests.json` vs baseline | 1,258 | **0** | `results/corpus/summary.json` |
| deterministic fuzz (seed `0x16b10`) | 1,000,000 | **0** | `results/fuzz/summary.json` |

Both P-CORE-01 as written and the amendment are compared against the same
unpatched `libequiv-core-baseline.so`. The fuzz histogram contains 359,377
`SCRIPTNUM` cases, so the scriptnum branch is heavily exercised. Neither result
covers OOM or a throwing external; those are the directed tests below.

### 4.3 Directed per-site cases

`harness/sites_driver.cpp` reaches 11 of the 12 `GetScriptNum` sites from
`VerifyScript` in BASE. Baseline, P-CORE-01 and amended agree on every row
(`results/results-sites.txt`):

- CLTV 6-byte, CSV 6-byte, ROLL 5-byte, unary 5-byte, binary operand 1 and 2,
  WITHIN operand 1/2/3: all `false`, `SCRIPT_ERR_SCRIPTNUM=4`.
- CHECKMULTISIG `nKeysCount` and `nSigsCount` 5-byte: `false`, `4`.
- `OP_CHECKSIGADD` in BASE: `false`, `SCRIPT_ERR_BAD_OPCODE=16` (the numeric
  argument is not read in BASE).
- 4-byte/1-byte controls: `true`, `SCRIPT_ERR_OK=0`.

**Not covered:** the 12th site, `OP_CHECKSIGADD` (:1103), is Tapscript-only.
Reaching it needs a witness-v1 Tapscript execution with `sigversion == TAPSCRIPT`;
it is not in `script_tests.json` (0 occurrences of `CHECKSIGADD`), and the fuzz
lane is witness-free. The amended and P-CORE-01 source at that site is the same
`GetScriptNum` form as the other 11, but it is **source-verified only**.

### 4.4 The two prior defects, reproduced and fixed

`harness/throw_oom_driver.cpp` calls the real `VerifyScript` directly three
times per library:

- `throw_test`: a `BaseSignatureChecker` whose `CheckECDSASignature` throws
  `std::runtime_error` (a throwing external inside `EvalScript`'s `try`).
- `oom_test`: a global `operator new` armed to throw `std::bad_alloc` on the
  first allocation (the `OP_1` stack push).

| Test | baseline (upstream) | P-CORE-01 as written | amended |
|---|---|---|---|
| external throw | `false`, `SCRIPT_ERR_UNKNOWN_ERROR` | **exception propagates** out of `VerifyScript` | `false`, `SCRIPT_ERR_UNKNOWN_ERROR` |
| `bad_alloc` | `false`, `SCRIPT_ERR_UNKNOWN_ERROR` | **`bad_alloc` propagates** | `false`, `SCRIPT_ERR_UNKNOWN_ERROR` |

Exact output: `results/results-throw-oom.txt`.

Important subtlety: `VerifyScript` sets `SCRIPT_ERR_UNKNOWN_ERROR` at entry, so
the error cell reads `1` in both the caught and propagated cases. The observable
difference is the **propagation** (uncaught in Core's validation path =>
`std::terminate`/DoS vs a script failure), which is why the driver reports
`PROPAGATED` separately. This also means a differential that compares only
`(result, error_kind)` on OOM/throw is blind to the P-CORE-01 defect.

---

## 5. Bounded E5 cell

### 5.1 Module

The amended interpreter was linked with the pinned `script.cpp` and the probe
guard stubs, ABI globals resolved by `defglob.py`, and the statics given the
declared explicit treatment by `mkm.py patched-explicit`:

```
m3a.bc  78b1b47f2d03fed464480acd7e006310857997d5963116858730f45ad88f1ad5
```

This reproduces the prior amendment module exactly from an independent rebuild.

### 5.2 SAW results

| Spec | Claim | Result |
|---|---|---|
| `spec-b4-throw-pcore01-amend.saw` | `EvalScript(OP_1ADD, 5-byte operand)` -> `false`, `SCRIPT_ERR_SCRIPTNUM` | **Proof succeeded** (`results/saw/log-b4-throw-amend.txt`) |
| `spec-vs-empty-m3a.saw` | `VerifyScript(empty, empty)` -> `false`, `SCRIPT_ERR_EVAL_FALSE` | **Proof succeeded** (`results/saw/log-vs-empty-m3a.txt`) |
| `spec-vs-scriptnum-m3a.saw` | `VerifyScript(PUSH5, OP_1ADD)` -> `false`, `SCRIPT_ERR_SCRIPTNUM` | **Blocked**: `Failed to load function handle: _Znwm` (`results/saw/log-vs-scriptnum-m3a.txt`) |

The first result is a genuine bounded cell for the amended lowering: the stack
is pre-populated by the spec, so no allocation is needed. The third result is
the precise blocker for a `VerifyScript`-level scriptnum cell: the script's
first push allocates the outer stack, and B2 has no allocator model.

### 5.3 Alive2

| Module/function | Result |
|---|---|
| amended `VerifyScript` | `ERROR: Unsupported instruction: ... invoke ...`; cannot translate (`results/alive2/alive2-amend-vs.txt`) |
| amended `EvalScript` | `ERROR: Unsupported instruction: ... load atomic ... __cxa_guard ...` (`results/alive2/alive2-amend-es.txt`) |
| erased amended `VerifyScript` | `Transformation seems to be correct! (syntactically equal)` — **not a proof**; erasure is domain-restricting |

IR counts for `EvalScript` / `VerifyScript` (line-based function boundaries):

| Module | EvalScript invokes / landingpads | VerifyScript invokes / landingpads |
|---|---|---|
| upstream | 336 / 32 | 58 / 6 |
| P-CORE-01 as written | 342 / 28 | 58 / 6 |
| amended | 348 / 32 | 58 / 6 |

Keeping the catches restores the function-level exception edges (32 landing
pads, matching upstream) and the `scriptnum_error` typeinfo references
(26, matching upstream; P-CORE-01 as written has 0). That is the trade: source
behavior preservation vs the no-catch IR property the old patch was using for
Alive2. **The amendment does not unblock Alive2 by itself.**

### 5.4 Cell caveats

- The SAW module is a **stubbed/erased** artifact: `defglob.py` replaces RTTI,
  exception typeinfo and vtable globals with internal constants, and the guard
  protocol is the probe stub. With catches restored, those stubs are *less*
  faithful to a throwing execution, not more. SAW 1.6 does not unwind
  `invoke`/`landingpad` anyway (prior audit, `wave16b/04-e5-exceptions` §1.1).
  Every SAW result here is therefore on the no-throw domain and must carry that
  statement.
- The `vchTrue` value in `m3a` is the stated read-only `{0x01}` assumption
  (`mkm.py patched-explicit`), not the real heap initializer. It is not read on
  the proved scriptnum path, but it is part of the module's trust note.
- The empty `VerifyScript` proof does not exercise the P-CORE-01 change; it only
  shows the amended module still loads and executes the scoped path.
- No `llvm_unsafe_assume_spec` is used.

---

## 6. E5 exception model, re-audited

The prior model (`wave16b/04-e5-exceptions`) states a no-throw domain `D`:
(a) no `scriptnum_error`, (b) no allocation failure, (c) non-throwing linked
externals/checker, (d) no assert fires. Re-audit:

- **(a) is discharged at the source** by the amended patch: all 12 throwing
  constructor sites in `EvalScript` are lowered to `GetScriptNum`; the
  `catch(scriptnum_error)` that remains is a safety net and is dead. Verified
  by preprocessed census and directed tests (11/12 empirical, 12/12 source).
- **(b), (c) are *preserved in behavior*** by the restored `catch(...)`: both
  upstream and amended return `SCRIPT_ERR_UNKNOWN_ERROR` for `bad_alloc` and a
  throwing external. They are still **not modeled** by SAW/Alive2; a cell still
  assumes them away.
- **(d)** is unchanged. The `popstack` throw is restored, so the empty-stack
  audit (78/78 sites) is no longer load-bearing for *behavior preservation*:
  if the audit were wrong, upstream and amended would both catch the throw and
  return `SCRIPT_ERR_UNKNOWN_ERROR`. The audit remains load-bearing for the
  no-throw cell domain (SAW would fail closed on the throw).
- **Error precedence:** the lowered sites set the error and return at the same
  program point where the old throw unwound to the catch; the post-loop
  unbalanced-conditional check is skipped in both. The corpus/fuzz equality
  covers precedence on the tested domain.
- **Parser/exception safety:** no live non-trivial local is destroyed
  differently at the 12 sites (the objects in scope are `CScriptNum`, integers
  and references). The `const` removal on `nLockTime`/`nSequence`/`num` has no
  observable effect.

**Verdict on the model:** the amended patch is the correct source-level handle
for restriction (a) and it removes the prior `catch(...)` defect. It does not
turn the E5 IR lane into an exception-preserving lane. Erasure or a no-throw
domain statement is still required, and B2/B3/B5 still own the remaining cells.

---

## 7. Blockers and non-claims

Open blockers after this re-audit:

1. **No proof.** All results are bounded checks/differentials; no Lean theorem
   and no LLVM refinement proof.
2. **Site 12 (`OP_CHECKSIGADD`) is not empirically exercised** (Tapscript-only;
   absent from the corpus and witness-free fuzz). Source-identical lowering only.
3. **B2 heap** blocks any `VerifyScript` path that pushes a value; the
   `VerifyScript` scriptnum spec stops at `_Znwm`.
4. **SAW 1.6 does not model unwinding**; the amended module's restored catches
   are not executed in a proof, and the defglob RTTI stubs would not model them
   faithfully if reached.
5. **Alive2 still refuses `invoke`** (and the `EvalScript` atomic guard load);
   the erased form is "syntactically equal", not a proof.
6. **B3 loop invariant / B5 guard recipe** remain as in the prior residual.
7. **No OOM model.** The `bad_alloc` test proves the catch is live for one
   injected allocation failure; it is not an allocator refinement.
8. The `popstack` audit is still a script-assisted source audit, not a
   machine-checked obligation (behavior no longer depends on it; the no-throw
   cell does).

Explicit non-claims:

- Not a promotion of P-CORE-01, P-CORE-02 or P-CORE-03; the registry stays
  PROPOSED.
- Not evidence that the amended patch is behavior-preserving on the OOM domain
  in the IR lane; only that the source catches it as Core does.
- Not a green cell and not a ledger row. `m3a` is a probe module with stubbed
  ABI/RTTI/guard machinery.
- Not a claim about ECDSA/Schnorr/SHA/RIPEMD internals (same-crypto rule
  untouched).

Recommendation: if a lane patch is ever adopted, use the amended form (keep
`catch(...)`, keep the popstack throw) and cite this re-audit plus the corpus/
fuzz/throw/OOM evidence. Do not adopt the catch-deleting P-CORE-01 form for a
behavioral claim. Keep the cell labeled no-throw-domain until B2/B3 are solved.

---

## 8. Reproduction

See `COMMANDS.md`. The short version in a disposable scratch tree:

```sh
# baseline, P-CORE-01, amended builds
JOBS=12 ./harness/build_legs.sh

# corpus + fuzz (paths relative to the scratch root)
python3 harness/diff_corpus.py \
  --baseline lib/libequiv-core-baseline.so \
  --variant p01=lib/libequiv-core-p01.so \
  --variant p01amend=lib/libequiv-core-p01amend.so \
  --out results/corpus
./fuzz_diff --baseline lib/libequiv-core-baseline.so \
  --variant p01=lib/libequiv-core-p01.so \
  --variant p01amend=lib/libequiv-core-p01amend.so \
  --n 1000000 --seed 0x16b10 --out results/fuzz/summary.json

# directed tests
./bin-throw-oom-baseline; ./bin-throw-oom-p01; ./bin-throw-oom-p01amend
./bin-sites-baseline; ./bin-sites-p01; ./bin-sites-p01amend

# bounded E5 probes
/opt/equiv-tools/saw-1.6/bin/saw harness/spec-b4-throw-pcore01-amend.saw
/opt/equiv-tools/saw-1.6/bin/saw harness/spec-vs-empty-m3a.saw
/opt/equiv-tools/saw-1.6/bin/saw harness/spec-vs-scriptnum-m3a.saw
```

`hashes.txt` records every input, module, library and result hash.
