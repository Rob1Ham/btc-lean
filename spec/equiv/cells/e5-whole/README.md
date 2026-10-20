---
cell: e5-whole
title: "E5 whole-function VerifyScript attempt (SAW; Alive2 translation check)"
status: gap                 # no whole-function proof; one concrete-input SAW result
legs: [C]
tools: ["SAW 1.6 (68eed5f, release-1.6)", "Alive2 v20.0 (c0f5434)"]
core_pin: "cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66"
ir_toolchain: "clang/LLVM 20.1.2"
ir_inputs:
  interpreter_O0_ll: "b8f17c1f94569aa6e4ddc1f9776092ea83584f4aace192169cc32fba25a9ed4d"
  interpreter_O0_bc: "ff8b4028f3fa8afb05b609a3008fab3655176a085bc86f132ff4d475c76d4101"
  interpreter_O0_bc_pinned_lane: "f5718af79c56ccfd5a5437a313d957573cb87c0de0cdf5641013991268801b2c"
  interpreter_O1_ll: "860e711f2b3d2f3217567b706119d58ad8f18ae3bf9a78d1a846aeb28afe9f88"
  interpreter_O1_bc: "114e84075243920fab85c4c1323cb345cc190edabb402edf5fda6dfbdff94c0c"
ir_note: "the pinned proof-lane .bc is /tmp/opencode/equiv-work/ir20/interpreter-O0.bc (f5718a...); the /tmp/.../ir/ copy named in the task differs only in C++ ABI type-layout metadata. roots.bc and the scoped green result come from the pinned ir20 lane."
  roots_bc_patched_erased: "2b9f683c4fdd3550e4eab43083a4c528ce785d37956f0f24b75311ec756f04a8"
  linked3_probe_bc: "d287d14216fc1d1b5ed3461aad2ca96cf65bb00884b6abc85e9d90f9a74016a2"
blocking_features:
  - "undefined external GetScriptOp (declared, defined in script.cpp, not in the single-TU module)"
  - "heap allocator externals (_Znwm, malloc, free, realloc) reached by std::vector push_back"
  - "unbounded EvalScript dispatch loop (no IR bound; needs an invariant or EvalStep slicing)"
  - "C++ exception edges (invoke/landingpad) in the raw module"
  - "__cxa_guard static-initialization variables in the unpatched module"
  - "ptrtoint in reachable std::vector/tinyformat helpers"
  - "crypto/checker/hash externals (4 btc_equiv_check_* hooks, SHA/RIPEMD, memcmp, CheckMinimalPush)"
ledger: "NOT registered in spec/db/equiv-cells.yaml (E5 write scope excludes it); proposal only"
---

# E5 whole-function `VerifyScript` — SAW attempt and scoped residual

**Bottom line: no whole-function `VerifyScript` proof was obtained.** SAW
loads the Core LLVM-20 modules and symbolically executes `VerifyScript` for
one fully concrete empty-script input (a real, scoped result: return `false`).
Every attempt to execute a non-empty script stops at the first undefined
external, `GetScriptOp`. After linking `script.cpp` into the module, the next
hard stop is the heap allocator (`_Znwm`). The unbounded `EvalScript` dispatch
loop and the exception/guard/ptrtoint surface remain after that. The complete
blocker analysis is in [`findings/e5/E5-RESIDUAL.md`](../../findings/e5/E5-RESIDUAL.md).

This is the E5 "scoped residual" outcome, not an E5 proof. No
`llvm_unsafe_assume_spec` was used anywhere.

## Cell fields (proposal for the ledger owner)

- **contract:** `contract/ABI.md` (unchanged by this role; not hashed here)
- **legs:** C (Core only). No L/R direction is attempted in E5.
- **precondition:** the concrete empty-script input of
  `saw/e5-verifyscript-empty-roots.saw` / `...-linked3.saw`: `scriptSig` and
  `scriptPubKey` are 40-byte `prevector<36,unsigned char,unsigned int>` /
  `CScript` objects with size field 0 (offset 36, little-endian i32); witness
  pointer null (Core substitutes `emptyWitness`); flags 0; a readable 8-byte
  checker object (never dereferenced on this path); a readable 8-byte
  `ScriptError_t`.
- **postcondition:** `VerifyScript` returns `false` (`i1 0`). The error cell
  is not asserted; the path is `stack.empty()` → `SCRIPT_ERR_EVAL_FALSE`.
- **direction:** not applicable (C-only scoped execution result).
- **scr_rows:** none claimed. This is not offered as a green SCR cell.
- **patches:** the primary module `roots.bc` is the CORE-IR **patched** lane
  (P-CORE-01/02/03, all still PROPOSED). The second green run uses a probe
  module built from the **unpatched** `interpreter-O0.bc` plus linked
  `script.cpp`, with exceptions erased, guard bytes pinned, and three ABI
  globals stubbed (see `build/build-module.sh`).
- **trust_note:** both green results are concolic (fully concrete inputs), not
  symbolic whole-function proofs. SAW's `llvm_verify` still has to prove the
  return obligation, but the input space is a singleton. The linked3 module
  additionally assumes the one-time static initialization has completed and
  that erased exception paths are unreachable.

## Results

