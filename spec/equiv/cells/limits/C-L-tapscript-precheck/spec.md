---
# Cell limits/C-L-tapscript-precheck
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-tapscript-precheck
family: limits
tool_status: both-green (symbolic, all bounded depths and abstract outcomes)
precondition: |
  - ExecuteWitnessScript's tapscript prologue.  `depth` is the initial
    witness item count / main stack depth, bounded to [0, 2000].
  - `sv` ∈ {BASE=0, WITNESS_V0=1, TAPSCRIPT=2}; `has_success` is the
    abstract result of the OP_SUCCESSx scan; `discourage` is the
    SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS flag bit.
  - `inner_err` is the opaque EvalScript outcome: a Core ScriptError ordinal
    in [0, EQUIV_ERR_COUNT], where 0 means EvalScript returned true.  The
    cell is about the guard's placement, so EvalScript is a stub.
  - the item-size loop (SCR-021) is assumed satisfied; the altstack is empty
    at this point by construction, so there is no alt-depth input.
postcondition: |
  - TAPSCRIPT and has_success: result 1/error 0, or result 0/error 36
    (DISCOURAGE_OP_SUCCESS) when discourage is set — both before the depth
    guard and before EvalScript.
  - TAPSCRIPT and not has_success and depth > 1000: result 0, error_kind 8
    (STACK_SIZE), regardless of inner_err (the pre-check dominates).
  - otherwise: result 1/error 0 when inner_err = 0, else result 0 with
    error_kind = inner_err.
  - out-of-domain depth/sv/flags/ordinal: result 2, error_kind 1.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: [SCR-031]
scr_row_coverage: >-
  full — SCR-031 is the tapscript initial-stack guard `stack.size() > 1000 ⇒
  STACK_SIZE` and the fact that it runs before EvalScript with an empty
  altstack.  The cell proves the guard for every bounded main depth, proves
  it uses the main stack only (no alt input exists at this point), and proves
  placement: for depth > 1000 the result is STACK_SIZE for every possible
  EvalScript outcome `inner_err`, so a script that would have failed earlier
  or later inside EvalScript cannot preempt the guard.  The OP_SUCCESSx scan
  is an abstract boolean input with its exact ordering (success overrides the
  guard); the scan over script bytes is SCR-153 and is not claimed here.
patches: none
source_citations:
  - interpreter.cpp:1842-1844 (stack copy from the witness stack)
  - interpreter.cpp:1846-1862 (tapscript OP_SUCCESSx scan, abstracted)
  - interpreter.cpp:1864-1865 (initial stack size guard, altstack empty)
  - interpreter.cpp:1868-1874 (item loop, then EvalScript)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1207-1239 (executeWitnessScript)
trust_note: >
  C is a line-cited source-excerpt slice of Core ExecuteWitnessScript at the
  pin.  L is a reviewed transliteration of Lean `executeWitnessScript`; the
  generated twin has no witness engine at the pin (runtime.inc returns
  TWIN_INVALID_UNSUPPORTED on the witness path), so there is no twin handler
  to compare against and the Lean definition is the L source of record.
  EvalScript is an opaque symbolic outcome and the OP_SUCCESSx scan is an
  abstract boolean; both are stated in the precondition.  Alive2 compares
  the extracted modules; SAW verifies each against an independent Cryptol
  predicate.  This is a bounded prologue/placement cell, not a whole
  ExecuteWitnessScript proof.  No Core patch.
evidence:
  alive2: alive2/result.txt (STATUS=alive2-green)
  saw: saw/result.txt (STATUS=saw-green, 2 proofs)
  certificates:
    - alive2/certificate.sha256
    - saw/certificate.sha256
---

# limits/C-L-tapscript-precheck

C vs L for the tapscript initial-stack guard and its placement before
EvalScript.  `inner_err` is universally quantified: the guard cannot be
preempted by anything EvalScript would do.
