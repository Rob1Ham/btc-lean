# notes — limits/C-L-tapscript-precheck

## Design

ExecuteWitnessScript's tapscript prologue as a straight-line decision:

1. abstract OP_SUCCESSx scan (`has_success`), with DISCOURAGE_OP_SUCCESS;
2. `stack.size() > 1000 ⇒ STACK_SIZE` (main stack only, altstack empty);
3. item-size loop assumed satisfied (SCR-021);
4. EvalScript as an opaque outcome `inner_err`.

C leg cites `interpreter.cpp:1842-1874`.  L leg is the `executeWitnessScript`
definition at `Defs.lean:1207-1239`.  The generated twin has no witness
engine at the pin, so the Lean definition is the L source of record; this is
stated in `spec.md`.

The key property is placement: when `depth > 1000` and the sigversion is
TAPSCRIPT, the result is `STACK_SIZE` for every `inner_err`.  SAW quantifies
over the 8-bit ordinal and proves that universally.

## Commands

```sh
bash spec/equiv/cells/limits/C-L-tapscript-precheck/alive2/run.sh
bash spec/equiv/cells/limits/C-L-tapscript-precheck/saw/run.sh
sha256sum -c spec/equiv/cells/limits/C-L-tapscript-precheck/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/limits/C-L-tapscript-precheck/saw/certificate.sha256
```

## Tool versions

- clang/clang++ 20.1.2, LLVM 20.1.2
- Alive2 v20.0 (LLVM 20 build)
- SAW 1.6 (solver `abc`)

## Limits / non-claims

- The OP_SUCCESSx scan over script bytes is NOT modelled; `has_success` is an
  abstract boolean.  The scan itself is SCR-153.
- EvalScript is an opaque error ordinal; the cell claims the guard's
  placement, not EvalScript's semantics.
- The item-size loop is SCR-021 (separate cell, partial).
- Depth bounded at 2000 for the exact-sum domain.
- No crypto, no patch.

## Blockers

None.
