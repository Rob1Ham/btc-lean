# C-L-w32-p2sh-pushonly — notes

## Why a decoded-opcode domain

SCR-006 is the P2SH-arm `IsPushOnly` gate (interpreter.cpp:2065-2066).  The
row is about the classification and its placement, not about `GetOp`.  The
cell therefore takes the scriptSig as a decoded opcode list with symbolic wire
bytes and proves the total gate function:

- every wire `<= 0x60` (OP_16) is push-only,
- any wire `> 0x60` is not,
- the gate only exists under the P2SH flag.

The parser arm is the F-DIV-001 seam (Core `GetOp` failure -> `IsPushOnly`
returns false -> SIG_PUSHONLY; Lean `parseWire = none` -> BAD_OPCODE).  That
divergence is pre-existing and is not re-opened here.

## Why the L leg is a transliteration

The generated twin has a `classify_push_only` parser of its own, but the row
is stated over the Lean model (`isPushOnlyWire`, `p2shInner`), so the L leg is
a reviewed manual transliteration of those definitions (same convention as
`e4-witness/C-L-witness-v0-dispatch`).  It is not generated from `ops_ir.py`.

## Tool notes

- clang++-20 `-O1`, `llvm-extract --func=... --recursive`, Alive2 v20.
- SAW 1.6, solver z3 (recorded in `saw/solver.txt`); `abc` also discharges
  this one, z3 is used for uniformity across the four wave-32 cells.
- The observable packing is harness, not engine semantics, and is stated
  identically in `x_common.h` and `saw/cell.cry`.

## What a reviewer should check

1. The C excerpt's `n > 0/1/2` guards and the `0x60` comparison against
   `script.cpp:266-282`.
2. That `n_ops` is masked to a byte before the clamp (`n_ops & 0xff`), which
   the Cryptol spec mirrors (`% 256` then clamp).  An earlier spec revision
   clamped the full 64-bit value and SAW produced the counterexample — fixed.
3. That the result `1` means "the gate passed", not "the script is valid".
