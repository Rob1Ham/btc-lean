# witness-v0/C-L-witness-v0-cleanstack

The rule SCR-138: witness scripts implicitly require a clean, true stack after
EvalScript (interpreter.cpp:1876-1879).

## Design

`cell_v0_cleanstack(stack_size, top_truthy)` returns

| stack_size | top_truthy | result |
|---:|---:|---|
| != 1 | any | (0, 30) SCRIPT_ERR_CLEANSTACK |
| 1 | 0 | (0, 2) SCRIPT_ERR_EVAL_FALSE |
| 1 | nonzero | (1, 0) |

The C leg is a line-cited excerpt of the tail of `ExecuteWitnessScript`; the L
leg is a reviewed transliteration of the `.ok st` branch of
`Bitcoin.Interpreter.executeWitnessScript`
(`spec/core/Bitcoin/Interpreter/Defs.lean:1207-1241`).

`stack_size` and `top_truthy` are inputs standing for the post-EvalScript stack:
the EvalScript call at interpreter.cpp:1874 is a precondition, not re-run.  In
SAW, `top_truthy` is a 1-bit variable lifted with `zext` (CastToBool's range);
Alive2 additionally sees the whole u64 domain, where any nonzero value is
truthy in both legs.

## Exact commands

```sh
bash spec/equiv/cells/witness-v0/C-L-witness-v0-cleanstack/alive2/run.sh
bash spec/equiv/cells/witness-v0/C-L-witness-v0-cleanstack/saw/run.sh
sha256sum -c spec/equiv/cells/witness-v0/C-L-witness-v0-cleanstack/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/witness-v0/C-L-witness-v0-cleanstack/saw/certificate.sha256
```

## Versions

Alive2 v20.0 (`/opt/equiv-tools/alive-tv-v20.0`, LLVM 20.1.2), SAW 1.6
(68eed5f, solver abc), clang 20.1.2.

## Result

- Alive2: `Transformation seems to be correct! (syntactically equal)`,
  `STATUS=alive2-green`.  clang normalized the two branch spellings to the same
  select chain.
- SAW: two `Proof succeeded!` (C and L), `STATUS=saw-green`.

## Limits / blockers

- EvalScript is not run; the cell proves the post-state rule conditioned on its
  success.
- `CastToBool` is not re-implemented (SCR-057); truthiness is the Boolean input.
- Because EvalScript is abstracted, this cell cannot be combined with the
  witness-program cells to claim an end-to-end spend.  SCR-138 is promoted only
  for the post-state rule as written.
