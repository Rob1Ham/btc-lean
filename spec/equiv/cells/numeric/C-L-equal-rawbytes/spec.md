---
# Cell numeric/C-L-equal-rawbytes
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: numeric/C-L-equal-rawbytes
family: numeric
tool_status: both-green
precondition: |
  - flags = 0; one input; no cleanstack.  The opcode never decodes a
    CScriptNum, so neither the width cap nor the minimality guard applies.
  - closed dispatch to wire 0x87 (OP_EQUAL) or 0x88 (OP_EQUALVERIFY); the
    entry stack is exactly [a, b] and no other opcode executes.
  - a and b are bounded 8-byte elements of length `num_len8(l)`: the harness
    exposes a 4-bit length and folds 9..15 to 8, so every length 0..8 occurs
    and the content of each element is symbolic over 2^64.
postcondition: |
  - OP_EQUAL: push vchTrue {1} when the raw elements are equal (same length
    and same bytes) -> result 1, error 0, depth 1, len 1, byte0 1; otherwise
    push vchFalse {} and the tail rejects it -> result 0, error 2
    (EVAL_FALSE), depth 1, len 0.
  - OP_EQUALVERIFY: on equality both operands are dropped and the script ends
    with an empty stack, so the tail observes result 0, error 2
    (EVAL_FALSE); on inequality the op returns error 12 (EQUALVERIFY) with no
    stack.  Core has already pushed the bool before erroring; that stack state
    is not observable after an error.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-091
scr_row_coverage: >-
  full — the row's claim is "raw bytes, not numeric": both wires are proved
  for equal and unequal pairs, for every element length 0..8 (including the
  length-mismatch edge and the empty element), over a content domain of 2^64
  per element.  No CScriptNum decode is reachable, which is what the row
  asserts.  Element width 8 is a bounded-leaf representation constant (like
  depth 4), not a consensus limit: the comparison is Core's length-then-bytes
  rule and its byte loop is unrolled to 8.
patches: none
source_citations:
  - interpreter.cpp:897-923 (case OP_EQUAL / OP_EQUALVERIFY)
  - interpreter.cpp:906 (bool fEqual = (vch1 == vch2))
  - interpreter.cpp:907-911 (commented-out OP_NOTEQUAL case; 0x8e is OP_2DIV)
  - interpreter.cpp:916 (push_back(fEqual ? vchTrue : vchFalse))
  - interpreter.cpp:919-922 (EQUALVERIFY pop / SCRIPT_ERR_EQUALVERIFY)
  - interpreter.cpp:423-425 (vchTrue/vchFalse statics)
  - interpreter.cpp:1877-1878 (VerifyScript tail, EVAL_FALSE)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at the
  pin; the valtype comparison is transcribed as a constant-index chain guarded
  by the equal length (a std::vector compare is length first and then exactly
  len bytes).  L uses op_OP_EQUAL copied verbatim from twin/ops_ir.py by
  findings/wave16/07-numeric-ops/tools/mk_num_leaf.py, with its std::memcmp
  rebound to the twin's bounded_memcmp.  Init/push/tail/pack is cell harness.
  Alive2 compares C and L directly over 2 x 64-bit content words and 4-bit
  lengths; SAW verifies both against the independent Cryptol model
  tools/num.cry:pEqual.  That model initially compared all eight bytes
  regardless of length and SAW produced a counterexample; the model was wrong,
  not the legs (see notes.md).  Bounded op cell, not a whole-engine
  equivalence proof.  No Core patch.
---
