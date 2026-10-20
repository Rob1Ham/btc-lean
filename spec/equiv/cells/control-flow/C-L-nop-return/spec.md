---
# Cell control/C-L-nop-return
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-nop-return
family: control-flow
tool_status: both-green (bounded closed witnesses)
precondition: |
  - base sigversion; flags = 0; amount = 0; input_index = 0; one input.
  - empty scriptSig; no witness record; fully parseable scriptPubKey.
  - closed functions: OP_RETURN; OP_NOP; OP_NOP1; OP_NOP4..OP_NOP10.
  - bounded leaf domain: element length <= 1 byte, stack depth <= 6.
postcondition: |
  - cell_op_return returns packed (result=0, error=EQUIV_ERR_OP_RETURN=3, n=0).
  - cell_plain_nop, cell_nop1, cell_nop4_to_10 each leave the value 1 on the
    stack and return (result=1, error=0, n=1, top=(len=1,val=1)).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-069, SCR-071, SCR-072
scr_row_coverage: full — SCR-069 is exactly "OP_RETURN error"; SCR-071 executes
  NOP1 and NOP4..NOP10 and succeeds; SCR-072's premise is flags=0, under which
  those opcodes are plain NOPs.
patches: none
source_citations:
  - interpreter.cpp:529-530 (OP_NOP)
  - interpreter.cpp:605-609 (OP_NOP1, OP_NOP4..OP_NOP10)
  - interpreter.cpp:677-680 (OP_RETURN)
  - interpreter.cpp:1876-1880 (EVAL_FALSE tail)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at
  the pin, not the whole EvalScript. L uses the twin handler bodies verbatim,
  generated from twin/ops_ir.py into build/twin_ops.h; the bounded
  init/pack/dispatch code is cell harness, not engine code. The SAW
  postcondition is the declared packed constant for a closed witness; these
  are bounded op cells, not a whole-engine equivalence proof. No Core source
  patch is used.
---
