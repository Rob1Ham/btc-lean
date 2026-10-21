# tapscript/C-L-w32-opcount-budget

Bounded proof of SCR-155: the 201-opcode budget is consulted only for
`BASE`/`WITNESS_V0`; on the tapscript path it is skipped entirely.

## Two functions, one row

- `cell_opcount_guard(sv, wire, oc)` — the guard itself, total over
  `sv in {0,1,2}`, all 256 wire bytes and `oc <= 10000`.  Returns
  `(verdict, nOpCount_out)`.
- `cell_nop_overbudget(sv, oc, top_true)` — one `OP_NOP` through the guard plus
  the witness post-checks (`cleanstack`, `CastToBool`) for a one-item stack, so
  the row's "an already-over-budget tapscript OP_NOP still succeeds" is an
  observable rather than a comment.

## What the proof fixes

| sv | wire / op | oc | outcome |
|---|---|---|---|
| BASE, WITNESS_V0 | `> 0x60` / OP_NOP | `oc + 1 > 201` | `OP_COUNT` (7), aux `oc + 1` |
| BASE, WITNESS_V0 | `> 0x60` / OP_NOP | `oc + 1 <= 201` | continue / success, aux `oc + 1` |
| BASE, WITNESS_V0 | `<= 0x60` | any | continue, aux `oc` |
| TAPSCRIPT | any wire byte | any | continue, aux `oc` (never incremented) |
| TAPSCRIPT | OP_NOP | any | success iff `CastToBool(top)`, aux `oc` |

The `aux` field makes "leaves opCount untouched" observable: for TAPSCRIPT it
equals the input `oc` for every input; for BASE/WITNESS_V0 it is `oc + 1` for
counting opcodes and `oc` for `wire <= 0x60` (OP_RESERVED `0x50` included).

## Reachability caveat (stated, not hidden)

A real tapscript `EvalScript` starts with `nOpCount = 0` and never increments
it, so `oc > 201` is not reachable *inside* one tapscript evaluation.  The row
is a counterfactual statement about the guard ("the budget is not consulted"),
and the cell proves it for arbitrary `oc`.  The cell does **not** claim that a
tapscript run can reach `oc > 201`.

## What is not proved

- The rest of `EvalScript`: script parse, stack/alt checks, every other
  opcode, and the tapscript OP_SUCCESSx pre-scan (SCR-153/154).
- Initial stack-size/item-size/validation-weight preconditions of
  `cell_nop_overbudget` (SCR-021/031/040).
- That any particular script can be built that reaches the state.

## Exact commands

```sh
spec/equiv/cells/tapscript/C-L-w32-opcount-budget/alive2/run.sh
spec/equiv/cells/tapscript/C-L-w32-opcount-budget/saw/run.sh
cd <repo root> && sha256sum -c spec/equiv/cells/tapscript/C-L-w32-opcount-budget/alive2/certificate.sha256
cd <repo root> && sha256sum -c spec/equiv/cells/tapscript/C-L-w32-opcount-budget/saw/certificate.sha256
```
