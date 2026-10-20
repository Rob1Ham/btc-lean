# C-L-w32-push-parse

SCR-045 (`pushdata1/2/4` length parsing; truncation => false => BAD_OPCODE),
implemented as a bounded parser cell with **both tools green**. Alive2
compares C and L; SAW verifies both against an independent Cryptol parser.

## Source

Pinned Core `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`:

- `src/script/script.cpp:313-363` — `GetScriptOp`: the `opcode < OP_PUSHDATA1`
  / `== OP_PUSHDATA1` / `== OP_PUSHDATA2` / `== OP_PUSHDATA4` arms, the
  `end - pc < 1/2/4` prefix checks, and the final `(unsigned)(end - pc) <
  nSize` truncation check.
- `src/script/interpreter.cpp:487-488` — a failed `GetOp` in the EvalScript
  loop sets `SCRIPT_ERR_BAD_OPCODE`.

## L leg

`src/l_leaf.cpp` transcribes `Bitcoin/Script/Parser/Defs.lean:206-229`
(`getOpAux` / `getOp`) and `twin/runtime.inc:242-283` (`decode_op`) at offset
0. Both legs are single-opcode scripts, so the all-or-nothing `parseWire`
order (F-DIV-001) is out of scope.

## Symbolic claim

The entry points take the eight script bytes and the valid length
`n <= 8`. Two observables:

- `cell_parse_meta(n, b0..b7)`: `res(2) | err(6) | wire(8) | dlen(16) |
  next(16)`. Failure is `res=0, err=16` (BAD_OPCODE).
- `cell_parse_payload(n, b0..b7)`: the eight payload lanes.

Because `n <= 8`, every successfully parsed `PUSHDATA1/2/4` payload is at
most 7 bytes, so the payload sink is exact. Larger scripts are not in this
cell's domain; the length decision (`k <= n - prefix`) is symbolic over all
32-bit `k`, including the truncation direction.

## Commands

```sh
cd spec/equiv/cells/push-encoding
./C-L-w32-push-parse/alive2/run.sh "$PWD/C-L-w32-push-parse"
./C-L-w32-push-parse/saw/run.sh    "$PWD/C-L-w32-push-parse"
```

## Raw tails

`alive2/result.txt` (two commands, meta then payload):

```text
Transformation seems to be correct!
...
  1 correct transformations
  0 incorrect transformations
...
STATUS=alive2-green
```

`saw/result.txt`:

```text
Proof succeeded! cell_parse_meta
Proof succeeded! cell_parse_meta
Proof succeeded! cell_parse_payload
Proof succeeded! cell_parse_payload
CELL_PUSH_PARSE_SAW_GREEN
STATUS=saw-green
```

## Notes and limits

- The first Alive2 attempt found a real C-slice bug (a non-push opcode
  reported `next = 0`); fixed to `next = pc`. The second found a real Cryptol
  spec bug (32-bit `5 + k` overflow in the PUSHDATA4 bound); fixed to
  `k <= n - 5`. Both are recorded here, not hidden.
- A compiler-generated switch table in the L module caused an Alive2
  "poison" report (globals present on one side only); the width is now
  computed arithmetically. This is an Alive2 globals limitation, not a
  semantic divergence.
- No Core patch is used (`patches: none`).
