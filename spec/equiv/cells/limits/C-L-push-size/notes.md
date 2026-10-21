# notes — limits/C-L-push-size

## Design

Both legs are straight-line functions over `(dlen: u16, fExec: u8, kind: u8)`.
The C leg is Core `interpreter.cpp:455-458` (the check immediately after
`GetOp`) plus the `:488-493` push condition.  The L leg is Lean `stepBody`'s
`sizeOk` (`Defs.lean:817-826`), which computes the predicate from `op.ast`
alone, and is structurally identical to `runtime.inc:603-606` in the
generated twin.

`kind` abstracts a successfully decoded instruction: 0 = `.pushBytes d`
(`dlen = d.size`), 1 = `.pushNum` (empty push value), 2 = `.op` (empty push
value).  This is exactly the three Lean `op.ast` cases that the size predicate
distinguishes.

The payload is the post-step push depth.  It is 1 only when a push executes,
so a divergence in where the check sits relative to `fExec` would change the
observable, not just the error.

## Commands

```sh
bash spec/equiv/cells/limits/C-L-push-size/alive2/run.sh
bash spec/equiv/cells/limits/C-L-push-size/saw/run.sh
sha256sum -c spec/equiv/cells/limits/C-L-push-size/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/limits/C-L-push-size/saw/certificate.sha256
```

## Tool versions

- clang/clang++ 20.1.2, LLVM 20.1.2
- Alive2 v20.0 (LLVM 20 build)
- SAW 1.6 (solver `abc`)

## Limits / non-claims

- GetOp itself is not modelled; the cell starts from a decoded instruction.
  Truncated PUSHDATA tails (F-DIV-001) are outside the domain.
- `dlen` is 16-bit because that is the cell's bounded domain; a real
  PUSHDATA4 length is 32-bit.  The predicate only compares against 520, and
  every value above 520 behaves identically, so the 16-bit domain covers the
  whole decision.  The spec states the domain.
- One instruction only; no opcode-budget or stack-limit interaction.
- No crypto, no patch.

## Blockers

None.
