# numeric/C-L-binary-4byte

SCR-088 (`ADD/SUB/BOOLAND/BOOLOR/NUMEQUAL/NUMNOTEQUAL/LE/GE/LT/GT/MIN/MAX`)
and SCR-090 (`false ⇒ NUMEQUALVERIFY error`), a bounded op cell with **both
tools green** symbolically over the full 4-byte operand domain plus the width
reject edge.

## Source

- `interpreter.cpp:955-1010` — `case OP_ADD` … `case OP_MAX`: pop two
  operands, `CScriptNum bn1(stacktop(-2), fRequireMinimal)` and
  `bn2(stacktop(-1), ...)`, apply the operation, `push_back(bn.getvch())`.
- `interpreter.cpp:1002-1008` — `OP_NUMEQUALVERIFY`:
  `if (CastToBool(stacktop(-1))) popstack(stack); else return
  set_error(serror, SCRIPT_ERR_NUMEQUALVERIFY);`
- `script.h:246-271`, `script.h:342-373` — CScriptNum decode / serialize.
- `interpreter.cpp:1877-1878` — VerifyScript tail (`EVAL_FALSE`).

## Entry points

```c
uint64_t cell_add(uint32_t wa, uint32_t la, uint32_t wb, uint32_t lb);
// ... one per wire: sub, booland, boolor, numequal, numequalverify,
// numnotequal, lessthan, greaterthan, lessthanorequal,
// greaterthanorequal, min, max
```

The entry stack is exactly `[a, b]`; the tail observes the pushed result.

## Symbolic claim

- Alive2: 13 entry points, 13/13 `correct transformations`.
  `add` and `sub` need a larger solver budget than Alive2's 120 s default
  (`SMT_TO=600000`, ~2.5 min each); the other eleven close in seconds.
- SAW: 26/26 `Proof succeeded` (13 entry points × C, L) against
  `tools/num.cry:pBinary` for every `(wa, la, wb, lb)`.

## Build and tool pipeline (shared by the numeric cells)

1. `src/build.sh` emits `build/twin_ops.h` via
   `tools/mk_num_leaf.py`, which reuses `cells/_tools/mk_leaf.py` for the
   handler table and substitutes six bounded runtime primitives from
   `twin/runtime.inc`, unrolled to an 8-byte element.  Every handler body is
   asserted byte-identical to `mk_leaf`'s output; `disabled_wire` is appended
   verbatim from `runtime.inc`.
2. Both legs are compiled with `clang++-20 -O2 -fno-jump-tables
   -fno-strict-aliasing -S -emit-llvm`, then `llvm-extract --func --recursive`.
3. `opt -passes='default<O2>'` runs on the extracted module, **identically on
   both legs**.  Without it Alive2 must reason about the twin `State`'s
   dynamically indexed 200-byte alloca (it needs the block-address
   quantifier); after it, `grep -c alloca build/*_cell_*.ll` is 0 in every
   cell.  This is a tool-ingestion normalisation, not a semantic change.
4. `tools/expand_abs.py` expands `llvm.abs` and `llvm.{smin,smax,umin,umax}`
   into their own definitions (poison-faithful for `abs`).  Alive2 v20 reports
   modules that both contain `llvm.abs` as miscompiles, and it cannot reduce
   the min/max intrinsics; the expansion is applied identically to both legs
   and the script fails if any of them survives.
5. **No variable-index scratch buffer.**  Core's `serialize` writes `out[n++]`
   and reads `out[n-1]`; a bounded copy with that shape keeps the scratch
   array in memory and turns Alive2's UB query into a `forall` over block
   addresses, which times out.  `encode_num` assembles the same bytes in a
   little-endian `uint64`, so every access is constant-indexed.  The bytes are
   identical (checked against the C leg).
6. SAW 1.6 uses `z3`, not `abc`: `abc` never finished `cell_1sub`, `z3`
   proves it in about five seconds.  Cryptol literals take their width from
   the digit count, so every `[64]` literal is written with 16 hex digits, and
   `||` binds tighter than `==`, so comparisons are parenthesised.

## Numeric specifics

- The harness element is 8 bytes because `OP_ADD` of two 4-byte operands can
  push 5 bytes.  Depth 4 because `WITHIN` needs three operands.
- Only the first five bytes of the top element are packed into the observable.
  No numeric opcode pushes more than five bytes, so the truncation is
  observable only on an untouched input element (the EQUAL cell, which does
  compare 8-byte elements, packs all eight in its own cell record).
- After an error the observable carries no stack, so Core's
  "push the bool, then fail" in `OP_NUMEQUALVERIFY` and the twin's
  early return are both `(0, 15)`; the stack contents are not part of the
  contract once the script has failed.
