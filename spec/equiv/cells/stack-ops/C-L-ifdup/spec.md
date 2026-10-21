---
# Cell stack-ops/C-L-ifdup
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-ifdup
family: stack-ops
tool_status: both-green (symbolic bounded law)
precondition: |
  - `cell_ifdup_empty`: empty stack.
  - `cell_ifdup_len0`: one zero-length element.
  - `cell_ifdup_d1`: one symbolic one-byte top element v0.
  - `cell_ifdup_d2`: two symbolic one-byte bottom elements e0,e1 and one
    symbolic one-byte top v0.
  - `opc` is the incoming nOpCount (symbolic 0..255) and `sv` is the sigversion
    (symbolic 0..2). fExec is 1 in every entry.
  - bounded leaf: total stack <= 4, elements at most one byte.
postcondition: |
  - budget first: in BASE/WITNESS_V0 (sv 0/1) OP_IFDUP's wire 0x73 is above
    OP_16 and charges one unit; nOpCount 201 -> 202 is OP_COUNT (7), and 200 is
    the last passing value. TAPSCRIPT (sv 2) charges nothing. The empty-stack
    entry proves a budget failure wins over the size error.
  - empty stack -> INVALID_STACK_OPERATION (18).
  - CastToBool: zero-length is false; a one-byte 0x00 or 0x80 (negative zero)
    is false; every other one-byte value is true.
  - true -> the top element is copied and pushed again; false -> the stack is
    unchanged. The d2 entries show that only the top is copied and that the
    lower elements keep their order.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-077
scr_row_coverage: >-
  full — under the stated bounds the row's branches are all
  exercised: empty-stack underflow, the zero-length false case, both false
  one-byte encodings (0x00 and the 0x80 negative zero) and every true one-byte
  encoding via symbolic v0, at depth 1 and depth 2; both sides of the nOpCount
  201 boundary in every entry; all three sigversions. The duplicate at depth 2
  produces four elements, the maximum in the leaf domain.
patches: none
source_citations:
  - src/script/interpreter.cpp:460-465 (opcode budget)
  - src/script/interpreter.cpp:488 (fExec gate)
  - src/script/interpreter.cpp:776-785 (OP_IFDUP)
  - src/script/interpreter.cpp:46-59 (CastToBool)
  - src/script/script_error.cpp (error ordinals via contract/error_kind.h)
trust_note: >
  C is a line-cited source-excerpt slice of EvalScript's IFDUP case plus the
  budget gate and CastToBool. L calls the handler generated verbatim from
  twin/ops_ir.py by cells/_tools/mk_leaf.py, inside a mirror of
  twin/runtime.inc:594-652. The C CastToBool is a transcription of the same
  rule the twin's runtime.inc helper implements; the symbolic top byte makes
  the proof cover the 0x80 negative-zero special case rather than assuming it
  away. No source patch.
---
