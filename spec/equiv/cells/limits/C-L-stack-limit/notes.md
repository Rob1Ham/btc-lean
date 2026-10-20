# notes — limits/C-L-stack-limit

## Design

Straight-line predicate over the post-opcode `(stack, altstack)` depths.

C leg: `interpreter.cpp:1231-1233`, the guard at the end of the opcode loop
body.  L leg: `Defs.lean:1131-1136`, `stepChecked`'s terminal guard
(`MAX_STACK_SIZE < st'.stack.length + st'.alt.length`), which is
structurally the same as `runtime.inc:642-643`.

Both depths are symbolic and bounded to [0,2000].  The payload is the exact
sum, so the altstack's contribution to the limit is part of the observable.

## Commands

```sh
bash spec/equiv/cells/limits/C-L-stack-limit/alive2/run.sh
bash spec/equiv/cells/limits/C-L-stack-limit/saw/run.sh
sha256sum -c spec/equiv/cells/limits/C-L-stack-limit/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/limits/C-L-stack-limit/saw/certificate.sha256
```

## Tool versions

- clang/clang++ 20.1.2, LLVM 20.1.2
- Alive2 v20.0 (LLVM 20 build)
- SAW 1.6 (solver `abc`)

## Limits / non-claims

- One step guard; multi-op accumulation is not modelled.  The row is the
  predicate and its per-op placement, not an opcode semantics proof.
- Depth is bounded at 2000 per stack so the sum is exact; the boundary and
  every rejecting pair inside [0,2000]^2 are covered.
- `MAX_STACK_SIZE` is 1000 for base, v0 and tapscript alike at the pin; the
  cell does not need a sigversion input.
- No crypto, no patch.

## Blockers

None.
