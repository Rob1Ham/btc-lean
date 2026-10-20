# wave64 / 11-scr-072 — SCR-072 flag-off CLTV/CSV NOP cell

**Row:** SCR-072, control-flow, "without flags they are plain NOPs"
(`interpreter.cpp:EvalScript:534-537,573-576@cce32b168`; Lean face
`PDW73.lean:31-47 stepBody_cltv_csv_noflag_nop`).
**Branch:** `wave64/11-scr-072`, base `5946c02`.
**Cell:** `spec/equiv/cells/control-flow/C-L-cltv-csv-nop/`
**Result:** both tools green (symbolic). Ledger entry not edited here (shared
file); `update_ledger.py --from-cells` derives `SCR-072 -> both-green` from
the record.

## Why the row was a gap

The withdrawn green (`control-flow/C-L-nop-return`) proved NOP-ness only for
`OP_NOP`, `OP_NOP1` and `OP_NOP4..10`. It never dispatched wires `0xb1`
(CLTV) or `0xb2` (CSV), so the pre-activation NOP branch that the row names
was untested. The withdrawal was correct.

## What the new cell proves

Four exported functions, all with symbolic inputs (stack depth 0..3, every top
byte, incoming nOpCount 0..200):

| function | flag | depth | result |
|---|---|---|---|
| `cell_cltv_flagoff`, `cell_csv_flagoff` | clear | 0..3 | continue; state unchanged except `opCount + 1` |
| `cell_{cltv,csv}_flagon` | set | 0 | `INVALID_STACK_OPERATION` (18) |
| `cell_{cltv,csv}_flagon` | set | 1..3 | declared boundary (decode/compare: locktime rows) |

The flag-off result is exactly the row's Lean theorem:
`.ok { st with opCount := st.opCount + 1 }`. The flag-on/depth-0 row is the
contrast: the stack guard (`:539-540`, `:578-579`) is reachable only when the
flag is set, so the same empty stack changes from NOP to error.

- Alive2: 4/4 "Transformation seems to be correct", 1 correct / 0 incorrect /
  0 failed-to-prove per pair (`alive2/result.txt`).
- SAW: 8/8 `Proof succeeded!` against one independent Cryptol predicate
  (`saw/result.txt`).
- Mutants executed in a scratch copy, all three killed by Alive2: flag-off
  returning 18 (counterexample at depth 0), op-count `+1 -> +2` (counterexample
  at depth 1), and flag-on empty stack returning "continue" instead of 18
  (counterexample at depth 0). The equality and the contrast are not vacuous.

## Provenance

- C leg is a line-cited Core slice: flag checks, both stack guards and the
  op-count bump are verbatim; `break`/`set_error` are the cell's return codes.
- L leg is a reviewed transliteration of `Defs.lean:817-848` / `:857-875`
  (mapping in `src/lean_excerpt.md`). It is not generated twin output: the
  twin's `OP_CLTV`/`OP_CSV` return `TWIN_INVALID_UNSUPPORTED` on the flag-on
  path (F-LOCKTIME-001), so it cannot express the contrast. Its flag-off body
  is the same `.ok st` branch.
- No Core patch. No shared file edited.

## Boundary (explicit, not hidden)

Flag-on **with a non-empty stack** is the declared boundary in both legs
(result code 3): operand decode plus `CheckLockTime`/`CheckSequence` need the
transaction context and are `locktime/C-L-cltv-op` (SCR-122..125) and
`locktime/C-L-csv-op` (SCR-126..129). This cell does not claim those rows.

## Integration notes

- `spec.md` front matter: `scr_rows: SCR-072`,
  `tool_status: both-green (...)`, `patches: none`, `trust_note` present;
  schema-validated by `update_ledger.py` (dry run on a temp ledger gave
  `SCR-072 both-green ['control-flow/C-L-cltv-csv-nop']`, gap_note cleared).
- Both certificates are in normalized form (all tracked cell inputs + both
  `result.txt` + `contract/error_kind.h`); `normalize_certificates.py --check`
  reports no drift for this cell.
- `gate_ir_pin.py` reports no failure naming this cell; the pre-existing
  certificate/build-artifact failures in other cells are unchanged (225 before
  and after).
