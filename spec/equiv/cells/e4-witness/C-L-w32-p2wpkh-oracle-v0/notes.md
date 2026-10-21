# e4-witness/C-L-w32-p2wpkh-oracle-v0

Bounded proof of **SCR-136** at the P2WPKH v0 boundary, extending the existing
`C-L-w32-p2wpkh-exec` cell from "the outcome is right for every oracle value"
to "the outcome is right **and the two oracle seams receive the right bytes,
lengths and scriptCode**".

The cell adds two exports over the same five-op machine:

- `cell_p2wpkh_scr136` — the total execution outcome (identical contract to the
  exec cell);
- `cell_p2wpkh_seam` — a symbolic transcript export returning the argument word
  a selected seam receives, or an all-ones sentinel when that seam is not
  reached.

## 1. Seam and sources

Core at pin `cce32b168`:

```cpp
// interpreter.cpp:1947-1953
} else if (program.size() == WITNESS_V0_KEYHASH_SIZE) {
    if (stack.size() != 2) {
        return set_error(serror, SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH);
    }
    exec_script << OP_DUP << OP_HASH160 << program << OP_EQUALVERIFY << OP_CHECKSIG;
    return ExecuteWitnessScript(stack, exec_script, flags, SigVersion::WITNESS_V0,
                                checker, execdata, serror);
}
```

and the two argument sites the new export pins down:

```cpp
// interpreter.cpp:1048-1056 (OP_HASH160)
CHash160().Write(vch).Finalize(vchHash);   // vch is the whole top stack element
// interpreter.cpp:1075-1076 (OP_CHECKSIG)
valtype& vchSig    = stacktop(-2);
valtype& vchPubKey = stacktop(-1);         // EvalChecksig(..., pbegincodehash, pend, ...)
// interpreter.cpp:331-355 (EvalChecksigPreTapscript)
CScript scriptCode(pbegincodehash, pend);  // WITNESS_V0: no FindAndDelete
```

The slice keeps the arity predicate, the 25-byte construction, `GetScriptOp`
(direct push / PUSHDATA1/2/4), the EvalScript per-op checks, the five
instruction semantics, and the `ExecuteWitnessScript` tail (cleanstack 30,
CastToBool 2).  The loop and parser are unrolled exactly five times.

## 2. The two declared seams

Free symbolic inputs, identical on C, L and the Cryptol contract:

| seam | inputs | Core site |
|---|---|---|
| same-hash | `h0,h1,h2` = 20-byte `HASH160(pk)` | `interpreter.cpp:1048-1056` |
| same-crypto | `(ck_err, ck_ok)` = EvalChecksig outcome at WITNESS_V0 | `interpreter.cpp:331-355` + checker |

Because both are universally quantified, the outcome theorem is parametric: it
holds for every hash and every checker.  The new transcript export additionally
proves *what those primitives are called with*:

| selector | result |
|---|---|
| `sel 0, k` | word k of the HASH160 preimage = the pk witness item (masked to `pk_len`) |
| `sel 4` | HASH160 preimage length = `pk_len` |
| `sel 5` | HASH160 output width = 20 |
| `sel 1, k` | word k of EvalChecksig's signature argument (masked to `sig_len`) |
| `sel 2, k` | word k of EvalChecksig's pubkey argument (masked to `pk_len`) |
| `sel 3, k` | word k of EvalChecksig's scriptCode = the whole 25-byte implied script |
| `sel 6 / 7 / 8` | EvalChecksig sig length / pubkey length / scriptCode length (25) |
| anything else / not reached | sentinel `0xffffffffffffffff` |

Selection follows execution order.  The hash seam is reached at OP_HASH160,
*before* OP_EQUALVERIFY, so `sel 0/4/5` do not require the hash to match.  The
checksig seam is reached only if `program = HASH160(pk)`; a mismatch aborts with
12 first.  Arity (40) and item-size (6) failures precede both.  This
ordering — not just the values — is part of the compared functions.

## 3. Outcome contract (export A)

`result(2) | error(6) << 2`, total:

| condition | outcome |
|---|---|
| `n_wit != 2` | `(0, 40)` |
| `sig_len > 520` or `pk_len > 520` | `(0, 6)` |
| `program != hash` | `(0, 12)` |
| equal hash, `ck_err != 0` | `(0, ck_err & 63)` |
| equal hash, `ck_err = 0`, `ck_ok = 0` | `(0, 2)` |
| equal hash, `ck_err = 0`, `ck_ok != 0` | `(1, 0)` |

Converse forms are included.

## 4. Proof shape and exact runs

```sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-oracle-v0/alive2/run.sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-oracle-v0/saw/run.sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-oracle-v0/src/matrix.sh   # concrete sanity table
```

Toolchain (from this host): Alive2 `Ubuntu LLVM version 20.1.2`; SAW
`1.6 (68eed5f release-1.6)`; clang `20.1.2`; solver z3 `4.8.12`.

Alive2, `--bidirectional --smt-to=120000`, both exports:

