# notes — limits/C-L-witness-push-size

## Status

Tool-green on both legs, **row coverage partial**.  This cell must not be
used to promote SCR-021; it is filed as partial in `spec.md`.

## Design

ExecuteWitnessScript's witness-stack checks, as a straight-line decision:

1. tapscript OP_SUCCESSx outcome (`has_success`), with DISCOURAGE_OP_SUCCESS;
2. tapscript initial-stack guard (SCR-031, `depth > 1000`);
3. item-size loop: `any item.size() > 520` ≡ `max_item > 520`.

C leg cites `interpreter.cpp:1844-1871`; L leg is the
`executeWitnessScript` definition at `Defs.lean:1207-1239`.  The generated
twin has no witness engine at the pin (`runtime.inc` returns
`TWIN_INVALID_UNSUPPORTED` on the witness path), so the Lean definition is
the L source of record.

## Exact missing feature for full SCR-021

`opSuccessScan exec` is a real scan over the tapscript bytes:

```
while (pc < exec_script.end()) { GetOp(pc, opcode); if (IsOpSuccess(opcode)) ... }
```

with an early success return.  Deciding it symbolically needs the parser loop
plus the `IsOpSuccess` set, i.e. the same feature that blocks SCR-153.  This
cell therefore takes the scan's outcome as a Boolean input and proves only the
ordering after it.  The item-size predicate itself (including the
base/v0 and tapscript-without-OP_SUCCESSx cases) is fully symbolic.

## Commands

```sh
bash spec/equiv/cells/limits/C-L-witness-push-size/alive2/run.sh
bash spec/equiv/cells/limits/C-L-witness-push-size/saw/run.sh
sha256sum -c spec/equiv/cells/limits/C-L-witness-push-size/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/limits/C-L-witness-push-size/saw/certificate.sha256
```

## Tool versions

- clang/clang++ 20.1.2, LLVM 20.1.2
- Alive2 v20.0 (LLVM 20 build)
- SAW 1.6 (solver `abc`)

## Limits / non-claims

- OP_SUCCESSx scan abstracted (the partial-coverage gap; SCR-153).
- EvalScript and the implicit witness cleanstack are outside the cell.
- `max_item` is 16-bit; the predicate compares against 520, so the decision
  is covered for every representable size.
- No crypto, no patch.

## Blockers

No tool blocker.  The remaining gap is semantic/modelling: a symbolic
OP_SUCCESSx scan over script bytes (one-byte bounded script would still not
generalize to multi-op scripts).
