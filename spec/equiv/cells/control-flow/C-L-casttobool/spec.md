---
# Cell control-flow/C-L-casttobool
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-casttobool
family: control-flow
tool_status: both-green (symbolic, all byte values, element length 0-2)
precondition: |
  - no engine flags, scriptSig, or sigversion input: CastToBool is a pure
    predicate on one element.
  - the bounded element is (len, bytes) with len in {0,1,2}; three exported
    functions fix len at 0, 1 and 2 so Core's loop has a constant trip count.
  - every byte value is symbolic (2^8 for len 1, 2^16 for len 2).
postcondition: |
  - cell_cast_empty() == 0.
  - cell_cast_len1(b0) == 1 iff b0 is nonzero and not 0x80.
  - cell_cast_len2(b0,b1) == 1 iff b0 != 0, or b0 == 0 and b1 is nonzero
    and not 0x80 (the negative-zero test applies only to the last byte).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-057
scr_row_coverage: >-
  partial — lengths 0..2 only; lengths 3..520 are a stated domain gap.  The
  three named outcomes are: any nonzero
  byte is true, a lone 0x80 (negative zero) is false, and the empty vector is
  false. All three are exercised, and the special case `i == size-1 && 0x80`
  is exercised at the last position (len 1) and at a non-last position (len 2,
  first byte 0x80). Domain bound: element length is 0-2 bytes; lengths 3-520
  are not machine-enumerated by this cell and are a stated domain gap, not a
  fourth branch.
patches: none
source_citations:
  - interpreter.cpp:46-59 (bool CastToBool(const valtype& vch))
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at
  the pin: the CastToBool loop is verbatim and only vch.size() is fixed per
  function. L is the twin's bounded `cast_to_bool` helper, emitted verbatim
  from cells/_tools/mk_leaf.py (the same helper the twin uses for lengths
  <= 2); the exported wrappers are cell harness. Alive2 compares C and L over
  all byte values; SAW verifies both separately against an independent
  Cryptol predicate. This is a bounded predicate cell, not a whole-engine
  equivalence proof. No Core source patch is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: none (not a REDTEAM gate cell)
---
