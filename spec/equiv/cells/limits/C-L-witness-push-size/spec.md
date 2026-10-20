---
# Cell limits/C-L-witness-push-size
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-witness-push-size
family: limits
tool_status: both-green (symbolic; row coverage is partial by design)
precondition: |
  - ExecuteWitnessScript's initial witness stack.  `depth` (item count) is
    bounded to [0, 2000]; `max_item` is the maximum item size in bytes, all
    2^16 values.
  - `sv` ∈ {BASE=0, WITNESS_V0=1, TAPSCRIPT=2}.
  - `has_success` is the abstract result of the tapscript OP_SUCCESSx scan;
    `discourage` is SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS.
  - the script is assumed to reach the item-size loop (it parses); EvalScript
    is outside this cell.
postcondition: |
  - TAPSCRIPT and has_success: success (or DISCOURAGE_OP_SUCCESS=36), before
    the item loop — the BIP342 exemption.
  - TAPSCRIPT and not has_success and depth > 1000: STACK_SIZE=8 (the
    SCR-031 guard, which precedes the item loop).
  - otherwise, if max_item > 520: PUSH_SIZE=6.
  - otherwise: result 1/error 0 (the item loop admitted the stack).
  - out-of-domain depth/sv/flags: result 2, error_kind 1.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: [SCR-021]
scr_row_coverage: >-
  partial — the cell proves the witness item-size predicate
  `any (item.size() > 520) ⇒ PUSH_SIZE` (represented exactly by
  max_item > 520) for base/v0 and for tapscript without OP_SUCCESSx, its
  ordering after the SCR-031 initial-stack guard, and the BIP342 exemption
  ordering (a tapscript with OP_SUCCESSx returns success before the item
  loop).  The OP_SUCCESSx scan itself is an abstract boolean: deciding
  `opSuccessScan exec` over symbolic script bytes needs the per-opcode
  decode loop and early success, which is SCR-153 and is not modelled here.
  So the row's "containing OP_SUCCESSx" branch is only modelled at its
  outcome, not by scanning bytes.  EvalScript is also a stub, but the row
  ends before it.
patches: none
source_citations:
  - interpreter.cpp:1844 (stack built from the witness item vector)
  - interpreter.cpp:1846-1862 (OP_SUCCESSx scan and exemption, abstracted)
  - interpreter.cpp:1864-1865 (initial stack guard)
  - interpreter.cpp:1868-1871 (item size > 520 ⇒ PUSH_SIZE)
  - script.h:29 (MAX_SCRIPT_ELEMENT_SIZE = 520); script.cpp:365-371 (IsOpSuccess)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1207-1239 (executeWitnessScript)
  - spec/core/Bitcoin/Interpreter/Defs.lean:459-466 (isOpSuccessWire)
trust_note: >
  C is a line-cited source-excerpt slice of Core ExecuteWitnessScript; the
  item loop's `any` is represented by the maximum item size, which is exact
  for the predicate.  L is a reviewed transliteration of Lean
  `executeWitnessScript`; the generated twin has no witness engine at the
  pin, so the Lean definition is the L source of record.  `has_success` is an
  abstraction of `opSuccessScan`, explicitly named as the partial-coverage
  gap.  Alive2 compares the extracted modules; SAW verifies each against an
  independent Cryptol predicate.  No Core patch.
evidence:
  alive2: alive2/result.txt (STATUS=alive2-green)
  saw: saw/result.txt (STATUS=saw-green, 2 proofs)
  certificates:
    - alive2/certificate.sha256
    - saw/certificate.sha256
---

# limits/C-L-witness-push-size

C vs L for the witness-stack item-size limit.  Tool-green, row coverage
**partial**: the OP_SUCCESSx scan is an abstract input, so SCR-021 is not
promoted by this cell.  See `notes.md` for the exact missing feature.
