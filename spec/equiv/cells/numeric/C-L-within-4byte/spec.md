---
# Cell numeric/C-L-within-4byte
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: numeric/C-L-within-4byte
family: numeric
tool_status: both-green
precondition: |
  - flags = 0 (fRequireMinimal false, MINIMALDATA off); one input; no
    cleanstack; nMaxNumSize default 4.
  - closed dispatch to wire 0xa5 (OP_WITHIN); the entry stack is exactly
    [x, min, max] (top element is max) and no other opcode executes.
  - each of x, min, max is a bounded element of length `l & 7`: every 4-byte
    CScriptNum operand for lengths 0..4, lengths 5..7 are the nMaxNumSize
    reject edge.  Element width 8, stack depth 4 (bounded leaf).
postcondition: |
  - SCRIPTNUM error on x, then min, then max (first failure wins, left to
    right): result 0, error 4, no stack.
  - else if min <= x && x < max: push vchTrue = {1}; result 1, error 0,
    depth 1, len 1, byte0 1.
  - else: push vchFalse = {}; the tail rejects the empty top; result 0,
    error 2 (EVAL_FALSE), depth 1, len 0.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-089
scr_row_coverage: >-
  full — the cell is symbolic over the whole bounded operand domain: x, min
  and max each range over every content word (2^32) and length 0..7, i.e. all
  4-byte CScriptNum operands plus the SCR-079/SCR-080 width-cap reject edge.
  This extends cells/e2-numeric/within-boundary, which covered one-byte
  operands only, to the full 4-byte row.  Stack underflow (< 3 operands) is
  SCR-078's row; the minimality guard is off by the flags = 0 domain.
patches: none
source_citations:
  - interpreter.cpp:1012-1026 (case OP_WITHIN)
  - interpreter.cpp:1020 (bn2 <= bn1 && bn1 < bn3)
  - script.h:246-271 (CScriptNum constructor, width and minimality guards)
  - script.h:376-391 (set_vch sign-magnitude decode)
  - interpreter.cpp:423-425 (vchTrue/vchFalse statics)
  - interpreter.cpp:46-61 (CastToBool)
  - interpreter.cpp:1877-1878 (VerifyScript tail, EVAL_FALSE)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp and
  script.h at the pin.  The three operands are decoded in Core's order, so the
  error precedence is exercised rather than assumed.  L uses op_OP_WITHIN
  copied verbatim from twin/ops_ir.py by
  findings/wave16/07-numeric-ops/tools/mk_num_leaf.py; init/push/tail/pack is
  cell harness.  Alive2 compares C and L directly; SAW verifies both against
  the independent Cryptol model tools/num.cry:pWithin.  Bounded op cell, not a
  whole-engine equivalence proof.  No Core patch.
---
