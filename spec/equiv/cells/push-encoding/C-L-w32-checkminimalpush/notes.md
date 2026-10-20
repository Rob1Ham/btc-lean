# C-L-w32-checkminimalpush

SCR-048 (canonical push opcode for each data length under `MINIMALDATA`),
implemented as one bounded decision-function cell with **both tools green**.
Alive2 compares C and L; SAW verifies both against an independent Cryptol
predicate.

## Source

Pinned Core `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`:

- `src/script/script.cpp:373-396` — `CheckMinimalPush(const valtype& data,
  opcodetype opcode)`: `n == 0` requires `OP_0`; `n == 1` with `0x01..0x10`
  or `0x81` is non-minimal; `2 <= n <= 75` requires the direct-push opcode
  `n`; `76 <= n <= 255` requires `OP_PUSHDATA1`; `256 <= n <= 65535` requires
  `OP_PUSHDATA2`; anything larger requires `OP_PUSHDATA4`.
- `src/script/interpreter.cpp:499-503` — the only call site: the function is
  reached only when `opcode <= OP_PUSHDATA4` (0x4e), under `fExec` and
  `fRequireMinimal`.

The function reads only `data.size()` and, when `n == 1`, `data[0]`; the C
slice is reduced to exactly those (`n`, `b0`) plus `opcode`. `uint64_t n`
and `uint8_t opcode` are used because the unsliced signatures are
`size_t`/`opcodetype`; the call-site domain constrains `opcode <= 0x4e`.

## L leg

`src/l_leaf.cpp` transcribes `Bitcoin/Interpreter/Defs.lean:529-537`
(`checkMinimalPush`) verbatim, branch order included, from the generated twin
`twin/runtime.inc:191-199` (`check_minimal_push`). The same read-set reduction
(`n`, `b0`) is applied; no handler semantics change.

## Symbolic claim

`cell_minpush(n, b0, opcode)` returns `1` iff `CheckMinimalPush` is true,
`0` otherwise. The SAW proof is over:

- `n`: all 64-bit values (every length class named by SCR-048: 0, 1,
  2..75, 76..255, 256..65535, >65535);
- `b0`: all bytes (the only first-byte classes the function reads:
  `0x01..0x10`, `0x81`, anything else);
- `opcode`: `0x00..0x4e` (the call-site domain), all 79 values.

Outside the call-site domain both legs return the sentinel `2`, and the SAW
precondition `op <= 0x4e` excludes it, so nothing is proved or assumed about
non-call-site opcodes.

## Commands

```sh
cd spec/equiv/cells/push-encoding
./C-L-w32-checkminimalpush/alive2/run.sh "$PWD/C-L-w32-checkminimalpush"
./C-L-w32-checkminimalpush/saw/run.sh    "$PWD/C-L-w32-checkminimalpush"
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
Verifying cell_minpush...
Checking proof obligations cell_minpush...
Proof succeeded! cell_minpush
Verifying cell_minpush...
Checking proof obligations cell_minpush...
Proof succeeded! cell_minpush
CELL_PUSH_MINPUSH_SAW_GREEN
STATUS=saw-green
```

## Notes and limits

- This cell proves the decision function, not its gate: the `fExec` /
  `fRequireMinimal` guard that decides whether Core calls it is SCR-049 and is
  covered by `C-L-w32-fexec-push`. `PUSH_SIZE` (SCR-020) runs before the
  call and is out of scope; hence the `n > 520` lengths are still in this
  function's mathematical domain and are proved, even though EvalScript
  rejects them earlier.
- The Cryptol predicate (`src/cell.cry`) is written from the row text and the
  function, independently of both C and L legs; it uses `(0:[56]) # op` for
  the direct-push comparison so the 64-bit length and 8-bit opcode compare at
  a common width.
- No Core patch is used (`patches: none`).
