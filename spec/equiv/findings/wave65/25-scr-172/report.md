# Wave 65 — task 25-scr-172

Family: disabled-opcodes.  Assigned row: **SCR-172** ("same bytes become
success in tapscript").

Pin: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
Contract: `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
Branch: `wave65/25-scr-172`, cut from `76dbfe5e42f8a337e41a7308158b0de078afafd9`.
Not pushed.  No shared files edited; this directory and the new cell are the
whole deliverable.

## 1. Result

**The row is now closed for arbitrary script length on the Lean model, and
machine-checked at length <= 8 on the compiled C/L pair.**  The one remaining
case is an **ordering** divergence that was already known
(F-DIV-w32-001): on a truncated tail with a simultaneous stack/item-size
condition, Core returns `BAD_OPCODE` (16) before the size checks while Lean
returns `STACK_SIZE` (8) or `PUSH_SIZE` (6).  This cell states that set exactly
and records it as an expected Alive2 counterexample; it does **not** claim the
two post-scan contexts are equivalent.

Deliverables:

| path | what |
|---|---|
| `spec/equiv/cells/disabled/C-L-w65-row172-arbscan/` | the cell: C/L leaves, independent Cryptol spec, SAW script, Alive2/SAW/Lean runners, raw results, certificates |
| `.../src/Row172Induction.lean` | arbitrary-length Lean induction (not `spec/proofs`) |
| `.../alive2/divergence.txt` | the expected non-equivalence, kept out of the green result |
| `spec/equiv/findings/wave65/25-scr-172/report.md` | this report |

## 2. What was proved

### 2.1 Compiled pair, `len <= 8` (Alive2 + SAW)

`cell_flip(len, b0..b7, disc)` computes both classifications in one
byte-granular shift-register walk and packs `(base << 32) | tap`:

| first event on the walk | base | tap |
|---|---|---|
| decoded opcode in the fifteen legacy-disabled wires | 17 `DISABLED_OPCODE` | 0, or 36 if `disc != 0` |
| decoded `.op` in `IsOpSuccess` | 66 | 0, or 36 if `disc != 0` |
| `GetOp` truncation before either | 16 `BAD_OPCODE` | 16 `BAD_OPCODE` |
| walk completes, nothing found | 66 | 66 |

- Alive2, C -> L and L -> C: `1 correct transformations`, `0 incorrect`,
  `0 failed-to-prove`, `0 Alive2 errors` each (`alive2/result.txt`).
- SAW, both legs against the **jump-form** Cryptol spec `flip` in
  `src/cell.cry` (`saw/result.txt`), plus seven spec theorems:
  - the exact post-scan divergence boundary
    (`prop_divergence`), and both agreement directions
    (`prop_agree_found`, `prop_agree_no_size`);
  - a decoded legacy-disabled byte forces tapscript success for every
    `len <= 8` and every byte (`prop_base17_tap_success`);
  - each of the fifteen disabled bytes as a one-byte script flips 17 -> 0;
  - a non-disabled OP_SUCCESSx (0xbb) wins tapscript but is not a legacy flip;
  - a disabled byte inside a push payload is data on both legs (no flip).

The shift register is not assumed equivalent to Core's variable-`next` loop:
the Cryptol spec keeps the jump form and SAW proves each IR leg equal to it.

### 2.2 Arbitrary length (Lean kernel)

`src/Row172Induction.lean`, compiled against the pinned core package:

```lean
inductive ScanPath (b : ByteArray) : Nat -> Nat -> Nat -> Prop
theorem opSuccessScan_of_reaches_success
    (hp : ScanPath b s 0 j)
    (hget : getOp b j = some (Opcode.op c, j'))
    (hs : isOpSuccessWire c.toNat = true) :
    opSuccessScan b = true
theorem opSuccessScan_of_reaches_disabled ...        -- via disabledWire_success
theorem executeWitnessScript_tapscript_of_reaches_disabled
    ... : executeWitnessScript ... tapscript = ok / fail discourageOpSuccess
theorem evalFrom_prefix_disabled
    ... (hoc : st'.opCount < MAX_OPS_PER_SCRIPT) :
    evalFrom ctx (pre.length + 1) (pre ++ op :: rest) st
      = .error ExecError.disabledOpcode
```

No length bound, no suffix condition, any witness stack/fuel for the tapscript
outcome.  Axiom footprints: `[propext, Quot.sound]` for all four; no
`sorryAx`.

## 3. The exact remaining ordering case

Post-scan ordering (`cell_tail`), Core vs Lean:

| order | Core `interpreter.cpp:1846-1871` | Lean `Defs.lean:1211-1233` |
|---|---|---|
| success found | 0 / 36 | 0 / 36 |
| decode failure | **16** | after size checks |
| > 1000 initial items | 8 | 8 |
| item > 520 bytes | 6 | 6 |
| otherwise | 66 | 66 |

Divergence set, proved at the spec level:

```
found == 0  /\  decode_fail != 0  /\  (too_many != 0  \/  oversize != 0)
```

On that set Core = 16, Lean = 8 when `too_many != 0`, else 6.  Alive2's witness
(source 16, target 8) is recorded in `alive2/divergence.txt` with
`STATUS=expected-divergence-recorded`.  This is F-DIV-w32-001, not a new
divergence; the cell's contribution is the exact predicate and the fact that
the green flip result is kept separate from it.

Why the row still holds: the flip is about a **reachable decoded disabled
opcode**.  A truncated tail is by definition not a decoded opcode, and the
arbitrary-length theorem only concludes after `getOp` succeeds at that index.
So the ordering split cannot turn a disabled/success opcode back into a
different verdict; it only changes which error a malformed script reports.

Also conditional and preserved: the BASE disabled verdict needs
`opCount < MAX_OPS_PER_SCRIPT`.  At `opCount = 201` a counting disabled opcode
yields `OP_COUNT`, not `DISABLED_OPCODE` (PDW60's dichotomy).  The Lean base
theorem carries that hypothesis explicitly.

## 4. Evidence and reproduction

```
cd spec/equiv/cells/disabled/C-L-w65-row172-arbscan
./alive2/run.sh     # green flip both directions + expected divergence file
./saw/run.sh        # 4 llvm_verify + 7 prove_print, Z3 backend
./lean/run.sh       # lake build + kernel check, axiom footprint pins
```

- `alive2/run.sh` uses `--smt-to=300000`.  Alive2's default 10 s budget times
  out on the eight-byte unroll; the explicit budget is required.  ABC was
  killed after 20 minutes on the same SAW obligation; Z3 proves the C leg in
  about 70 s.  The committed Alive2 run (both directions plus the divergence)
  took 53 s; the full SAW run (4 `llvm_verify` + 7 `prove_print`) took 2m29s
  and reports 11 `Proof succeeded!` lines.
- Each runner writes a raw `result.txt` and a `certificate.sha256` over
  repo-relative tracked inputs.  Certificates are normalised by
  `spec/equiv/tools/normalize_certificates.py`.
- Tool versions: clang/LLVM 20.1.2, Alive2 v20.0, SAW 1.6, Z3 4.8.14 (SAW
  bundle).

## 5. Residual / not covered

- No arbitrary-length theorem about the **compiled C IR**; the compiled unroll
  stops at 8 and the arbitrary-length closure is the Lean model of record.
- No proof about scripts that never reach a disabled/success opcode (the 66
  markers); EvalScript after the guard, witness contents, the 520-byte item
  computation, validation weight, annex/control block and signature ops are
  outside the cell.  `too_many`/`oversize` are abstract inputs in `cell_tail`.
- The policy word is modelled as `disc != 0`; error 36 is standardness, not
  consensus.
- The parser `isDisabled` 0x9a vs interpreter 0x99 discrepancy is documented;
  the cell follows the interpreter (`OP_RSHIFT = 0x99`).

## 6. A note on the SAW counterexample that found a bug

The first SAW run did not prove `cell_flip`; it produced a counterexample with
`disc = 0x40000000`.  Both leaves tested `discourage & 1`, while the intended
(and Cryptol) meaning is `disc != 0`.  The leaves were fixed to test
`disc != 0`, after which Alive2 is green in both directions and SAW proves the
obligation.  This was a transcription slip shared by both legs, so Alive2
alone could not see it; the independent spec did.
