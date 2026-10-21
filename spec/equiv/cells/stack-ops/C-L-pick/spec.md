---
# Cell stack-ops/C-L-pick
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-pick
family: stack-ops
tool_status: both-green (symbolic bounded law, one depth-specialised entry per case)
precondition: |
  - Twelve entries. PICK has one symbolic-index entry for each data depth
    d = 1,2,3 (`cell_pick_d*_sym`), so every one-byte index encoding is in the
    domain, valid or not. ROLL has one entry per valid constant index at each
    depth: d = 1 -> {0}, d = 2 -> {0,1}, d = 3 -> {0,1,2}. Two depth-0 entries
    (`cell_pick_d0`, `cell_roll_d0`) exercise the size < 2 pre-check, and
    `cell_skip` is an unexecuted (fExec = 0) depth-3 entry.
  - Seeded data elements are symbolic one-byte values (e0..e2, bottom-up); the
    index is pushed last. `opc` is the incoming nOpCount (symbolic 0..255), and
    `sv` is the sigversion (symbolic 0..2). fExec is a per-entry constant.
  - bounded leaf: data depth <= 3 (the index makes the total stack <= 4) and
    every element is one byte.
postcondition: |
  - budget first: in BASE/WITNESS_V0 (sv 0/1) the opcode (> OP_16) charges one
    unit and nOpCount 201 -> 202 is OP_COUNT (7), even when fExec is false;
    TAPSCRIPT (sv 2) charges nothing. nOpCount 200 is the last passing value.
  - d = 0 (only the index on the stack) -> INVALID_STACK_OPERATION (18) after
    the budget check.
  - otherwise n = CScriptNum(top), where a one-byte 0x80 is negative zero
    (n = 0), 0x81..0xff are negative, and n outside [0, d) -> 18.
  - PICK copies stacktop(-n-1) and pushes it; ROLL erases that element and
    pushes it on top, so ROLL keeps the data depth and PICK adds one.
  - fExec = 0 (`cell_skip`) leaves the stack unchanged but still charges (or
    fails) the budget first.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-075
scr_row_coverage: >-
  full — under the stated depth bound every branch named by the
  row is exercised: size < 2 for both opcodes (d = 0), every valid ROLL index
  at d = 1,2,3, PICK with a symbolic index at d = 1,2,3 (so in-range selection,
  the 0x80 negative-zero encoding, and every out-of-range encoding are all
  covered), both PICK and ROLL, all three sigversions, both sides of the
  nOpCount 201 boundary, and the unexecuted skip with budget-before-fExec.
  MAX_STACK_SIZE is not exceeded in the domain: the largest result is PICK at
  d = 3, which leaves 4 elements.
patches: none
source_citations:
  - src/script/interpreter.cpp:460-465 (opcode budget)
  - src/script/interpreter.cpp:488 (fExec gate)
  - src/script/interpreter.cpp:833-849 (OP_PICK / OP_ROLL)
  - src/script/interpreter.cpp:67-72 (popstack)
  - src/script/script_error.cpp (error ordinals via contract/error_kind.h)
trust_note: >
  C is a line-cited source-excerpt slice of EvalScript's PICK/ROLL case plus the
  budget and fExec gates. L calls the twin handlers generated verbatim from
  twin/ops_ir.py by cells/_tools/mk_leaf.py, inside a mirror of
  twin/runtime.inc:594-652; an unexecuted branch is one false condition-stack
  frame so the twin's own vf_all decides. Alive2 cannot close a PICK/ROLL query
  with a symbolic depth (SMT array stores), and ROLL's data-dependent shift
  loop does not fold with a symbolic index, so depth and the ROLL index are
  constants per entry. The two tools use separate build dirs because they need
  different optimisation levels for the same source: Alive2 needs -O2 (at -O1
  the ROLL loop's undef-valued element extraction survives and Alive2 rejects
  an otherwise equal pair; -O2 folds the constant-index loop), while SAW/abc
  needs -O1 (at -O2 its handling of a nneg zero-extension in decode_num reports
  poison for the negative-index encodings that SAW otherwise proves at -O1).
  Within each tool both legs are compiled from the same source at the same
  level, so the comparison is still C-vs-L. No source patch.
---
