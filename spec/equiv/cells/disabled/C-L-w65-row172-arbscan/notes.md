# notes — C-L-w65-row172-arbscan

Row: SCR-172 (`same bytes become success in tapscript`).

Wave 65, task 25.  Independent, additive cell: it edits no shared ledger,
matrix, rules, pins, contract, runtime, or existing cell.  The only new paths
are this cell and `spec/equiv/findings/wave65/25-scr-172/`.

## 1. What this cell adds over wave 64/32

The wave-64 cell `disabled/C-L-w64-row172-flip` proves the flip for a
**one-byte** script, and the wave-32 cell `C-L-w32-opsuccess-scan` proves a
**two-opcode** pre-scan.  Neither states the row for a script of arbitrary
length, which is where OP_SUCCESSx actually matters: the pre-scan walks the
whole script and the first success opcode wins.

This cell closes that gap in two layers:

1. **Compiled, bounded (`len <= 8`).**  One shift-register walk computes both
   the BASE disabled classification and the tapscript pre-scan classification.
   Alive2 compares the C and L leaves in **both** directions; SAW compares
   each leg against an independent **jump-form** Cryptol specification, so the
   one-byte-per-iteration encoding is machine-checked against Core's
   variable-`next` walk rather than assumed.
2. **Model, arbitrary length.**  `src/Row172Induction.lean` proves, about the
   pinned Lean definitions, that *reaching* any decoded OP_SUCCESSx (and in
   particular any legacy-disabled wire) forces the tapscript success outcome,
   and that reaching a legacy-disabled wire forces the BASE disabled error
   while the op-count budget is not exhausted.  This is an induction over the
   decode path (`ScanPath`), not an unroll; it has no length bound.

## 2. The bounded pair

`cell_flip(len, b0..b7, disc)` returns `(base << 32) | tap`:

| condition (first event on the walk) | base | tap |
|---|---|---|
| decoded opcode in the fifteen-wire disabled set | 17 `DISABLED_OPCODE` | 0, or 36 if `disc != 0` |
| decoded `.op` in `IsOpSuccess` | 66 (no disabled wire) | 0, or 36 if `disc != 0` |
| `GetOp` truncation before any such opcode | 16 `BAD_OPCODE` | 16 `BAD_OPCODE` |
| walk completes, nothing found | 66 (EvalScript would run) | 66 (scan completes) |

`cell_flip` is identical on both legs; Alive2 proves `C <=> L` in both
directions and SAW proves both legs equal `flip` in `src/cell.cry`.

### 2.1 The bug SAW found

The first SAW run produced a counterexample rather than a proof: the leaves
tested the policy word as `discourage & 1`, while the spec (and the intended
meaning) is `disc != 0`.  A word such as `0x40000000` therefore disagreed
(tap 0 vs 36).  The leaves now test `disc != 0`; the counterexample is a good
example of the check doing real work, not a formality.  It is not a Core/Lean
divergence — both transcriptions had the same slip, which is exactly what
Alive2 alone could not catch.

## 3. The preserved ordering divergence (not equivalence)

The cell deliberately exports two **different** functions that share the name
`cell_tail`:

| order | function |
|---|---|
| Core (interpreter.cpp:1846-1871) | found -> 0/36; `decode_fail` -> 16; `too_many` -> 8; `oversize` -> 6; else 66 |
| Lean (Defs.lean:1211-1233) | found -> 0/36; `too_many` -> 8; `oversize` -> 6; `decode_fail` -> 16; else 66 |

The divergence set is exactly

```
found == 0  /\  decode_fail != 0  /\  (too_many != 0  \/  oversize != 0)
```

On that set Core returns `BAD_OPCODE` (16) from `GetScriptOp` **before** the
initial stack-size and 520-byte item checks, while Lean checks `STACK_SIZE`
(8) or `PUSH_SIZE` (6) first and returns 16 only if both are clear.  Alive2
reports the expected counterexample (source 16, target 8) in
`alive2/divergence.txt`; `alive2/result.txt` contains only the green flip
checks, so the gate can never read the divergence as an equivalence.  SAW also
proves, at the spec level, the exact boundary (`prop_divergence`) and the two
directions in which the orders do agree (`prop_agree_found`,
`prop_agree_no_size`).

This is the residual ordering case, stated exactly rather than papered over.
It does not weaken the row: the ordering difference is about which error a
*mutated/truncated* script reports, not about whether a reachable disabled
opcode becomes success.

## 4. Arbitrary length on the Lean side

`src/Row172Induction.lean` (compiled by `lean/run.sh`, not part of
`spec/proofs`):

- `ScanPath b s i j`: `s` successful `getOp` decodes take the walk from `i` to
  `j`.
- `ScanPath.progress`: `i + s <= j` and `j <= b.size`; every decode consumes
  at least one byte.
- `opSuccessScanFrom_sound` / `_complete`: the scan is exactly "some decoded
  `.op` on the path has a success wire".
- `opSuccessScan_of_reaches_success`: any path from 0 that reaches a decoded
  success `.op` makes `opSuccessScan b = true`, for **any** `b.size` and any
  suffix.
- `opSuccessScan_of_reaches_disabled`: the same for the fifteen legacy wires,
  via `disabledWire_success`.
- `executeWitnessScript_tapscript_of_reaches_disabled`: the row's tapscript
  outcome (`ok`, or `fail discourageOpSuccess` under the policy bit) for every
  fuel, witness stack and validation-weight value — i.e. before the size checks
  and EvalScript.
- `evalFrom_prefix_disabled`: the BASE-side mirror.  If a prefix steps without
  error and then a decoded disabled wire is reached with
  `opCount < MAX_OPS_PER_SCRIPT`, `evalFrom` returns `.error .disabledOpcode`,
  for any prefix length.  At `opCount = 201` the op-count check wins instead
  (PDW60), so this direction is conditional by design.

The Lean runner rejects `sorryAx` and any axiom footprint other than
`[propext, Quot.sound]`.

## 5. What is not covered

- An arbitrary-length theorem about the **compiled C IR**.  The compiled
  unroll stops at 8; the arbitrary-length closure is about the Lean model of
  record.  Bridging the two would need a loop or a verified extraction, which
  this cell does not attempt.
- Scripts that never reach a disabled opcode (the `66` markers).  The cell
  classifies the scan result, not the rest of EvalScript.
- Witness-stack contents, the 520-byte item computation, validation weight,
  annex/control block, signature operations, and EvalScript after the disabled
  guard.  `too_many`/`oversize` are abstract inputs in `cell_tail`.
- Whether a node sets the policy bit.  Error 36 is standardness, not
  consensus.
- The parser `isDisabled` 0x9a vs interpreter 0x99 discrepancy: the cell uses
  the interpreter's fifteen wires (`OP_RSHIFT = 0x99`, script.h:168), as the
  interpreter does.  The parser discrepancy is documented, not relied on.

## 6. Tools

- clang/LLVM 20.1.2, Alive2 v20.0, SAW 1.6 (Z3 backend).  Alive2 needs
  `--smt-to=300000`; the default 10 s budget is too small for the eight-byte
  unroll.  ABC was killed after 20 minutes on the same obligation; Z3 proves
  it.
- `alive2/run.sh`, `saw/run.sh`, and `lean/run.sh` each write a raw
  `result.txt` and a certificate over the cell's tracked inputs.  The
  intentional divergence lives in `alive2/divergence.txt` and is never part of
  the green status.
