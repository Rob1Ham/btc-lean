---
# Cell stack-ops/C-L-depth-size
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-depth-size
family: stack-ops
tool_status: both-green (symbolic bounded law, one depth/length-specialised entry per case)
precondition: |
  - DEPTH entries at data depth d = 0,1,2,3. d = 0 starts with an empty stack;
    d = 1..3 seed d symbolic one-byte elements e0..e2 (bottom-up).
  - SIZE entries at one element length per entry: 0, 1, 2, 127, 128, 255,
    256, and 520 (MAX_SCRIPT_ELEMENT_SIZE). The first payload byte e0 is
    symbolic; remaining payload bytes are zero. One extra entry starts with an
    empty stack.
  - `opc` is the incoming nOpCount (symbolic 0..255) and `sv` is the sigversion
    (symbolic 0..2). fExec is 1 in every entry.
  - bounded leaf: total stack <= 4 and element length <= 520. DEPTH at d = 4
    is outside the cell: its push would make five elements, which is the
    STACK_SIZE edge, not this row.
postcondition: |
  - budget first: in BASE/WITNESS_V0 (sv 0/1) an opcode above OP_16 charges one
    unit and nOpCount 201 -> 202 is OP_COUNT (7); TAPSCRIPT (sv 2) charges
    nothing. nOpCount 200 is the last passing value.
  - OP_DEPTH (wire 0x74) has no stack-size pre-check. It pushes
    CScriptNum(stack.size()).getvch(): zero is the empty vector, 1..3 are one
    byte. Capacity is not checked on the push path itself; the final stack is
    d+1 and is at most 4 in the domain.
  - OP_SIZE (wire 0x82) with an empty stack returns INVALID_STACK_OPERATION
    (18). Otherwise it leaves the original element and pushes the minimal
    CScriptNum encoding of its length: 0 -> empty, 1..127 -> one byte,
    128..255 -> two bytes with a 0x00 sign byte, 256 -> 0x00 0x01, 520 ->
    0x08 0x02.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-076
scr_row_coverage: full — under the stated bounds every DEPTH depth (0..3) and
  every branch of the minimal CScriptNum encoding of an element length up to
  MAX_SCRIPT_ELEMENT_SIZE are covered. The SIZE lengths 0,1,2,127,128,255,256,
  520 hit both sides of the one-byte/two-byte boundary and both sign-byte
  cases (0x80/0xff gain a 0x00 byte, 0x0100/0x0208 do not). Budget is symbolic
  in every entry, so both sides of the nOpCount 201 edge are included, for both
  opcodes, in all three sigversions. The STACK_SIZE edge for DEPTH at a full
  stack is excluded by the depth bound and belongs to the stack-size row.
patches: none
source_citations:
  - src/script/interpreter.cpp:460-465 (opcode budget)
  - src/script/interpreter.cpp:488 (fExec gate)
  - src/script/interpreter.cpp:787-793 (OP_DEPTH)
  - src/script/interpreter.cpp:883-891 (OP_SIZE)
  - src/script/interpreter.cpp:415-427 (CScriptNum::getvch)
  - src/script/script_error.cpp (error ordinals via contract/error_kind.h)
trust_note: >
  C is a line-cited source-excerpt slice of EvalScript's DEPTH/SIZE cases plus
  the budget gate; the minimal encoder is transcribed from CScriptNum::getvch.
  L calls the twin handlers generated verbatim from twin/ops_ir.py by
  cells/_tools/mk_leaf.py, inside a mirror of twin/runtime.inc:594-652. The
  cell-local src/obs.h is the same observable on both legs: four fixed slots
  for DEPTH and two fixed slots plus a ten-bit original length for SIZE. Fixed
  slots avoid a dynamic top index, which the optimiser otherwise lowers to
  llvm.usub.sat and SAW cannot load. No source patch.
---
