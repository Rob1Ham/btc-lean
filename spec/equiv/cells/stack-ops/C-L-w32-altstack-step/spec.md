---
# Cell stack-ops/C-L-w32-altstack-step
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: stack-ops/C-L-w32-altstack-step
family: stack-ops
tool_status: both-green (symbolic single-step cell)
precondition: |
  - base sigversion; flags = 0; policy = 0; one input.
  - the step's wire is OP_TOALTSTACK (0x6b) or OP_FROMALTSTACK (0x6c);
    other wires are outside the cell domain and return a fixed sentinel on
    both legs.
  - nOpCount before the step is a full 32-bit value; the fExec bit is
    symbolic; main and alt depths are in 0..4; every element is one byte and
    the top byte of each stack is symbolic.
  - the trailing combined stack-size guard is unreachable in this domain
    (depth after any step is at most 5).
postcondition: |
  - both legs return the same packed observable
    result(2) | error(6) | main.n(3) | alt.n(3) | main top(8) | alt top(8).
  - budget: ++nOpCount > 201 gives OP_COUNT (7) before any handler check;
    nOpCount = 200 still executes.
  - executed TOALTSTACK with a non-empty main stack moves the top item to the
    altstack; executed FROMALTSTACK with a non-empty altstack moves the alt
    top to the main stack.
  - executed TOALTSTACK on an empty main stack gives
    INVALID_STACK_OPERATION (18); executed FROMALTSTACK on an empty altstack
    gives INVALID_ALTSTACK_OPERATION (19).
  - unexecuted (fExec false) non-budget-evicted steps leave both stacks
    unchanged and succeed.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-073
scr_row_coverage: >-
  full — every clause of the row is a symbolic case of this cell: the
  one-opcode-left move (nOpCount = 200), both empty-stack errors, the
  unexecuted-branch skip, and OP_COUNT precedence at nOpCount = 201 (the
  budget gate is checked before the handler and before the fExec skip).  The
  cell is a single EvalScript step, not the whole loop; the loop's decode and
  index bookkeeping are outside the row.
patches: none
source_citations:
  - interpreter.cpp:521-523 (opcode budget, counted before the switch)
  - interpreter.cpp:526-529 (fExec gate)
  - interpreter.cpp:687-695 (OP_TOALTSTACK)
  - interpreter.cpp:696-703 (OP_FROMALTSTACK)
  - interpreter.cpp:562-566 (per-step combined stack-size guard; unreachable here)
  - twin/ops_ir.py:150-179 (TOALTSTACK/FROMALTSTACK handler bodies)
  - twin/runtime.inc:612-625 (budget and fExec gates)
  - Defs.lean:906-912 (stepBody_toAltstack_* / stepBody_fromAltstack_*)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at
  the pin: the budget gate, the fExec gate and the two handlers, specialised
  to one step and to a bounded one-byte-element stack.  L uses the twin
  OP_TOALTSTACK/OP_FROMALTSTACK handler bodies verbatim (mk_leaf.py from
  twin/ops_ir.py); the two gates are copied from runtime.inc's eval_script,
  and the bounded init/pack/direct-call are cell harness.  The EvalScript
  loop itself is not executed (single-step projection); the row is about the
  step, not the loop.  No Core or twin patch is used.
---
