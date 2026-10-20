# locktime/C-L-csv-op — notes

OP_CHECKSEQUENCEVERIFY, rows SCR-126..SCR-130, both tools green.

## Commands

```sh
cd /tmp/opencode/wave16/12-locktime
bash spec/equiv/cells/locktime/C-L-csv-op/alive2/run.sh
bash spec/equiv/cells/locktime/C-L-csv-op/saw/run.sh
sha256sum -c spec/equiv/cells/locktime/C-L-csv-op/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/locktime/C-L-csv-op/saw/certificate.sha256
```

Tools: Alive2 v20.0 (LLVM 20.1.2), SAW 1.6 (`68eed5f`), clang++-20 20.1.2.

## Source and elisions

The C leg keeps the `OP_CHECKSEQUENCEVERIFY` case body and `CheckSequence`
**verbatim** from the pin. Three text-level deviations, all stated in
`spec.md`:

1. `interpreter.cpp:575-577` (`stack.size() < 1`) is elided — one operand in
   the domain, so the guard is statically false (SCR-051's row).
2. `interpreter.cpp:586-587` (`CScriptNum nSequence(stacktop(-1),
   fRequireMinimal, 5)`) is elided — the operand arrives decoded
   (SCR-051/052's rows).
3. `break` (NOP / continue) is spelled `return true`, with the ScriptError as
   the observable.

## L-leg provenance

`src/l_leaf.cpp` transliterates `Defs.lean:285-297` (`checkSequenceDef`) and
`Defs.lean:866-875` (`dispatchOp` wire `0xb2`); the reviewed mapping is in
`src/lean_excerpt.md`. Again, this is the Lean model of record, not the
generated twin (`twin/ops_ir.py:53-58` returns `TWIN_INVALID_UNSUPPORTED` on
the flag-on path because the twin handler has no transaction context) —
finding F-LOCKTIME-001.

## Details that matter for fidelity

- **`txTo->version` is `uint32_t`** at the pin (`primitives/transaction.h:299`),
  so `if (txTo->version < 2)` is unsigned.  The Lean model's
  `env.txVersion.toUInt32 < 2` is the same comparison; a slice that modelled
  the field as `int32_t` would diverge on version values with bit 31 set.  The
  cell models `uint32_t` and the symbolic domain covers that edge (e.g.
  `0x80000000 >= 2` → the version gate passes on both legs).
- **The operand disable bit is tested on the operand, the disable bit in
  `CheckSequence` on the transaction.**  Two different checks with the same
  constant; both are in the cell (SCR-127 and SCR-129 respectively).
- **Masking.**  `nLockTimeMask` is `TYPE_FLAG | MASK = 0x0040ffff`.  The
  comparison is `CScriptNum(nSequence & mask) > (int64_t)(txSeq & mask)`, i.e.
  raw masked values with no granularity scaling — see
  `locktime/C-L-csv-granularity` for the SCR-131 split.
- `n.toNat &&& mask` in Lean is only defined-looking for `n >= 0`; the opcode
  rejects `n < 0` first, so the transliteration's `static_cast<uint32_t>(n)`
  is only reached with `n >= 0`.

## What the proofs say

- Alive2: `alive-tv build/c_cell_csv.ll build/l_cell_csv.ll` —
  "Transformation seems to be correct!", 1 correct / 0 incorrect.
- SAW: `llvm_verify` of both `cell_csv` definitions against `src/cell.cry`
  (independent Cryptol predicate) over
  `(i64 operand, i1 flag, i32 version, i32 nSequence)`.

The `and` that clang forms from the version gate and the tx disable bit is
sound: both branches return the same ordinal (22), and the DeadSpy/opt
combination cannot merge them with the accept path.

## Why the rows are full

SCR-126..130 are exactly the decision points of the CSV path (activation is
not a row).  The cell quantifies over every field they read and both tools
prove all branches, including the two NOP paths (activation clear and operand
disable bit) and the two transaction-side gates.  SCR-131 (granularity split)
and SCR-132 (per-input) are separate rows with separate cells.
