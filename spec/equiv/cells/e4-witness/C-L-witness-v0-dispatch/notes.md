# e4-witness/C-L-witness-v0-dispatch

Bounded, symbolic proof of the witness-v0 length/arity dispatch in
`VerifyWitnessProgram`. This is the Task A green attempt: it deliberately
stops before SHA256 and `ExecuteWitnessScript`, so it can be judged by both
tools without a loop, an indirect call, or a crypto model.

## Seam and citations

Core (`/tmp/opencode/equiv-work/bitcoin/src/script/interpreter.cpp`, pin
`cce32b168`):

- `1927` — `VerifyWitnessProgram` signature.
- `1934-1938` — 32-byte v0 program (P2WSH); `stack.size() == 0` returns
  `SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY` (39).
- `1939-1946` — `SpanPopBack`, single `SHA256`, `memcmp` against `program`,
  then `ExecuteWitnessScript`. **Abstracted to success.**
- `1947-1953` — 20-byte v0 program (P2WPKH); `stack.size() != 2` returns
  `SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH` (40), else the implied
  `DUP HASH160 <program> EQUALVERIFY CHECKSIG` script runs. **Execution
  abstracted to success.**
- `1954-1955` — every other v0 length returns
  `SCRIPT_ERR_WITNESS_PROGRAM_WRONG_LENGTH` (38).

Lean (`spec/core/Bitcoin/Interpreter/Defs.lean:1259-1279`):

```
if version = 0 then
  if program.size = 32 then
    if witness.length = 0 then .fail .witnessProgramWitnessEmpty
    else if hashSha256 script != program then .fail .witnessProgramMismatch
    else executeWitnessScript ...
  else if program.size = 20 then
    if witness.length != 2 then .fail .witnessProgramMismatch
    else executeWitnessScript ...
  else .fail .witnessProgramWrongLength
```

The L leg in `cells/_tools/e4/l_cell.cpp` is a reviewed transliteration of
that branch order. It is **not** produced by `mk_leaf.py`: the twin has no
`VerifyWitnessProgram` handler, so there is no handler body to copy. The
transliteration and its abstraction comments are the review artifact.

## What is proved

Function `cell_v0_dispatch(uint64_t program_len, uint64_t witness_n)` is
symbolic in both arguments (not a closed witness). Both legs return the packed
`(result, error_ordinal)` pair:

| program_len | witness_n | result, error |
|---:|---:|---|
| 32 | 0 | (0, 39) WITNESS_PROGRAM_WITNESS_EMPTY |
| 32 | > 0 | (1, 0) under hash/exec abstraction |
| 20 | != 2 | (0, 40) WITNESS_PROGRAM_MISMATCH |
| 20 | 2 | (1, 0) under implied-script abstraction |
| other | any | (0, 38) WITNESS_PROGRAM_WRONG_LENGTH |

Alive2 compares the two IR modules directly; SAW verifies each module against
the same Cryptol function `v0_dispatch`. Both directions (`L ⊑ C`, `C ⊑ L`)
are therefore the same equality.

## What is not proved

- `SHA256(witnessScript) == program` — no hash model (SCR-133).
- `ExecuteWitnessScript`: item size, EvalScript loop, cleanstack, EVAL_FALSE,
  CHECKSIG (SCR-136, SCR-138).
- Any taproot/tapscript branch: annex, control block, leaf version,
  OP_SUCCESSx, validation weight, sigops.
- Whole `VerifyScript`/`VerifyWitnessProgram` ingestion by a tool.

The success rows in the table depend on the declared abstraction and must not
be read as hash or script-execution results.

## Exact commands

```sh
cells/e4-witness/C-L-witness-v0-dispatch/alive2/run.sh
cells/e4-witness/C-L-witness-v0-dispatch/saw/run.sh
```

No `make equiv`, no `make gate-ir-pin`, no commits.

## Raw results

`alive2/result.txt` and `saw/result.txt` hold the full tool output.
Certificates hash `spec.md`, the runners, both tool sources, the extracted
IR/BC, the Cryptol/SAW spec and the result.

Alive2 tail (2026-10-19):

```
Transformation seems to be correct!

Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

SAW tail (2026-10-19):

```
Verifying cell_v0_dispatch...
Simulating cell_v0_dispatch...
Checking proof obligations cell_v0_dispatch...
Proof succeeded! cell_v0_dispatch
Verifying cell_v0_dispatch...
Simulating cell_v0_dispatch...
Checking proof obligations cell_v0_dispatch...
Proof succeeded! cell_v0_dispatch
CELL_e4_witness_v0_dispatch_SAW_GREEN
STATUS=saw-green
```


## Proposed mutation (not executed)

`l_cell.cpp`: change `if (witness_n != 2) return {L_FAIL, 40};` in the
20-byte arm to `if (witness_n < 2) return {L_FAIL, 40};`. The unmutated pair
is green first; the mutant should fail at `program_len = 20,
witness_n = 3`. This is the dispatch analogue of the E1 gate mutation
discipline. It is recorded, not run, per the Task A rules.
