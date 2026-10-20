# C-L-w32-pushnum

SCR-046 (`OP_0 -> empty; OP_1..16 -> one byte 0x01..0x10`) and SCR-047
(`OP_1NEGATE -> 0x81`, no MINIMALDATA gate), implemented as one bounded
opcode cell with **both tools green**.

## Source

Pinned Core `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`:

- `interpreter.cpp:499-503` — OP_0 is `opcode <= OP_PUSHDATA4`, so it takes
  the pushdata branch and pushes the empty vector; the MINIMALDATA gate is
  `CheckMinimalPush(∅, 0)` which is true.
- `interpreter.cpp:415-427` — `CScriptNum::getvch`, canonical LE
  sign-magnitude.
- `interpreter.cpp:527-546` — `OP_1NEGATE` and `OP_1..OP_16`:
  `CScriptNum((int)opcode - (int)(OP_1 - 1)).getvch()`; `OP_1 - 1 == 0x50`.
- `interpreter.cpp:1876-1880` — the EVAL_FALSE tail.

## L leg

`src/l_leaf.cpp` transcribes `Defs.lean:836-846` (`stepBody` `.pushBytes` /
`.pushNum`), the OP_0/OP_1NEGATE/OP_n AST convention
(`Parser/Defs.lean:26-30, 200-221`), and `encodeScriptNum`
(`Numeric/Interface.lean:55-56`) via `twin/runtime.inc:159-163`, restricted
to the reachable values -1..16 and a two-element stack.

## Symbolic claim

`cell_pushnum(sel, minimalData)` with `sel = 0` (OP_0), `1` (OP_1NEGATE),
`2..17` (OP_1..OP_16), and `minimalData` symbolic:

| sel | stack element | final (EVAL_FALSE tail) |
|---|---|---|
| 0 | empty | false |
| 1 | `{0x81}` | true |
| 2..17 | `{sel-1}` | true |

Both legs return the same packed observable
(`res(2) | err(6) | depth(2) | len(2) | byte(8) | final(1)`) for every `sel`
and both MINIMALDATA values.

## Commands

```sh
cd spec/equiv/cells/push-encoding
./C-L-w32-pushnum/alive2/run.sh "$PWD/C-L-w32-pushnum"
./C-L-w32-pushnum/saw/run.sh    "$PWD/C-L-w32-pushnum"
```

## Raw tails

```text
Transformation seems to be correct!
  1 correct transformations
  0 incorrect transformations
STATUS=alive2-green
```

```text
Proof succeeded! cell_pushnum
Proof succeeded! cell_pushnum
CELL_PUSH_PUSHNUM_SAW_GREEN
STATUS=saw-green
```

## Notes and limits

- The OP_0 push and the OP_1NEGATE/OP_n switch are separate Core paths; the
  cell keeps them separate and only shares the harness.
- The MINIMALDATA bit is symbolic and provably ignored on these paths,
  which is the SCR-047 "no MINIMALDATA gate" claim.
- No Core patch is used (`patches: none`).
