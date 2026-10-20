---
# Cell e2-numeric/within-boundary
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: e2-numeric/within-boundary
family: numeric
tool_status: both-green (symbolic, all one-byte operand triples)
precondition: |
  - base sigversion; flags = 0; minimalData = false; one input.
  - the leaf starts with stack [x, min, max], each element exactly one byte
    (the top element is max, then min, then x).
  - closed dispatch to wire 0xa5 (OP_WITHIN); no other opcode executes.
  - bounded leaf domain: element length 1, stack depth 4.
postcondition: |
  - if min <= x < max: the op pushes vchTrue = {1}; packed observable
    0x0000000000002901 (result=1, error=0, depth=1, len=1, val=1).
  - otherwise: the op pushes vchFalse = {}; VerifyScript's tail rejects the
    empty top with EVAL_FALSE; packed observable 0x0000000000000108
    (result=0, error=2, depth=1, len=0, val=0).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-089
scr_row_coverage: >-
  partial — the cell is symbolic over all 2^24 single-byte
  operand triples, which is the full half-open-interval rule for one-byte
  CScriptNum operands. It does not exercise 2-4 byte operands or the
  SCR-079/SCR-080 width cap, nor the stack-underflow branch of SCR-078;
  those are separate rows/gaps, not hidden extensions of this cell.
patches: none
source_citations:
  - interpreter.cpp:1012-1026 (case OP_WITHIN)
  - interpreter.cpp:1020 (bn2 <= bn1 && bn1 < bn3)
  - script.h:246-271 (CScriptNum width and minimality guards)
  - script.h:376-391 (set_vch one-byte sign-magnitude)
  - interpreter.cpp:46-61 (CastToBool)
  - interpreter.cpp:423-425 (vchTrue/vchFalse statics)
  - interpreter.cpp:1878 (EVAL_FALSE tail)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp and
  script.h at the pin, not the whole EvalScript. The slice fixes operand
  length to one byte, so the CScriptNum width guard is provably settled
  (1 <= 4) and the minimality guard is off (minimalData = false). L uses the
  OP_WITHIN handler copied verbatim from twin/ops_ir.py by
  cells/_tools/mk_leaf.py; init/dispatch/finish/pack is cell harness. Alive2
  compares C and L over all i8 inputs; SAW verifies both separately against
  an independent Cryptol predicate for all 2^24 triples. The packed
  observable canonicalises empty elements to value 0 because Core's
  vchFalse is the empty vector. This is a bounded op cell, not a whole-engine
  equivalence proof. No Core source patch is used.
---
