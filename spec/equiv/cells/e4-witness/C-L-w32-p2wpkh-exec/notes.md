# e4-witness/C-L-w32-p2wpkh-exec

Bounded proof of the **execution half of SCR-136**: the P2WPKH implied script is
built, decoded with the `GetScriptOp` rules, executed through the five
`EvalScript` iterations it contains, and consumed by the
`ExecuteWitnessScript` tail (cleanstack + `CastToBool`) — for every input, with
`HASH160` and `EvalChecksig` exposed as explicit seams.

It composes with the existing reconstruction cell
`e4-witness/C-L-w32-p2wpkh-build` (unchanged), which proves that the constructed
25 bytes are exactly `76 a9 14 <program> 88 ac` for every 160-bit program.

## 1. Seam

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

The slice keeps: the arity predicate, the byte construction, `GetScriptOp`
(direct push / PUSHDATA1/2/4 / truncation), the EvalScript per-op checks that
the loop runs (pushed-value size, 201-op budget, disabled-opcode table), the
semantics of `OP_DUP`, `OP_HASH160`, `OP_EQUAL`/`OP_EQUALVERIFY`,
`OP_CHECKSIG`/`OP_CHECKSIGVERIFY`, and the `ExecuteWitnessScript` tail
(`stack.size() != 1` → 30, `CastToBool` → 2).

The implied script has five instructions, so both the `GetScriptOp` walk and
the `EvalScript` loop are **unrolled five times** and the leaf is loop-free
(`build/leaf-shape.txt`: 0 loops, 0 calls, 0 allocas on both legs).

## 2. The two declared seams

Both are *free symbolic inputs*, present identically on the C leg, the L leg and
the Cryptol contract:

| seam | inputs | Core site it stands for |
|---|---|---|
| same-hash | `h0,h1,h2` = 20-byte `HASH160(pubkey)` | `interpreter.cpp:1048-1056` (`CHash160().Write(vch).Finalize`) |
| same-crypto | `ck_err`, `ck_ok` = `EvalChecksig` outcome at `WITNESS_V0` | `interpreter.cpp:331-355` encoding checks + `BaseSignatureChecker` |

Because they are universally quantified, the theorem is **parametric**: it holds
for every possible `HASH160` and every possible signature checker.  No equality
between two different hash/checker models is assumed — the same symbolic value
is used everywhere.  What is *not* proved is that Core's real `CHash160` /
`EvalChecksig` compute those values; instantiating the seams is the residual
obligation (§6).

Note the ordering the cell proves: a hash mismatch returns `EQUALVERIFY` (12)
**before** the checksig seam is consulted, so a witness with a wrong program can
never reach a signature error.

## 3. Proven postcondition

`result(2) | error(6) << 2`, total over all 11 inputs:

| condition | outcome |
|---|---|
| `n_wit != 2` | `(0, 40)` WITNESS_PROGRAM_MISMATCH |
| `sig_len > 520` or `pk_len > 520` | `(0, 6)` PUSH_SIZE |
| `program != hash` (20 bytes) | `(0, 12)` EQUALVERIFY |
| equal hash, `ck_err != 0` | `(0, ck_err)` (low 6 bits) |
| equal hash, `ck_err = 0`, `ck_ok = 0` | `(0, 2)` EVAL_FALSE |
| equal hash, `ck_err = 0`, `ck_ok != 0` | `(1, 0)` success |

Converse forms are included (each outcome iff its condition).  The
`cleanstack` (30) branch is present in both legs but unreachable for the
unmutated script; it is exercised only by mutants.

## 4. Proof shape and exact runs

```sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-exec/alive2/run.sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-exec/saw/run.sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-exec/src/matrix.sh   # concrete sanity table
```

Alive2 v20.0, `--bidirectional`, `--smt-to=120000`:

