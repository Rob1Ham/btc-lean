# tapscript/C-L-w32-op-success-prescan

Bounded proof of the TAPSCRIPT OP_SUCCESSx pre-scan (SCR-153) and its policy
failure (SCR-154), plus the ordering it creates: OP_SUCCESSx beats the initial
stack-size check, the 520-byte item check and the whole EvalScript tail.

## Two functions

- `cell_scan_finds_success(len, b0..b3)` — Core's `while (pc < end)` scan of
  `ExecuteWitnessScript`, unrolled four times so it is loop-free, against the
  Lean `opSuccessScanFrom` walk.  One (index, found) state machine in Cryptol
  is the shared specification.
- `cell_prescan_tail(found, discourage, too_many, oversize, later_rc)` — the
  three checks after the scan, in Core's order, with the EvalScript tail as an
  uninterpreted input.

## What is proved

For **every** script of length 0..4 (all byte values, any length in that
range):

| scan result | flag | outcome |
|---|---|---|
| OP_SUCCESSx decoded | off | success; independent of an oversized initial stack, an oversized item, and the EvalScript tail |
| OP_SUCCESSx decoded | on | DISCOURAGE_OP_SUCCESS (36), policy |
| none | any | STACK_SIZE > PUSH_SIZE > EvalScript tail, in that order |

The scan handles the decode rules that matter for the row:

- pushes and PUSHDATA1/2/4 are skipped with their payload, so a `0x50` inside
  push data is **not** an OP_SUCCESSx; the next opcode after the push is;
- a truncated push before any OP_SUCCESSx yields "not found"; an OP_SUCCESSx
  **before** a truncated push yields "found" (BIP342: the scan stops at the
  first OP_SUCCESSx and later bytes are never decoded);
- OP_RESERVED `0x50` is an OP_SUCCESSx; `0x51..0x60` are not; `0xff` is not.

## What is not proved (this is a partial row)

- **Arbitrary script length.**  The scan is straight-line unrolled for length
  <= 4.  An 8-byte version of the same pair was built and run: Alive2 could not
  discharge it inside a 60 s SMT budget (it did return a counterexample when the
  budget was raised, which exposed a real 32-bit wrap in the first L draft of
  the PUSHDATA4 bound check; that bug is fixed here).  SAW is not the obstacle
  — its cost is the same 4-step unfold.
- **Error kind on malformed tails.**  Core's scan returns BAD_OPCODE when
  `GetOp` fails *before* the stack-size checks; the Lean model returns false and
  lets the size checks run, so with >1000 witness items Core says BAD_OPCODE and
  Lean says STACK_SIZE.  Both reject.  This is filed as F-DIV-w32-001 in
  `findings/wave32/27-tapscript-149-155/`; the cell compares only the found bit
  and therefore excludes the malformed-tail error kind.
- The EvalScript/cleanstack/CastToBool result (`later_rc`) and the size
  preconditions themselves.

## Why this is still worth filing

The row's substance — "overrides all later checks (incl. size limits)" — is an
*ordering* statement, and the cell proves the ordering symbolically: the
`found` branch's outcome does not depend on `too_many`, `oversize` or
`later_rc`.  The remaining gap is only the length bound and the malformed-tail
error kind, both stated exactly.

## Next experiment (smallest)

1. Raise the unroll bound to 8 with a shorter byte argument (two 32-bit words)
   and `--smt-to=300000`, or
2. prove the same pair with a SAW loop invariant on the pre-scan over
   `MAX_SCAN_LEN = 8` and keep Alive2 at the bounded instance.

## Exact commands

```sh
spec/equiv/cells/tapscript/C-L-w32-op-success-prescan/alive2/run.sh
spec/equiv/cells/tapscript/C-L-w32-op-success-prescan/saw/run.sh
cd <repo root> && sha256sum -c spec/equiv/cells/tapscript/C-L-w32-op-success-prescan/alive2/certificate.sha256
cd <repo root> && sha256sum -c spec/equiv/cells/tapscript/C-L-w32-op-success-prescan/saw/certificate.sha256
```

The Alive2 runner passes `--smt-to=60000`; the scan needs ~9 s per proof, the
tail <1 s.

## Development note

The first green attempt used one 64-bit word for the 8-byte scan; Alive2 timed
out at the default 10 s budget.  The four-byte form is the largest instance
that both tools discharge comfortably.  The 8-byte experiment is preserved in
this report, not in the cell.
