# SCR-074 arity closure — stack-ops/C-L-arity

Addendum to `findings/cells/E1-report.md`. This cell was built after the E1
report; it is the full-coverage closure of one row, not a new family claim.

- Cell: `cells/stack-ops/C-L-arity`
- Ledger row: **SCR-074** — "each op checks depth ⇒
  INVALID_STACK_OPERATION" over the 2DROP..TUCK set.
- C leg: `cells/_tools/arity/c_leaf.cpp`, one line-cited Core guard per
  opcode (`interpreter.cpp:888-1045`); `g1/g2/g3/g4/g6` are the exact per-op
  depth minimums.
- L leg: `cells/_tools/arity/l_leaf.cpp` calls the twin handler copied by
  `cells/_tools/mk_leaf.py` from `twin/ops_ir.py`.
- Precondition: base sigversion, `flags=0`, empty main/alt stack, bounded leaf
  (element <= 1 byte, depth <= 6).
- Postcondition: each of 16 closed functions returns
  `(0, INVALID_STACK_OPERATION=18, n=0)` = `0x48`.
- Tools: Alive2 16/16 `Transformation seems to be correct`; SAW
  `Proof succeeded!` 32/32 (C and L for each function).
- Raw evidence: `alive2/result.txt` (`STATUS=alive2-green`),
  `saw/result.txt` (`STATUS=saw-green`), certificates, `build/twin_ops.h`.
- Coverage: `full` for the arity-guard row. Success-branch composition is
  covered by the other E1 cells; `DEPTH` has no arity guard and is covered by
  the depth-count cell.
- No Core patch, no whole-engine proof, no unconditional Lean==Core claim.
