# C-L-w32-fexec-push

SCR-049 (`fExec`-gated: an unexecuted non-minimal push is not an error),
implemented as a bounded fixed-script executor cell with **both tools
green**. Alive2 compares C and L; SAW verifies both against independent
packed constants.

## Source

Pinned Core `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`:

- `src/script/interpreter.cpp:476-503` — the EvalScript loop order:
  `GetOp`, element-size check, op budget, disabled opcodes,
  `CONST_SCRIPTCODE`, then the
  `if (fExec && opcode <= OP_PUSHDATA4)` push branch. The `MINIMALDATA` gate
  is `if (fRequireMinimal && !CheckMinimalPush(...))`; an unexecuted push is
  skipped by the branch and never reaches the gate.
- `src/script/interpreter.cpp:613-661` — `OP_IF`/`OP_NOTIF`/`OP_ENDIF`: an
  unexecuted `OP_IF` pushes `false`; `OP_ENDIF` pops and checks balance.
- `src/script/interpreter.cpp:527-546` — `OP_1` (`CScriptNum(1).getvch()`).
- `src/script/script.cpp:373-396` — `CheckMinimalPush`.
- `src/script/interpreter.cpp:1876-1880` — the `EVAL_FALSE` tail.

Fixed script (6 bytes), so the loop is unrolled exactly six times:

| offset | bytes | meaning |
|---|---|---|
| 0 | `0x00` / `0x51` | `OP_0` (false) / `OP_1` (true) |
| 1 | `0x63` | `OP_IF` |
| 2..3 | `0x01 0x01` | direct push of `{1}` — **non-minimal** |
| 4 | `0x68` | `OP_ENDIF` |
| 5 | `0x51` | `OP_1` |

## L leg

`src/l_leaf.cpp` transcribes the `stepBody` order from
`Bitcoin/Interpreter/Defs.lean:816-846` (element size, op budget, disabled,
`CONST_SCRIPTCODE`, `.pushBytes`/`.pushNum` with the `fExec` skip and the
`minimalData` gate) and the `OP_IF`/`OP_NOTIF`/`OP_ENDIF` semantics from
`Defs.lean:878-900`, following the generated twin `twin/runtime.inc:607-640`
(loop shape). It is a bounded transcription for this fixed script, not a
general EvalScript loop.

## Symbolic claim

Only `minimalData` is symbolic. Two entry points:

- `cell_fexec_false(minimalData)` — script starts with `OP_0`: `OP_IF` is not
  taken, the non-minimal push is never executed, and the script passes with
  stack `[{1}]` (`res = 1`, `err = 0`, depth 1, top len 1, byte 1) for every
  `minimalData`.
- `cell_fexec_true(minimalData)` — script starts with `OP_1`: `OP_IF` is
  taken, the push is executed, and
  - `minimalData == 0` -> accepted, stack `[{1},{1}]`, `res = 1`, `err = 0`;
  - `minimalData != 0` -> `SCRIPT_ERR_MINIMALDATA` (25), `res = 0`.

Both legs must return the same packed
`res(2) | err(6) | depth(2) | top len(2) | top byte(8)` for every
`minimalData`. This is the row's claim exactly: the same non-minimal push is
harmless when unexecuted and an error when executed.

## Commands

```sh
cd spec/equiv/cells/push-encoding
./C-L-w32-fexec-push/alive2/run.sh "$PWD/C-L-w32-fexec-push"
./C-L-w32-fexec-push/saw/run.sh    "$PWD/C-L-w32-fexec-push"
```

## Raw tails

`alive2/result.txt` (two functions):

```text
Transformation seems to be correct!

Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

`saw/result.txt` (four proofs: both legs x both scripts):

```text
Proof succeeded! cell_fexec_false
Proof succeeded! cell_fexec_false
Proof succeeded! cell_fexec_true
Proof succeeded! cell_fexec_true
CELL_PUSH_FEXEC_SAW_GREEN
STATUS=saw-green
```

## Notes and limits

- The first attempt was red: the L `get` did not handle `OP_1` and the
  unrolled executor ran one step too many for the 6-byte script. Fixed to
  handle `.pushNum` and to five `step` calls (offsets 0..5); recorded here,
  not hidden.
- The script derives `fExec` by executing `OP_0`/`OP_1` and `OP_IF`, rather
  than assuming a bit. Other `fExec` constructions (`ELSE`, nested `IF`,
  `NOTIF`) and multi-byte payloads are not covered; those are wider E2/E5
  work, not part of this row's fixed premise.
- The executor is a six-step unrolled slice with a <=1-byte element domain;
  it is not a general EvalScript loop proof. No Core patch is used
  (`patches: none`).
