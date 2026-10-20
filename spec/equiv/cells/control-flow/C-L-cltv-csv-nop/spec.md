---
# Cell control-flow/C-L-cltv-csv-nop
cell: C-L-cltv-csv-nop
family: control-flow
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c024546e39f55775bfd9a077b042e3feeef4
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (symbolic in depth 0..3, all top bytes, opCount 0..200)
precondition: |
  - base sigversion; one transaction input; the script is dispatched as
    executed (fExec = true), so the `switch` is reached.
  - bounded state: stack depth 0..3, each element one byte, top byte
    symbolic over all 2^8 values, incoming nOpCount 0..200.
  - the activation bits are the only flags that differ between the function
    pairs: cell_*_flagoff passes flags = 0 (the row's premise), cell_*_flagon
    passes only the corresponding activation bit.
  - SCR-072's Lean face (PDW73.lean:31-47) carries
    `¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1)`; the cell's opCount domain is
    0..200, so the OP_COUNT rejection is statically outside the domain.
postcondition: |
  Observable (packed uint64): result(2) | error(6)<<2 | depth(3)<<8 |
  top_len(2)<<11 | top(8)<<13 | nOpCount(8)<<21.

  cell_cltv_flagoff / cell_csv_flagoff, for every depth in 0..3, every top
  byte, and every opCount in 0..200:
    result = 1 (the opcode continued: Core `break`), error = 0,
    depth and top byte unchanged, nOpCount = opCount + 1.
  That is exactly Lean `stepBody_cltv_csv_noflag_nop`:
    `.ok { st with opCount := st.opCount + 1 }` — the whole state, stack
  included, is unchanged and only the op-count budget moves.  The empty-stack
  case is included, so the flag check provably precedes the stack guard.

  cell_cltv_flagon / cell_csv_flagon, flag-on contrast:
    depth = 0: result = 0, error = INVALID_STACK_OPERATION (18), stack
    unchanged, nOpCount = opCount + 1.  The stack guard at :539-540 /
    :578-579 is reached only when the flag is set, so the same empty stack
    that is a NOP with the flag clear is an error with it set.
    depth >= 1: result = 3, the declared cell boundary.  The operand decode
    and the locktime/sequence comparison need the transaction context; they
    are the locktime cells' rows (SCR-122..129) and are not claimed here.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-072
scr_row_coverage: |
  full for the row's own claim.  SCR-072 is "without flags they are plain
  NOPs", i.e. the `if (!(flags & …)) break;` branches at
  interpreter.cpp:534-537 (CLTV) and :573-576 (CSV).  The cell is symbolic over
  the state those branches could disturb (stack depth 0..3, every top byte)
  and over the incoming op-count, and both tools prove that on that domain the
  two branches leave the state unchanged except for the pre-switch op-count
  bump.  The flag-on functions are the contrast that makes the flag
  load-bearing on the same input: flag off on an empty stack continues, flag
  on on an empty stack returns 18.  The flag-on non-empty-stack continuation
  (decode + CheckLockTime/CheckSequence) is explicitly outside the cell and is
  covered by locktime/C-L-cltv-op and locktime/C-L-csv-op, which own
  SCR-122..129; it is not claimed twice here.
patches: none
source_citations:
  - interpreter.cpp:529-530 (OP_NOP, for contrast)
  - interpreter.cpp:532-540 (OP_CHECKLOCKTIMEVERIFY flag-off NOP2 and stack guard)
  - interpreter.cpp:571-579 (OP_CHECKSEQUENCEVERIFY flag-off NOP3 and stack guard)
  - interpreter.cpp:460-465 (op-count bump precedes the switch; MAX_OPS_PER_SCRIPT = 201)
  - interpreter.h:102-106 (SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY enumerator 9, SCRIPT_VERIFY_CHECKSEQUENCEVERIFY enumerator 10)
  - script.h:32 (MAX_OPS_PER_SCRIPT = 201)
  - spec/core/Bitcoin/Interpreter/Defs.lean:817-848 (stepBody op-count bump), :857-875 (dispatchOp wires 0xb1/0xb2)
  - spec/proofs/BitcoinProofs/AF/PDW73/PDW73.lean:31-47 (stepBody_cltv_csv_noflag_nop, the row's Lean face)
  - contract/error_kind.h:49 (EQUIV_ERR_INVALID_STACK_OPERATION = 18)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at
  the pin: the two flag checks, both stack guards and the op-count bump are
  verbatim except that `break` is `return CELL_CONT` and set_error is the
  ScriptError ordinal.  The `opcode > OP_16` conjunct is dropped because it
  is statically true for 0xb1/0xb2.  L is a reviewed transliteration of the
  Lean model Defs.lean:817-848 / :857-875, not generated twin output: the
  generated twin (twin/ops_ir.py OP_CLTV/OP_CSV) returns
  TWIN_INVALID_UNSUPPORTED on the flag-on path, so it cannot express the
  contrast.  Its flag-off body (`if (!ctx.flags.cltv) return TWIN_OK;`) is
  the same `.ok st` branch.  The flag-on non-empty-stack region is a declared
  boundary in both legs (result 3), not an engine verdict.  The packed
  op-count on an error path mirrors the pre-switch local, which Core and Lean
  both discard on failure; no claim is attached to it there.  Alive2 compares
  the C and L IR over every symbolic input; SAW verifies each leg separately
  against the same independent Cryptol predicate.  This is a bounded two-op
  cell, not a whole-engine equivalence proof.  No Core source patch is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: >
  Executed, not committed: three one-line mutants of the L leg, each killed by
  Alive2.  (1) flag-off returns INVALID_STACK_OPERATION instead of continuing:
  counterexample at depth 0 (C 0x200001 vs L 0x200048).  (2) op-count bump
  changed from +1 to +2: counterexample at (depth 1, b0 1, opCount 0)
  (C 0x202901 vs L 0x400001).  (3) flag-on empty stack returns CELL_CONT
  instead of 18: counterexample at depth 0 (C 0x200048 vs L 0x200001).  The
  three pin the NOP branch, the op-count observable, and the flag-on contrast
  respectively; the equality is not vacuous.
---

# control-flow/C-L-cltv-csv-nop

Minimal bounded cell for SCR-072: with their activation flags absent, CLTV
(0xb1) and CSV (0xb2) are plain NOPs, including on an empty stack, and only
the op-count budget moves.  The flag-on functions are the contrast.

## Seam

Core, at the pin, in `EvalScript`:

```
460  if (sigversion == SigVersion::BASE || sigversion == SigVersion::WITNESS_V0) {
462      if (opcode > OP_16 && ++nOpCount > MAX_OPS_PER_SCRIPT) {
463          return set_error(serror, SCRIPT_ERR_OP_COUNT);
465  }
...
534      if (!(flags & SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY)) {
535          // not enabled; treat as a NOP2
536          break;
537      }
539      if (stack.size() < 1)
540          return set_error(serror, SCRIPT_ERR_INVALID_STACK_OPERATION);
...
573      if (!(flags & SCRIPT_VERIFY_CHECKSEQUENCEVERIFY)) {
574          // not enabled; treat as a NOP3
575          break;
576      }
578      if (stack.size() < 1)
579          return set_error(serror, SCRIPT_ERR_INVALID_STACK_OPERATION);
```

The NOP branch is taken before any stack read.  So with the flag clear the
opcode cannot fail on an empty stack and cannot move the stack; the only state
change is the pre-switch `++nOpCount`.

## Model

`src/c_leaf.cpp` is the Core slice; `src/l_leaf.cpp` is the reviewed Lean
transliteration (`src/lean_excerpt.md` maps every line).  Both take the same
three symbolic inputs — `depth` (clamped to 0..3), `b0` (top byte) and
`opcount` (clamped to 0..200) — and return the packed observable.

The flag is not free text: the four exported functions fix it to the row's two
settings (0, or only the relevant activation bit).  The flag-off pair is the
row; the flag-on pair is the contrast that shows the bit is load-bearing on
identical inputs.

## What is proved

| function | depth | result | error | stack | opCount |
|---|---|---:|---:|---|---|
| `cell_cltv_flagoff`, `cell_csv_flagoff` | 0..3 | 1 | 0 | unchanged | +1 |
| `cell_{cltv,csv}_flagon` | 0 | 0 | 18 | unchanged | +1 |
| `cell_{cltv,csv}_flagon` | 1..3 | 3 boundary | — | unchanged | +1 |

Alive2 proves C ≡ L for all four functions; SAW proves each of the eight
compiled definitions against the independent Cryptol predicate
(`src/cell.cry`), 8 `Proof succeeded!` lines.  A concrete check:
`cell_cltv_flagoff(1, 1, 0) = 0x202901` — depth 1, top 1, opCount 1 — which is
the control cell's NOP success `0x2901` plus the op-count field.

## Limits

- Depth 0..3 and one-byte elements.  The branches are stack-free, so depth is
  only observed, never read; wider elements and deeper stacks cannot change
  the result, but they are not machine-enumerated.
- The `fExec` gate is assumed true (the switch is reached).  Unexecuted
  branches are a different row.
- Flag-on with a non-empty stack stops at the stack guard; the rest of the
  opcode belongs to `locktime/C-L-cltv-op` and `locktime/C-L-csv-op`.
- `INVALID_STACK_OPERATION` is 18 in `contract/error_kind.h`; the ordinal is
  the contract's, and it coincides with Core's `SCRIPT_ERR_INVALID_STACK_OPERATION`
  (`contract/error_enum.md`).