| Run | Module | Outcome | Raw log |
|---|---|---|---|
| SAW load, raw `interpreter-O0.bc` | raw O0 | loads | `logs/e5-load-raw.log` |
| SAW load, `interpreter-O1.bc` | raw O1 | loads | `logs/e5-load-o1.log` |
| SAW load, `roots.bc` | patched+erased | loads | `logs/e5-load-roots.log` |
| `llvm_verify` empty scripts | raw `interpreter-O0.bc` | **fails at load**: undefined ABI global `_ZTVN10__cxxabiv120__si_class_type_infoE` | `logs/e5-verifyscript-empty.raw.log` |
| `llvm_verify` empty scripts | `roots.bc` | **Proof succeeded** (return `false`) | `logs/e5-verifyscript-empty-roots.raw.log` |
| `llvm_verify` empty scripts | linked3 probe | **Proof succeeded** (return `false`) | `logs/e5-verifyscript-empty-linked3.raw.log` |
| `llvm_verify` OP_1 (`51`) script | `roots.bc` | **stops**: no implementation/override for `GetScriptOp` | `logs/e5-verifyscript-op1.raw.log` |
| `llvm_verify` OP_1 script | linked `script.cpp`, no ABI stub | **stops at setup**: ABI vtable global not a compile-time constant | `logs/e5-verifyscript-op1-linked.raw.log` |
| `llvm_verify` OP_1 script | linked + ABI stub | **stops**: `__cxa_guard` variable has no allocation | `logs/e5-verifyscript-op1-linked2.raw.log` |
| `llvm_verify` OP_1 script | linked + ABI stub + guards pinned | **stops**: no implementation/override for `_Znwm` (heap) | `logs/e5-verifyscript-op1-linked3.raw.log` |
| Alive2 self-pipeline `VerifyScript` | raw O0 | **fails to translate**: `Unsupported instruction: invoke` | `logs/e5-alive2-raw-verifyscript.log` |
| Alive2 self-pipeline `VerifyScript` | `roots.bc` | `Transformation seems to be correct! (syntactically equal)` — **not an equivalence proof** | `logs/e5-alive2-roots-verifyscript.log` |
| Alive2 self-pipeline, SMT enabled (`--smt-to=5000`) | `roots.bc` | same `syntactically equal` result; no SMT obligation was generated | `logs/e5-alive2-roots-verifyscript-smt.log` |

SAW proofs are `llvm_verify ... [] false ... z3` (no unsound override). The
`abc` prover is not installed in this environment; the SAW bundle's `z3`
(4.8.14) was used.

## Reproduction

Tool versions:

```sh
/opt/equiv-tools/saw-1.6/bin/saw --version   # 1.6 (68eed5f release-1.6)
/usr/local/bin/alive-tv --version            # v20.0 (c0f5434), LLVM 20.1.2
```

The SAW specs contain absolute `/tmp/opencode/equiv-work/...` input paths:

```sh
# green scoped result (concrete empty scripts)
/opt/equiv-tools/saw-1.6/bin/saw \
  cells/e5-whole/saw/e5-verifyscript-empty-linked3.saw

# first hard blocker for a non-empty script
/opt/equiv-tools/saw-1.6/bin/saw \
  cells/e5-whole/saw/e5-verifyscript-op1.saw

# Alive2 translation checks
alive-tv /tmp/opencode/equiv-work/ir/interpreter-O0.bc \
  --func='_Z12VerifyScriptRK7CScriptS1_PK14CScriptWitness19script_verify_flagsRK20BaseSignatureCheckerP13ScriptError_t' \
  --passes=verify --skip-smt
alive-tv /tmp/opencode/equiv-work/ir20-proto/roots.bc \
  --func='_Z12VerifyScriptRK7CScriptS1_PK14CScriptWitness19script_verify_flagsRK20BaseSignatureCheckerP13ScriptError_t' \
  --passes=verify --skip-smt
```

Rebuild the linked3 probe module with `build/build-module.sh` (writes only
under `/tmp/opencode/equiv-work`). It applies three explicit transformations:
exception erasure, internalization, ABI-global stubbing and `__cxa_guard`
pinning.

## What would be needed to close E5

1. **A real definition or verified override for `GetScriptOp`** (and the
   `CScript::GetOp` chain) at the pinned LLVM version.
2. **A heap model**: verified specs for `_Znwm`/malloc/free/realloc, or SAW
   overrides that model `std::vector` growth without pretending allocation
   cannot fail.
3. **An `EvalScript` loop invariant** over (PC, stack, altstack, condition
   stack, error) — or the P-CORE-04 `EvalStep` refactor plus bounded
   unrolling. A timeout without an invariant is not a proof.
4. **Exception policy**: keep erasure with a no-throw proof for the domain, or
   overrides for `__cxa_*` that preserve the uncaught-exception result.
5. **Guard policy**: P-CORE-03, or a verified model of one-time static
   initialization.
6. **Crypto/hash seam**: the four `btc_equiv_check_*` hooks, SHA-1/SHA-256/
   RIPEMD-160, `memcmp`, `CheckMinimalPush`; the claim stays conditional on
   same-crypto (`docs/DECISION-lax-ecdsa.md`).
7. **Symbolic CScript/vector setup** if a genuine whole-function theorem (not
   a concrete input) is wanted; the concrete 40-byte layout used here does not
   generalize.

## Artifact hashes

See `SHA256SUMS` in this directory for the specs, logs and build inputs.
