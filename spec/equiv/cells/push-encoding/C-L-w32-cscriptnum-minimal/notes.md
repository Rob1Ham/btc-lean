# C-L-w32-cscriptnum-minimal

SCR-050 (CScriptNum minimality: `top byte & 0x7f == 0` requires size 1 or a
set high bit in the next byte, under `fRequireMinimal`), implemented as a
bounded decode cell with **both tools green**. Alive2 compares C and L; SAW
verifies both against an independent Cryptol decode predicate.

## Source

Pinned Core `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`:

- `src/script/script.h:246-268` — `CScriptNum(const std::vector<unsigned
  char>& vch, bool fRequireMinimal, size_t nMaxNumSize = 4)`: the
  `vch.size() > 4` overflow guard and the minimality guard
  `(vch.back() & 0x7f) == 0` =>
  `vch.size() <= 1 || (vch[vch.size()-2] & 0x80) == 0` is an error.
- `src/script/script.h:376-391` — `set_vch`: little-endian sign-magnitude,
  the top byte's `0x80` is the sign and is masked out of the magnitude.
- `src/script/interpreter.cpp:415-427` — `CScriptNum::getvch`, the inverse
  encoder, used to state the accepted value convention.

`EvalScript` maps `scriptnum_error` to `SCRIPT_ERR_SCRIPTNUM`. The C slice is
the decode primitive at `nMaxNumSize = 4` (the numeric-op default), with the
length loop unrolled over exact lengths 0..4 because the width guard rejects
anything longer.

## L leg

`src/l_leaf.cpp` transcribes `Numeric/Interface.lean:45-47`
(`decodeScriptNum`) as emitted by the generated twin
`twin/runtime.inc:165-185` (`decode_num`): same width guard, same minimality
guard, same sign-magnitude decode. The byte walk is written as exact-length
cases over the same 0..4 domain.

## Symbolic claim

`cell_cscriptnum(n, b0, b1, b2, b3, minimal)` returns the packed observable
`valid(1) | error(4) | low 32 bits of value at bit 6`, where:

- `minimal == 0`: every 0..4-byte payload decodes (`valid = 1`, `error = 0`);
- `minimal != 0`: the payload is rejected with `error = 4`
  (`SCRIPT_ERR_SCRIPTNUM`) iff `(b[n-1] & 0x7f) == 0` and
  (`n <= 1` or `(b[n-2] & 0x80) == 0`), else it decodes;
- the accepted value is the LE sign-magnitude number of `set_vch`, including
  `0x80` (negative zero) and the `0xff00`/`0xff80` (255 / -255) exceptions.

The SAW proof is over `n <= 4`, all four payload bytes, and both values of
`minimal`. `n > 4` is the width-guard path (SCR-079/SCR-080, separate) and is
the sentinel `error = 4` on both legs but outside the SAW precondition.

## Commands

```sh
cd spec/equiv/cells/push-encoding
./C-L-w32-cscriptnum-minimal/alive2/run.sh "$PWD/C-L-w32-cscriptnum-minimal"
./C-L-w32-cscriptnum-minimal/saw/run.sh    "$PWD/C-L-w32-cscriptnum-minimal"
```

## Raw tails

`alive2/result.txt`:

```text
Transformation seems to be correct!

Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

`saw/result.txt`:

```text
Verifying cell_cscriptnum...
Checking proof obligations cell_cscriptnum...
Proof succeeded! cell_cscriptnum
Verifying cell_cscriptnum...
Checking proof obligations cell_cscriptnum...
Proof succeeded! cell_cscriptnum
CELL_PUSH_CSCRIPTNUM_SAW_GREEN
STATUS=saw-green
```

(SAW also warns `Unused name: b3` in the Cryptol module; `b3` is still a
symbolic argument of the cell, and the predicate reads it through `valueOf`
for `n == 4`.)

## Notes and limits

- This is the decode/minimality primitive, not an opcode call site: no
  stack-underflow or opcode-specific path (SCR-081 and the numeric rows) is
  exercised.
- The Cryptol predicate (`src/cell.cry`) is an independent statement of the
  rule, not a transliteration of either leg. It needed `md` threaded through
  the predicate (the first attempt omitted the `fRequireMinimal` switch) and
  Cryptol `//` rather than `--` comments; both were tool/spec errors found
  while getting the proof, not semantic differences.
- No Core patch is used (`patches: none`).