```
===== cell_p2wpkh_exec =====
Transformation seems to be correct!
These functions seem to be equivalent!
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

SAW 1.6, solver **z3** (abc does not finish the L leg; z3 does in seconds):

```
Proof succeeded! cell_p2wpkh_exec      (C)
Proof succeeded! cell_p2wpkh_exec      (L)
STATUS=saw-green
```

Both `certificate.sha256` files verify with `sha256sum -c`.  The concrete
sanity table is `evidence/matrix.txt` (13 decoded rows: ok / EVAL_FALSE / two
EQUALVERIFY bytes / hash high-bit masking / checksig error pass-through /
mismatch-before-checksig / arity 1 and 3 / size 520 vs 521 / 6-bit masking) and
the leaf shape is `evidence/leaf-shape.txt`.  No `llvm_unsafe_assume_spec`, no
override, no `unsafe_assume`.

### Honest note on the emitted IR

The observable of the ABI is the final `(result, error)` pair.  Clang `-O1`
folds the C leg's straight-line build → parse → execute into an equivalent
predicate over the inputs (the dump is ~4 KB); the reviewed L leg keeps the
five parse/step transitions (~20 KB).  Alive2 therefore proves the *emitted
IR* of the two legs equivalent, exactly as every other cell in this contract
does; SAW additionally proves each emitted module equal to the independent
Cryptol postcondition.  Intermediate stack layouts are not observable through
the ABI and are not claimed beyond the step semantics in the sources.  The
mutation probes below show the cell is sensitive to the build → parse link,
the DUP stack effect and the checksig error pass-through, so the fold is not
hiding those semantics.

## 5. Negative controls (scratch, not committed)

Three one-line mutants of the L leg were built under `build/mut/` and checked
against the unmutated C leg with the same Alive2 invocation.

| mutant | change | Alive2 |
|---|---|---|
| M1 build → parse | PUSHDATA prefix `0x14` → `0x13` | `Transformation doesn't verify!` / `Value mismatch` at `p=h=0`, `n_wit=2`, `ck_ok=0`: source `8` (EVAL_FALSE) vs target `48` (EQUALVERIFY) — the 19-byte push shifts the decoded stream |
| M2 DUP semantics | `OP_DUP` body pushes → drops | `Value mismatch` at all-zero inputs: source `8` (EVAL_FALSE) vs target `72` (18 INVALID_STACK_OPERATION) |
| M3 checksig seam | every `ck_err != 0` → `12` | `Value mismatch` at `ck_err=1`: source `4` (`pack(0,1)`) vs target `48` (EQUALVERIFY) |

So the proof constrains the constructed bytes, the decoded instruction stream,
the stack effect and the seam plumbing — not just the final branch table.

## 6. What remains, and the exact blocker

SCR-136 stays **partial** in the strict ledger sense, but the blocker has
moved: it is no longer "no EvalScript/ExecuteWitnessScript model".  The
remaining two items are precisely the declared seams:

1. **HASH160.**  Instantiate `h0..h2` with a model of Core's `CHash160` and
   prove that model equal to `RIPEMD160(SHA256(pubkey))` over the byte strings
   a witness may carry.  That is the hash floor (SCR-093 / SCR-133 territory);
   no such model exists in the leaf harness.  Since this cell is parametric in
   `h`, the composition is by substitution once the hash model exists.
2. **EvalChecksig at WITNESS_V0.**  Instantiate `(ck_err, ck_ok)` with the
   encoding checks (`IsValidSignatureEncoding`, hashtype, low-S, NULLFAIL) and
   the ECDSA decision.  That is the E3/SCR-112 crypto seam.

Not reachable from this fixed five-instruction script, and therefore not
claimed: the generic `EvalScript` loop and `GetScriptOp` over arbitrary
scripts, the general `valtype`/heap representation, and script policy flags
(MINIMALDATA is irrelevant: the 20-byte push is minimal).

Suggested ledger text if the orchestrator promotes the coverage description
(not applied here — shared ledger untouched):

> SCR-136 remains gap.  `C-L-w32-p2wpkh-build` proves the 25 implied-script
> bytes; `C-L-w32-p2wpkh-exec` proves the build → GetScriptOp → five-op EvalScript
> → witness-tail outcome for every input, parametric in an explicit HASH160 seam
> and an explicit EvalChecksig seam.  Full-row blocker: instantiate the two
> seams (hash floor; ECDSA/encoding checks).  No loop or heap blocker remains
> for this fixed script.

## 7. Bounded representation (stated, not hidden)

- Script bytes are a pure selector over the 25-byte emission (no buffer/heap);
  `GetScriptOp` is a pure function over it.
- Stack elements are a 20-byte payload window plus the true byte length, with
  the head slot as TOP.  The signature and pubkey byte contents are opaque:
  the implied script copies the pubkey (`OP_DUP`) and hands both items to the
  checksig seam, never inspecting their bytes; their lengths are exact and
  drive the 520-byte item cap.
- Pushed payloads longer than 20 bytes take the out-of-domain arm.  The only
  push the implied script performs is the 20-byte program, so this is not
  reachable for the row.
- The checksig error input is the ABI's 6-bit ScriptError field; bits 6..63 of
  `ck_err` are masked and are not part of the seam.
