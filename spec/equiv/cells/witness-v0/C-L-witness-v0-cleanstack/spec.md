---
# Cell witness-v0/C-L-witness-v0-cleanstack
cell: C-L-witness-v0-cleanstack
family: witness-v0
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (post-EvalScript cleanstack/truthy dispatch, total)
precondition: |
  - ExecuteWitnessScript reached its post-state arm: EvalScript returned true
    and produced a stack.  The EvalScript result is an INPUT to this cell; the
    interpreter loop is not run.
  - `stack_size` is st.length (any u64; the model is total).
  - `top_truthy` is CastToBool(st.back()) as a Boolean: 1 = true, 0 = false.
    The C signature carries it as a u64 but the cell's domain is {0,1}, which
    is exactly CastToBool's range; any nonzero u64 is also accepted by the C
    and L code identically (Alive2 sees the whole u64 domain).
  - CastToBool's definition is not re-proved here (ledger row SCR-057).
postcondition: |
  Packed observable result(2) | error_ordinal(6) << 2:
    stack_size != 1                 -> (0, 30) SCRIPT_ERR_CLEANSTACK
    stack_size = 1, top_truthy = 0  -> (0, 2)  SCRIPT_ERR_EVAL_FALSE
    stack_size = 1, top_truthy != 0 -> (1, 0)  success
  The predicate is total over every stack size and both truth values; the
  cleanstack guard precedes the truthiness guard, as in Core and Lean.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-138
scr_row_coverage: |
  full for the rule as stated ("exactly 1 true element (cons.)").  The row is
  precisely the two post-EvalScript guards: `stack.size() != 1` and
  `!CastToBool(stack.back())`.  Both are proved for every stack size and both
  truth values, including the precedence order.  The row does not include
  running EvalScript; that is its precondition.  CastToBool's own definition is
  the separate row SCR-057 and is taken as the Boolean input.
patches: none
source_citations:
  - interpreter.cpp:1873-1874 (EvalScript call; its true result is the
    precondition, the call is not modelled)
  - interpreter.cpp:1876-1877 (stack.size() != 1 -> SCRIPT_ERR_CLEANSTACK)
  - interpreter.cpp:1878 (!CastToBool(stack.back()) -> SCRIPT_ERR_EVAL_FALSE)
  - interpreter.cpp:1879 (return true)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1207-1241
    (Bitcoin.Interpreter.executeWitnessScript, runExec post-state branch)
  - contract/error_enum.md (ordinals 2 SCRIPT_ERR_EVAL_FALSE, 30
    SCRIPT_ERR_CLEANSTACK)
trust_note: >
  C is a line-cited source-excerpt slice of the tail of ExecuteWitnessScript at
  the pin, not the whole function.  L is a REVIEWED TRANSLITERATION of the
  verified Lean post-state branch.  The EvalScript outcome and CastToBool are
  inputs; no interpreter, hash or crypto claim is made.  Both tools prove the
  same total dispatch over the post-state.  No Core patch is used.
evidence:
  - alive2/result.txt (alive-tv v20, clang 20.1.2)
  - saw/result.txt (SAW 1.6, solver abc; two proofs)
  - alive2/certificate.sha256, saw/certificate.sha256
mutant: >
  Not executed here.  A useful mutant is `stack_size < 1` instead of `!= 1`
  (which wrongly accepts size 0 or 2) or swapping the two guards (which would
  report EVAL_FALSE before CLEANSTACK).  Both must fail at a parseable
  counterexample, e.g. (stack_size=2, truthy=1) or (stack_size=2, truthy=0).
---
# witness-v0/C-L-witness-v0-cleanstack

Witness scripts have no explicit `OP_VERIFY` epilogue: Core imposes
"cleanstack" and truthiness on the stack that EvalScript leaves behind
(interpreter.cpp:1876-1879).  `ExecuteWitnessScript` is otherwise shared by
P2WSH and P2WPKH, so this post-state rule is the last common step before both
v0 success paths.

## What is proved

`cell_v0_cleanstack(stack_size, top_truthy)`:

| stack_size | top_truthy | result |
|---:|---:|---|
| != 1 | any | (0, 30) CLEANSTACK |
| 1 | 0 | (0, 2) EVAL_FALSE |
| 1 | nonzero | (1, 0) success |

This is total.  The guards are ordered: a non-singleton stack is rejected as
CLEANSTACK even when its top would also be false, which is what both Core and
Lean do.

## What is not proved

- Running EvalScript / the opcode loop.  The cell starts from its successful
  result; that is the declared precondition, not a claim.
- `CastToBool` itself (SCR-057).  The cell consumes its Boolean output, exactly
  as `executeWitnessScript` consumes `castToBool st[0]!`.
- Any hash, signature or witness-program dispatch (sibling cells).

The cell therefore promotes SCR-138 for the post-state rule only, and does not
claim a proved end-to-end witness spend.
