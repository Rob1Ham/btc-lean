# limits/C-L-witness-sigop-dispatch

SCR-035: the WitnessSigOps version/length dispatch, both tools green.

## Source (pin cce32b168)

- `src/script/interpreter.cpp:2133-2147` — `WitnessSigOps`:
  v0-20 -> 1; v0-32 with a non-empty witness stack -> accurate
  `GetSigOpCount(true)` of `witness.stack.back()`; every other version/length
  -> 0.
- `spec/core/Bitcoin/Interpreter/SigOps.lean` — `witnessSigOps` (SWT-025/026/
  028), same arms.

## Model

Inputs: the witness version, the witness-program length, whether the witness
stack is non-empty, and the accurate count of the last item. The accurate
count is an input; it is proved for the per-site rule by
`limits/C-L-sigop-site-weights`. L is a reviewed transliteration of the Lean
`witnessSigOps`.

## Symbolic claim

- Alive2: equality for every i8 version, i32 length, i8 emptiness and i32
  count.
- SAW: both modules against `witness_sigops` in `src/cell.cry`.

## Commands

```sh
bash spec/equiv/cells/limits/C-L-witness-sigop-dispatch/alive2/run.sh
bash spec/equiv/cells/limits/C-L-witness-sigop-dispatch/saw/run.sh
```

## Limits

- IsWitnessProgram classification is upstream and not part of SCR-035.
- The accurate count of the witnessScript is proved elsewhere; the cell proves
  which count is selected.
- No Core patch.
