# notes — limits/C-L-opcount

## Design

One `stepBody` step, before dispatch.  Inputs: incoming `nOpCount` (u32,
domain [0,202]), opcode byte, `fExec`, sigversion.

C leg: `interpreter.cpp:441` (the `int nOpCount` local), `:460-465` (the
BASE/WITNESS_V0 budget block), `:467-482` (the disabled table).  The order is
literal: charge and budget check first, disabled second.

L leg: `Defs.lean:826-833` of `stepBody`, which is a three-line transliteration
of the same order, plus `disabledWire` at `:455-457`.  The generated twin's
`runtime.inc:607-614` is structurally the same, so the transliteration is
reviewable against both.

`fExec` is a free input that the model never reads before the budget/disabled
steps.  The payload reports both the charged count and fExec so the
flow-insensitivity claim is observable in the proof, not an artifact of the
input being dead.

## Commands

```sh
bash spec/equiv/cells/limits/C-L-opcount/alive2/run.sh
bash spec/equiv/cells/limits/C-L-opcount/saw/run.sh
sha256sum -c spec/equiv/cells/limits/C-L-opcount/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/limits/C-L-opcount/saw/certificate.sha256
```

## Tool versions

- clang/clang++ 20.1.2, LLVM 20.1.2
- Alive2 v20.0 (LLVM 20 build)
- SAW 1.6 (solver `abc`)

## Limits / non-claims

- The cell starts at a decoded opcode and ends at the dispatch entry.  It
  does not model `script.GetOp`, the opcode switch, or any opcode's stack
  effects.  Those are not part of SCR-022..025.
- `nOpCount` is restricted to [0,202]; above that Core's signed `int`
  increment leaves the domain this row reasons about.
- OP_CODESEPARATOR / CONST_SCRIPTCODE is out of the domain (flags = 0).
- The CMS `nOpCount += nKeysCount` path (`interpreter.cpp:1127-1128`,
  SCR-026/028) is a different row and is not exercised.
- No crypto, no patch.

## Blockers

None.
