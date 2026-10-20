# stack-ops/C-L-arity

Closes SCR-074's "each op checks depth ⇒ INVALID_STACK_OPERATION" for the
full 2DROP..TUCK arity set. Each opcode has one closed function; the stack is
empty, so the per-case guard is the branch exercised.

The C side carries one source-cited guard per op in
`cells/_tools/arity/c_leaf.cpp`. The L side calls the twin handler body from
`twin/ops_ir.py` via `mk_leaf.py`. Both return the packed constant
`0x48` (result 0, error 18, n=0). Success-branch composition is covered by
`cells/e1-stack/*` and `cells/stack/C-L-*`, not claimed here.

This is a bounded closed-witness cell, not a symbolic law over arbitrary
stacks. The error ordinal is the contract's
`EQUIV_ERR_INVALID_STACK_OPERATION`.
