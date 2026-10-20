# e2-numeric/C-L-w32-disabled-2div

SCR-092 (`0x8e is OP_2DIV; legacy/witness-v0 disabled, tapscript
OP_SUCCESS142`), both tools green.

## Source

Pinned Core `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`:

- `src/script/script.h:155-156` — `OP_2MUL = 0x8d`, `OP_2DIV = 0x8e`; there
  is no `OP_NOTEQUAL`.
- `src/script/interpreter.cpp:443-467` — `EvalScript` prologue; the disabled
  list (including `OP_2DIV`) is checked **before** `fExec`, so unexecuted
  branches are rejected too.
- `src/script/interpreter.cpp:1846-1862` — `ExecuteWitnessScript`'s tapscript
  OP_SUCCESS pre-scan, which runs before stack/item-size checks.
- `src/script/script.cpp:365-371` — `IsOpSuccess`; 141..142 includes 0x8e.
- `src/script/interpreter.cpp:70` — `SCRIPT_ERR_DISCOURAGE_OP_SUCCESS`.

## L leg

`src/ops.txt` is empty: this cell is **not** a `twin/ops_ir.py` handler. The
twin runtime applies `disabled_wire` under every sigversion
(`twin/runtime.inc:613-614`) and has no tapscript OP_SUCCESS pre-scan, so a
verbatim twin handler would be the wrong model. `src/l_leaf.cpp` is a reviewed
transliteration of Lean `Defs.lean:455-492` (`disabledWire`,
`isOpSuccessWire`, `opSuccessScanFrom`), `:815-845` (`stepBody` check 3) and
`:1211-1216` (`executeWitnessScript` tapscript branch), plus `getOp` from
`Script/Parser/Defs.lean:206-229`. It is bounded to a two-byte script and
loop-free.

## Symbolic claim

- `cell_base(fexec)` / `cell_witness_v0(fexec)`: error 17 for every `fexec`;
  the disabled check does not depend on the executed state.
- `cell_tapscript(b0, b1, discourage)`: faithful GetOp + OP_SUCCESS pre-scan
  over `[b0, b1]`. A decoded 0x8e (or any success wire) gives success with an
  empty stack, or error 36 when `discourage != 0`. If no success opcode is
  decoded (0x8e was push data, or a truncated push fails), the cell returns
  the harness sentinel result=3, error=1; the remainder of tapscript
  execution is outside the cell.

Alive2 checks both directions for all three entry points; SAW verifies both
legs against the independent Cryptol predicate. Solver: `z3`.

## Commands

```sh
./spec/equiv/cells/e2-numeric/C-L-w32-disabled-2div/alive2/run.sh
./spec/equiv/cells/e2-numeric/C-L-w32-disabled-2div/saw/run.sh
```

## Raw outcomes

- `alive2/result.txt`: three green checks, `STATUS=alive2-green`.
- `saw/result.txt`: 6 `Proof succeeded!` lines, `STATUS=saw-green`.

## Notes

- The predicates are marked `always_inline`. With internal calls left in the
  extracted IR, Alive2 reported spurious UB ("source is more defined than
  target") on the helper call even for defined arguments; inlining removes the
  call and the checks are exact. This is a tool modelling artifact, not a
  semantics change.
- Negative-pre-scan script validation and scripts longer than two bytes are
  outside this cell; the SCR-092 edges (disabled in legacy/witness-v0,
  OP_SUCCESS142 in tapscript, discourage arm) are all covered.
