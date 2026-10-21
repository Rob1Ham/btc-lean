---
# Cell control-flow/C-L-verify
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-verify
family: control-flow
tool_status: both-green (symbolic, all byte values, element length 0-2)
precondition: |
  - OP_VERIFY is modelled as dispatched (it is outside [OP_IF..OP_ENDIF], so
    Core reaches it only when fExec is true; the gate is covered by
    C-L-conditional-stack).
  - symbolic stack depth and the top element at a fixed length in {0,1,2},
    one exported function per length.
  - every byte value is symbolic (2^8 for len 1, 2^16 for len 2).
postcondition: |
  - depth == 0: INVALID_STACK_OPERATION (18), stack unchanged.
  - CastToBool(top) true: pop one element, success.
  - CastToBool(top) false: VERIFY (11), stack unchanged.
  - packed observable: result(2) | error(6) | depth(8)@8.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-068
scr_row_coverage: >-
  full branch coverage for the declared domain — the row names the two
  outcomes "pop iff true" and "else VERIFY"; both are exercised symbolically
  for every byte value at lengths 0-2 (including the empty element, which is
  false, and the negative-zero byte 0x80, which is also false), and the
  handler's third arm (empty stack, error 18) is exercised for symbolic depth.
  Domain bound: element length 0-2 (the twin leaf domain); lengths >= 3 are a
  stated domain gap, not an unexercised named branch.
patches: none
source_citations:
  - interpreter.cpp:663-675 (case OP_VERIFY)
  - interpreter.cpp:46-59 (CastToBool)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at
  the pin: the OP_VERIFY body is verbatim and CastToBool is inlined at each
  fixed element length. L is a direct transcription of the Lean model
  Defs.lean:901-904, using the twin's bounded cast_to_bool helper and
  core_ord error map from build/twin_ops.h. Alive2 compares C and L over all
  inputs; SAW verifies each leg separately against an independent Cryptol
  predicate. This is a bounded single-op cell, not a whole-engine equivalence
  proof. No Core source patch is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: none (not a REDTEAM gate cell)
---