```
===== cell_p2wpkh_scr136 =====
Transformation seems to be correct!
These functions seem to be equivalent!
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
===== cell_p2wpkh_seam =====
Transformation seems to be correct!
These functions seem to be equivalent!
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

SAW, four `llvm_verify` obligations, solver z3:

```
Proof succeeded! cell_p2wpkh_scr136      (C)
Proof succeeded! cell_p2wpkh_scr136      (L)
Proof succeeded! cell_p2wpkh_seam        (C)
Proof succeeded! cell_p2wpkh_seam        (L)
STATUS=saw-green
```

No `llvm_unsafe_assume_spec`, no override, no `unsafe_assume`.

The concrete matrix (`evidence/matrix.txt`) decodes 11 outcome rows and 24
transcript rows (preimage words past `pk_len`, output width, sig word past the
window, scriptCode words 0/3, the three lengths, sentinel on mismatch/arity/
size, and `sel`/`k` truncation) and asserts eight exact values independently.

### Leaf shape

`evidence/leaf-shape.txt` (produced by `src/build.sh`) records no loop blocks
and:

```
[c:cell_p2wpkh_scr136] call/invoke=0 alloca=0
[c:cell_p2wpkh_seam]   call/invoke=0 alloca=0
[l:cell_p2wpkh_scr136] call/invoke=0 alloca=0
[l:cell_p2wpkh_seam]   call/invoke=0 alloca=0
```

## 5. A note on the emitted IR

The ABI observable of export A is the final `(result, error)` pair; clang folds
the straight-line build → parse → execute into a predicate, while the reviewed
L leg keeps the five transitions.  Alive2 proves the emitted IR equivalent in
both directions and SAW proves each module equal to the same independent
contract — the same standard as the sibling cells.  Export B is the part that
prevents the fold from hiding argument plumbing: it exposes the preimage,
scriptCode, sig/pk words and lengths as return values.

One representation detail is worth recording: an earlier draft of the mask
helper used `(1ull << 8n) - 1`.  Clang rewrote it as a shift by 64 on the
`n == 8` arm, which is LLVM poison even when unselected; SAW correctly rejected
it (`Poison value created`, counterexample `k=15, pk_len=192`).  The committed
helper builds the mask from constant bytes with no variable shift.  This is a
tool-model constraint, not a semantic change.

## 6. Negative controls (scratch, not committed)

Three one-line mutants of the **L transcript arm** were built under a scratch
directory outside the repository and checked against the unmutated C leg and against
the shared Cryptol contract.

| mutant | change | Alive2 | SAW |
|---|---|---|---|
| M1 preimage | HASH160 preimage reads the program element instead of the duplicated pk item | `Transformation doesn't verify!` — `Value mismatch`, source `0`, target `3` | `Proof failed`, counterexample `sel=0,k=0,pk_len=20` |
| M2 scriptCode | scriptCode is the 20-byte program instead of the whole 25-byte script | `Value mismatch`, source `0x14a976`, target `0` | `Proof failed`, counterexample `sel=3,k=2` |
| M3 ordering | OP_EQUALVERIFY no longer aborts, so a checksig selector answers on a mismatch | `Value mismatch`, source `0xffffffffffffffff`, target `0` | `Proof failed`, counterexample `sel=2,k=3452028158` |

So the cell constrains the seam interface and the error/selection ordering, not
only the final branch table.

## 7. Residual and coverage

The cell is sound but not complete for the row's *primitives*:

1. **HASH160.**  `h0..h2` are free.  The cell proves the preimage is exactly
   the pk item with length `pk_len` and the output width is 20; it does not
   compute `RIPEMD160(SHA256(pk))` (hash floor, SCR-093/SCR-133).
2. **EvalChecksig at WITNESS_V0.**  `(ck_err, ck_ok)` are free.  The cell proves
   the exact `(sig, pk, scriptCode)` arguments and their lengths; it does not
   implement DER/hashtype/low-S/NULLFAIL or the ECDSA decision (E3/SCR-112).
3. **`witversion = 0`** is a shared precondition of every v0 cell and is not
   modelled here; program length/version dispatch belongs to SCR-135/SCR-137
   (`e4-witness/C-L-w32-witness-v0-error-total`).
4. **F-DIV-004** (Lean `isValidPubKey` header-only vs Core
   `CPubKey::ValidSize`) is inherited through the free checker verdict and is
   not discharged.  Since the verdict is arbitrary, the cell is sound for any
   pubkey-validity policy; closing the divergence is a separate task.

`scr_row_coverage` is therefore declared **full at this cell's scope,
conditional on the named same-hash/same-crypto premise**: the build, decode,
five-op execution, error precedence and both oracle interfaces are proved; the
only remaining objects are the two named primitives, which is exactly the
accepted boundary in `checksig/C-L-checksig-nullfail-hashtype` (SCR-110/111)
and `hash-ops/C-L-hash-widths` (SCR-093/SCR-095).

## 8. Bounded representation (stated, not hidden)

- Script bytes are a pure selector over the 25-byte emission (no buffer/heap).
- Stack elements are a 20-byte payload window + exact length + a byte-source
  tag (`PROGRAM / HASH / SIG / PK / SCRIPT`).  The tag is what makes the
  transcript export sensitive to *which* element is hashed or checked.
- Pubkey window 72 bytes (9 words), signature window 80 bytes (10 words); every
  DER signature <= 73 bytes and every compressed (33) / uncompressed (65)
  pubkey fits.  Bytes past the true length read as 0 and the lengths are exact
  up to the 520-byte witness cap.
- The checksig error input is the ABI's 6-bit ScriptError field; bits 6..63 are
  masked.
- Pushed payloads longer than 20 bytes and instructions outside the fixed five
  are out-of-domain (sentinel/`unjudged`) and unreachable for the unmutated
  script.  The 1000-item STACK_SIZE guard cannot fire at depth <= 4.
