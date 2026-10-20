# tapscript/C-L-taproot-gate — notes

## Source excerpts (pin `cce32b168`)

`src/script/interpreter.cpp:1957-1969`:

```cpp
    } else if (witversion == 1 && program.size() == WITNESS_V1_TAPROOT_SIZE && !is_p2sh) {
        // BIP341 Taproot: 32-byte non-P2SH witness v1 program (which encodes a P2C-tweaked pubkey)
        if (!(flags & SCRIPT_VERIFY_TAPROOT)) return set_success(serror);
        if (stack.size() == 0) return set_error(serror, SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY);
        if (stack.size() >= 2 && !stack.back().empty() && stack.back()[0] == ANNEX_TAG) {
            // Drop annex (this is non-standard; see IsWitnessStandard)
            const valtype& annex = SpanPopBack(stack);
            execdata.m_annex_hash = (HashWriter{} << annex).GetSHA256();
            execdata.m_annex_present = true;
        } else {
            execdata.m_annex_present = false;
        }
        execdata.m_annex_init = true;
        if (stack.size() == 1) {
```

`src/script/interpreter.h:240`: `WITNESS_V1_TAPROOT_SIZE = 32`.

Lean (`spec/core/Bitcoin/Interpreter/Defs.lean:1280-1284`):

```lean
  else if version = 1 ∧ program.size = 32 ∧ !isP2SH then
    -- BIP341 taproot
    if !flags.taproot then .ok
    else match witness with
      | [] => .fail .witnessProgramWitnessEmpty
      | _ => ...
```

## Design

The C leg is a direct source slice. The L leg restates Lean's branch order.
The cell deliberately stops at the key/script split: result code `2` means
"continuation", not success. `3` means the shape is handled by another arm of
`VerifyWitnessProgram` (v0, other versions, P2SH).

## Commands and versions

- clang: Ubuntu clang 20.1.2 (0ubuntu1~24.04.3)
- Alive2: Ubuntu LLVM version 20.1.2 (`/usr/local/bin/alive-tv`, v20.0)
- SAW: 1.6 (68eed5f release-1.6), solver `abc`
- IR: `clang++-20 -O1 -S -emit-llvm`; `llvm-extract --func=cell_taproot_gate
  --recursive`.

```sh
bash spec/equiv/cells/tapscript/C-L-taproot-gate/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-taproot-gate/saw/run.sh
```

## Raw result tails

Alive2 (`alive2/result.txt`):

```
Transformation seems to be correct!
These functions seem to be equivalent!
Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

SAW (`saw/result.txt`):

```
Proof succeeded! cell_taproot_gate
Proof succeeded! cell_taproot_gate
CELL_tapscript_gate_SAW_GREEN
STATUS=saw-green (2/2 proofs)
```

## Honesty notes

- The gate's "not anyone-can-spend" half is evidenced by the empty-witness
  error 39 and by the continuation marker for non-empty witnesses; the final
  verdict is the sibling key-path/script-path cells' subject.
- SCR-142 remains **partial** because the row also names activation height
  709632 and exception block 692261, which are not inputs to
  `VerifyWitnessProgram` and are absent from the tape.
- This cell does not claim annex detection; that is
  `C-L-taproot-annex`.
