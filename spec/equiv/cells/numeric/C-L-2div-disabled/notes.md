# numeric/C-L-2div-disabled

SCR-092 (`0x8e is OP_2DIV (no OP_NOTEQUAL opcode exists); legacy and
witness-v0 execution reject it as a disabled opcode, and tapscript treats it
as OP_SUCCESS142`).

## What is proved, and what is not

| edge | claim | tool | status |
|---|---|---|---|
| 0x8e in BASE | `DISABLED_OPCODE` (17) | Alive2 (C vs L) + SAW (both vs model) | green |
| 0x8e in WITNESS_V0 | `DISABLED_OPCODE` (17) | same gate function (sigversion independent) | green |
| whole disabled table (15 wires) | only these wires are rejected at the gate | Alive2 + SAW, all 2^32 wire words | green |
| 0x8e in TAPSCRIPT | `IsOpSuccess(0x8e)` → terminal success | SAW (C vs model only) | green |
| whole OP_SUCCESS table | exactly the BIP342 set succeeds | SAW (C vs model only) | green |
| tapscript **C vs L** | pre-pass equivalence | — | **gap (E4)** |

The gate itself is not filtered by sigversion in Core: `interpreter.cpp:471-489`
is a plain disjunction that runs before the opcode switch, so EvalScript
rejects 0x8e in every sigversion it executes.  The tapscript difference comes
from `ExecuteWitnessScript`'s pre-pass (`interpreter.cpp:1841-1862`), which
walks the raw script and calls `set_success` as soon as it decodes an
`IsOpSuccess` wire — before EvalScript is called.  Because every disabled wire
is also an OP_SUCCESS wire, tapscript never reaches the disabled check for
them (the Lean side calls this `disabledWire_success`, TPR-074).

The twin has no tapscript engine.  `twin/generator.md:409` records
"witness v0/v1 execution, taproot key/script path, tapscript ⇒ E4; result 3",
and `runtime.inc:781` (`verify_script_full`) contains no OP_SUCCESSx pre-pass;
its `disabled_wire` check at `runtime.inc:613-614` is unconditional, matching
EvalScript and not ExecuteWitnessScript.  So the C-vs-L edge for tapscript
does not exist yet.  The cell therefore proves the tapscript table on the C
leg against the independent model and records the exact remaining gap rather
than weakening the L leg or writing the missing twin code into the cell.

## Source

- `interpreter.cpp:471-489` — the disabled-opcode disjunction
  (`OP_CAT` … `OP_RSHIFT`), returning `SCRIPT_ERR_DISABLED_OPCODE`
  (CVE-2010-5137).
- `script.cpp:365-371` — `IsOpSuccess`: 80, 98, 126-129, 131-134, 137-138,
  141-142, 149-153, 187-254.
- `interpreter.cpp:1841-1862` — `ExecuteWitnessScript`, tapscript pre-pass.
- `script.h:155-156` — `OP_2MUL = 0x8d`, `OP_2DIV = 0x8e`.
- `interpreter.cpp:897-923` — the only place a `NOTEQUAL` name appears is the
  commented-out `case OP_NOTEQUAL` at 907-911; the live opcode is
  `OP_NUMNOTEQUAL = 0x9e` (covered by `C-L-binary-4byte`).

## Entry points

```c
uint64_t cell_gate(uint32_t wire);      // C and L
uint64_t cell_tap_scan(uint32_t wire);  // C only
```

`cell_gate` returns a two-field observation: `result(2) | error(6) << 2`, with
result tags 0 = terminal error, 1 = terminal success, 2 = no terminal decision
at this layer.  `cell_tap_scan` uses the same packing.

## Claim

- Alive2: `cell_gate`, 1/1 `correct transformations` (C vs L).
- SAW: 3/3 `Proof succeeded` —
  `pGate` for C and L, `pTapScan` for C — over the whole 32-bit wire word.

## Build note

`src/build.cfg` sets `LFNS=(cell_gate)`: the L module defines no
`cell_tap_scan`, and `src/build.sh` extracts per leg from `FNS` (C) and
`LFNS` (L).  `OPS` selects `OP_EQUAL` only because `mk_leaf` treats an empty
selection as "all handlers" (and that full header does not compile
standalone); nothing in the cell calls it.
