---
# Cell numeric/C-L-binary-4byte
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: numeric/C-L-binary-4byte
family: numeric
tool_status: both-green
precondition: |
  - flags = 0 (fRequireMinimal false, MINIMALDATA off); one input; no
    cleanstack; nMaxNumSize default 4.
  - closed dispatch to one of the 13 wires 0x93 (ADD), 0x94 (SUB),
    0x9a (BOOLAND), 0x9b (BOOLOR), 0x9c (NUMEQUAL), 0x9d (NUMEQUALVERIFY),
    0x9e (NUMNOTEQUAL), 0x9f (LESSTHAN), 0xa0 (GREATERTHAN),
    0xa1 (LESSTHANOREQUAL), 0xa2 (GREATERTHANOREQUAL), 0xa3 (MIN),
    0xa4 (MAX); the entry stack is exactly [a, b] and no other opcode
    executes.
  - a and b are bounded elements of length `la & 7`, `lb & 7`: every 4-byte
    CScriptNum operand for lengths 0..4 (content symbolic over 2^32 each),
    lengths 5..7 are the nMaxNumSize reject edge.  Element width 8 absorbs the
    5-byte result of ADD/SUB.
postcondition: |
  - SCRIPTNUM error on either operand (length > 4): result 0, error 4, no
    stack.
  - the 12 pushing wires: the case body computes int64 v, serializes it and
    pushes it as the only element; the VerifyScript tail observes result 1
    (v != 0) or result 0 / error 2 (EVAL_FALSE, v == 0), depth 1, with the
    serialized bytes of v in the packed observable.
  - OP_NUMEQUALVERIFY (0x9d): false result 15 (NUMEQUALVERIFY) and no stack;
    a true comparison drops both operands, so the script ends with an empty
    stack and the tail observes result 0 / error 2 (EVAL_FALSE).  Core has
    already pushed the bool before erroring in the false arm; that stack state
    is not observable after an error (ABI: the observable carries no stack
    once the script has failed), so the asymmetry with the twin is harmless.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows:
  - SCR-088
  - SCR-090
scr_row_coverage: >-
  full — SCR-088: all 12 pushing wires of the row are proved over the complete
  length domain 0..7, including the numeric comparison family and MIN/MAX;
  OP_NUMEQUALVERIFY's success arm (both operands dropped, empty-stack
  EVAL_FALSE) is included, which the row note listed as not yet proved.
  SCR-090: the false arm is proved to return error 15 (NUMEQUALVERIFY) with no
  stack, for every operand pair, and the true arm is proved to return the
  empty-stack EVAL_FALSE tail.  The minimality guard is off by the flags = 0
  domain; stack underflow is SCR-078's row.
patches: none
source_citations:
  - interpreter.cpp:955-1010 (case OP_ADD .. OP_MAX)
  - interpreter.cpp:1002-1008 (OP_NUMEQUALVERIFY false => NUMEQUALVERIFY)
  - script.h:246-271 (CScriptNum constructor, width and minimality guards)
  - script.h:342-373 (CScriptNum::serialize)
  - script.h:376-391 (set_vch sign-magnitude decode)
  - interpreter.cpp:423-425 (vchTrue/vchFalse statics)
  - interpreter.cpp:46-61 (CastToBool)
  - interpreter.cpp:1877-1878 (VerifyScript tail, EVAL_FALSE)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp and
  script.h at the pin.  It is specialised to flags = 0, so the MINIMALDATA
  guard is settled false; operand lengths are symbolic, so the width guard is
  exercised.  L uses the 13 op_* handlers copied verbatim from
  twin/ops_ir.py by findings/wave16/07-numeric-ops/tools/mk_num_leaf.py;
  init/push/tail/pack is cell harness.  The bounded primitives are the
  twin/runtime.inc bodies unrolled to an 8-byte element, and serialize is
  re-expressed as a constant-indexed little-endian word with identical output
  (the variable-index form makes Alive2's UB query quantified; see notes.md).
  ADD and SUB need --smt-to=600000 to close.  Alive2 compares C and L
  directly; SAW verifies both against the independent Cryptol model
  tools/num.cry (pBinary).  The model was cross-checked against the C leg.
  Bounded op cell, not a whole-engine equivalence proof.  No Core patch.
---
