# Wave16B / 12 — bounded SegWit v0 witness execution prototype

**Role:** wave16b task `12-witness-exec` (structural unblocker for PR #29).
**Date:** 2026-10-20.
**Branch:** `wave16b/12-witness-exec`, cut from PR head `805c804`.
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (Bitcoin Core v32.99).
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`.

## Verdict

A bounded execution prototype was built and **both tools are green**:

- cell: `spec/equiv/cells/e5-whole/C-L-w2-v0-witness-exec/`
- Alive2 v20.0: both exported functions, `1 correct / 0 incorrect / 0 errors`
  for each; `STATUS=alive2-green`.
- SAW 1.6: four proofs (`cell_v0_exec` C+L, `cell_checksig_gate` C+L),
  `CELL_W2_V0_WITNESS_EXEC_SAW_GREEN`; `STATUS=saw-green`.
- Both certificate files verify (`sha256sum -c`: 15/15 Alive2, 17/17 SAW).

It advances the evidence for **SCR-133 (plumbing only), 134, 135, 137, 138
(bounded post-state model) and 139 (sigversion gate only)**. It does **not**
promote any row and is **not** a whole-function E5 proof. No pin, contract,
Lean proof, census, ledger or Core source file was changed.

The core result is structural: the v0 dispatch, the implied P2WPKH script,
the witness cleanstack check and the checksig sigversion gate can be put in
one loop-free leaf and are accepted by both tools. The EvalScript loop, the
general `valtype`, SHA256/HASH160, ECDSA and `FindAndDelete` byte semantics
remain abstract or external (section 5).

## 1. What was built

Two exported functions, each with a C leg and a reviewed Lean transliteration:

### `cell_v0_exec` — composed v0 path

Source-faithful control flow of:

| Core site | What is kept |
|---|---|
| `interpreter.cpp:1927-1957` | `VerifyWitnessProgram` v0: P2WSH empty witness (39), SHA256 mismatch (40), P2WPKH arity (40), wrong length (38) |
| `interpreter.cpp:1939-1946` | pop witness script, hash equality branch |
| `interpreter.cpp:1952-1953` | implied `OP_DUP OP_HASH160 <program> OP_EQUALVERIFY OP_CHECKSIG` |
| `interpreter.cpp:1874-1879` | `ExecuteWitnessScript` implicit cleanstack: size != 1 -> 30; `!CastToBool` -> 2 |
| `interpreter.cpp:331-343` | `EvalChecksigPreTapscript` FindAndDelete gate, driven by `SigVersion` |

Domain and result table are in `cells/e5-whole/C-L-w2-v0-witness-exec/spec.md`.
Summary:

- P2WSH: `wit_n=0 -> 39`; `hash_eq=0 -> 40`; `wit_n=1` and `hash_eq=1`
  executes one of four constant scripts: `51 75 51` -> ok, `51 75 00` -> 2,
  `51 75 51 51` -> 30, `51 75` -> 30. `wit_n in {2,3}` returns `SENT` (the
  cell's declared domain restriction, not Core semantics).
- P2WPKH: `wit_n!=2 -> 40`; `wit_n=2` and `hash_eq=0` -> 12
  (`OP_EQUALVERIFY`); checksig false -> 2; checksig true -> ok. `sv=1`
  (WITNESS_V0) on every execution arm; `del=0` always.
- every other `program_len` -> 38.
- out-of-domain inputs -> `SENT`.

### `cell_checksig_gate` — BASE / WITNESS_V0 gate

`if (sigversion == SigVersion::BASE)` consumes the declared `fd_found` and can
raise 54 (`SIG_FINDANDDELETE`); `sv = WITNESS_V0` never applies it. This is the
`sigversion != BASE skips deletion` control flow of SCR-139, isolated from
`FindAndDelete` byte semantics.

## 2. Exact runs

### Alive2

```sh
cells/e5-whole/C-L-w2-v0-witness-exec/alive2/run.sh
# alive-tv v20.0 (c0f5434), clang 20.1.2, LLVM 20.1.2
# cell_v0_exec:        1 correct, 0 incorrect, 0 failed-to-prove, 0 Alive2 errors
# cell_checksig_gate:  1 correct, 0 incorrect, 0 failed-to-prove, 0 Alive2 errors
# STATUS=alive2-green
```

Log: `alive2/result.txt` (sha256
`cb75e609817efbf8f56799eaabc885ca09f984aa34dde9fa1a87ca3e61ae1bed`).
Cert: `alive2/certificate.sha256`, 15/15 OK.

### SAW

```sh
cells/e5-whole/C-L-w2-v0-witness-exec/saw/run.sh
# SAW 1.6 (68eed5f release-1.6), solver abc
# Proof succeeded! cell_v0_exec          (C)
# Proof succeeded! cell_v0_exec          (L)
# Proof succeeded! cell_checksig_gate    (C)
# Proof succeeded! cell_checksig_gate    (L)
# CELL_W2_V0_WITNESS_EXEC_SAW_GREEN
# STATUS=saw-green
```

Log: `saw/result.txt` (sha256
`66fadb6ab85b193d795c29550e7ca95dad1ae405ec6ead1a4df01835423664f1`).
Cert: `saw/certificate.sha256`, 17/17 OK. No `llvm_unsafe_assume_spec`.

### Leaf shape (why the tools ingest it)

`src/build.sh` enforces and `evidence/leaf-shape.txt` records: for all four
extracted functions, `llvm-extract` + `opt -passes='print<loops>'` shows **no
loops**, and the disassembly has **0** `call` / `invoke` / `alloca`.
`src/build.sh` fails the build if any of those appears.

### Concrete sanity matrix (not a proof)

`src/matrix.sh` -> `evidence/matrix.txt` decodes the C slice on 17 inputs
(39/40/38, all four cleanstack outcomes, P2WPKH 12/2/ok, and the gate).
The table matches the postcondition in `spec.md`.

## 3. Rows advanced

| row | this work | still missing for a full row |
|---|---|---|
| SCR-133 | P2WSH `hash_eq=0 -> 40` branch proved; hash equality is explicit plumbing | SHA256 internals; same-crypto boundary |
| SCR-134 | composed dispatch: 32-byte program + empty witness -> 39, proved together with execution | none at this seam (full for the predicate) |
| SCR-135 | composed dispatch: P2WPKH arity -> 40 **and** P2WSH mismatch -> 40 | none at this seam |
| SCR-136 | implied script bytes and straight-line stack effect exercised | HASH160/CHECKSIG real semantics; not claimed |
| SCR-137 | every other v0 `program_len` -> 38, total | none at this seam |
| SCR-138 | cleanstack predicate proved over all `(size, truthy)` and over four executed scripts | arbitrary `EvalScript` post-state (R1/R2) |
| SCR-139 | v0 path never applies FindAndDelete; BASE arm can raise 54 | `FindAndDelete` byte semantics (R5), and a composition check |

No row is filed or promoted here; wave16 owns row promotion and the
orchestrator owns the ledger. This report is evidence, not a ledger write.

## 4. Pin probe — why the real function is not ingestible

The pinned `[core.ir]` O0 module (`/tmp/opencode/equiv-work/ir20/interpreter-O0.bc`,
sha256 `f5718af79c56ccfd5a5437a313d957573cb87c0de0cdf5641013991268801b2c`)
was probed directly. Exact commands and full output:
`pin-probe/commands.sh`, `pin-probe/shape.txt`, `pin-probe/alive2.log`.

```sh
FN='_ZL20VerifyWitnessProgramRK14CScriptWitnessiRKSt6vectorIhSaIhEE19script_verify_flagsRK20BaseSignatureCheckerP13ScriptError_tb'
llvm-extract --func="$FN" interpreter-O0.bc -o vw.bc     # non-recursive
alive-tv vw.ll --passes=verify --skip-smt
```

Shape of the real `VerifyWitnessProgram` (non-recursive extraction, so callees
are declarations; the counts are still the function's own body):

```
invoke=35   landingpad=1   alloca=45   call=62
opt print<loops>: no loops in VerifyWitnessProgram itself
```

Alive2:

```text
ERROR: Unsupported instruction:   invoke void @_ZN19ScriptExecutionDataC2Ev(...)
ERROR: Could not translate '...VerifyWitnessProgram...' to Alive IR
1 Alive2 errors
```

So the first hard stop is a C++ constructor `invoke` (the B4 exception-edge
blocker), not the v0 logic. The prototype avoids it by slicing the control
flow into pure C, which is exactly the declared refinement obligation.

The E5 residual blockers B1-B7 are unchanged: `GetScriptOp` (B1), the heap
(B2), the `EvalScript` loop (B3), exception edges/ABI globals (B4), `__cxa_guard`
(B5), `ptrtoint`/STL (B6), crypto/checker externals (B7). This cell is
ingestible because it instantiates none of them.

## 5. Mutation probes — the cell is not vacuous

Two one-line L-leg mutants were built in scratch and checked against the
unmutated C slice and the unmutated Cryptol spec. Details and full logs:
`mutation/README.md`.

| mutant | change | Alive2 | SAW |
|---|---|---|---|
| M1 cleanstack | `n != 1` -> `n < 1` | `Transformation doesn't verify!` source `#x0400515175517178` vs target `#x0400515175517101` (P2WSH kind 2: C=30 CLEANSTACK, mutant=ok) | C proof succeeds, L proof fails |
| M2 sigversion gate | `sv == 0` -> `sv <= 1` | `Transformation doesn't verify!` `0x201` vs `0x207` at `sv=1, fd_found=1` | C proof succeeds, L proof fails |

This shows the tools constrain the cleanstack predicate (SCR-138) and the
FindAndDelete gate (SCR-139), not just the surrounding plumbing. It says
nothing about the abstractions R1-R9.

## 6. What remains

1. **SCR-138 full**: replace the four-script family with a bounded symbolic
   script envelope (e.g. `script_len <= 8`, opcode subset
   `{0x00,0x51,0x75,0x76,0x87,0x88}`) and prove the executor's post-state
   relation, or prove an `EvalScript` post-state invariant that feeds the
   three-line cleanstack. The current cell proves the consumer and four
   concrete producers, not arbitrary scripts.
2. **SCR-139 full**: the missing piece is `FindAndDelete` byte semantics.
   The separate wave16 `checksig/C-L-findanddelete` cell (not in this
   worktree; not relied on here) is the bounded `FindAndDelete` proof; this
   cell is the gate. A two-cell composition check (or a single cell that
   inlines the bounded `FindAndDelete`) would close the row at the bounded
   seam. Do not cite this cell alone as SCR-139.
3. **SCR-133 full**: requires a same-crypto SHA256 (or a declared hash model
   accepted by the trust base). This cell only proves the branch.
4. **Full E5**: B1+B2+B3 remain the hard blockers: a real `GetScriptOp`, a
   heap/vector model, and an `EvalScript` loop invariant. A timeout or an
   `unsafe_assume` would not be a proof; none was used.
5. **General `valtype`/flags/tx context**: item sizes, `CastToBool` negative
   zero, encoding validators, NULLFAIL/STRICTENC, sighash, sigops/weight are
   outside this prototype (R2-R4, R7-R8).

There is no source patch and no proposal to change the pins. If the
orchestrator wants a row promotion, the smallest next step is the
`FindAndDelete` + gate composition for SCR-139 and a bounded symbolic script
envelope for SCR-138; neither is claimed here.

## 7. Artifacts

All new files are under:

```
spec/equiv/cells/e5-whole/C-L-w2-v0-witness-exec/
spec/equiv/findings/wave16b/12-witness-exec/
```

Source hashes (cell `src/`):

| file | sha256 |
|---|---|
| `w2_common.h` | `71cf1b89a75051675ce224a5722d5885e3b79b0518cb1a45c0fa6f33903d70bd` |
| `c_cell.cpp` | `35993326dff7bc4c999dd999f89fb80fabd18d9f0760766ad1cf0e65d2edf068` |
| `l_cell.cpp` | `2801fe5591a546f242dc84c91303438a525d489431a7fcc8161ad95563348391` |
| `cell.cry` | `a80f741d13ba56df250b40dca961b31260b6941b7d8d978bec2ff781aaabe034` |
| `cell.saw` | `d3e4f3eb25b1c3a439231c3cda6eee5440242aa8a1807207b2693d1554e1bffa` |
| `build.sh` | `9c784d897e27c2625ce52bc1276bd69652730a3f1fc63ec5856b03ec4cda2e70` |

Reproduce:

```sh
spec/equiv/cells/e5-whole/C-L-w2-v0-witness-exec/alive2/run.sh
spec/equiv/cells/e5-whole/C-L-w2-v0-witness-exec/saw/run.sh
spec/equiv/cells/e5-whole/C-L-w2-v0-witness-exec/src/matrix.sh
spec/equiv/cells/e5-whole/C-L-w2-v0-witness-exec/src/leaf-shape.sh
```

Commit: see the branch tip (`wave16b/12-witness-exec`). Nothing was pushed.
