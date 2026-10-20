---
# Cell stack-ops/C-L-arity
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-arity
family: stack-ops
tool_status: both-green (bounded closed witnesses)
precondition: |
  - base sigversion; flags = 0; amount = 0; input_index = 0; one input.
  - empty main and alt stacks before each function; empty scriptSig; no witness.
  - one closed function per opcode in 2DROP, 2DUP, 3DUP, 2OVER, 2ROT,
    2SWAP, IFDUP, DROP, DUP, NIP, OVER, PICK, ROLL, ROT, SWAP, TUCK.
  - bounded leaf: element length <= 1 byte, stack depth <= 6.
postcondition: |
  - Every function returns packed (result=0, error=EQUIV_ERR_INVALID_STACK_OPERATION
    = 18, n=0), exactly the per-op arity guard outcome.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-074
scr_row_coverage: full — every opcode in the 2DROP..TUCK arity set is
  exercised at an empty stack (n=0) against its per-case Core guard and its
  twin handler; the success branches are covered by the other E1 cells and are
  not part of this "each op checks depth" row.
patches: none
source_citations:
  - interpreter.cpp:888-1045 (per-op stack-arity guards; individual line
    citations are on cells/_tools/arity/c_leaf.cpp)
  - interpreter.cpp:EvalScript stack-op cases at cce32b168
trust_note: >
  C is a line-cited source-excerpt slice of Core's per-op guards, not the
  whole EvalScript. L uses the twin handler bodies copied verbatim by
  cells/_tools/mk_leaf.py into build/twin_ops.h; the init/dispatch/pack code is
  cell harness. The cell is a closed-witness, not a symbolic op law. No Core
  source patch is used. DEPTH has no arity guard and is covered by the
  depth-count cell.
---
