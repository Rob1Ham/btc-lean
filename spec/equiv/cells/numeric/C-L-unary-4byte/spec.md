---
# Cell numeric/C-L-unary-4byte
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: numeric/C-L-unary-4byte
family: numeric
tool_status: both-green
precondition: |
  - flags = 0 (so fRequireMinimal = false, MINIMALDATA off); one input; no
    cleanstack.  The CScriptNum nMaxNumSize keeps its default of 4.
  - closed dispatch to one of wires 0x8b (OP_1ADD), 0x8c (OP_1SUB),
    0x8f (OP_NEGATE), 0x90 (OP_ABS), 0x91 (OP_NOT), 0x92 (OP_0NOTEQUAL);
    the entry stack is exactly [x] and no other opcode executes.
  - x is a bounded element of length `lb & 7`: for lengths 0..4 every 4-byte
    CScriptNum operand occurs (content word symbolic over 2^32); lengths 5..7
    are the nMaxNumSize reject edge.  Element width 8 (bounded leaf).
postcondition: |
  - SCRIPTNUM error (x longer than 4 bytes): result 0, error 4, no stack
    (the script has failed; the ABI observable carries no stack after error).
  - otherwise let v be the int64 result of the case body.  v is serialized by
    CScriptNum::serialize and pushed as the only stack element; VerifyScript's
    tail then observes result 1 (v != 0) or result 0 / error 2 (EVAL_FALSE,
    v == 0) with depth 1 and the serialized bytes of v.
  - packed observable: result(2) | error(6)<<2 | depth(3)<<8 | len(4)<<11 |
    bytes 0..4<<15 (see findings/wave16/07-numeric-ops/tools/num_common.h).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-087
scr_row_coverage: >-
  full — all six opcodes of the row (1ADD, 1SUB, NEGATE, ABS, NOT, 0NOTEQUAL)
  are proved, each over the complete length domain 0..7 of the bounded leaf:
  every 4-byte operand (lengths 0..4, content symbolic over 2^32) plus the
  nMaxNumSize reject edge (lengths 5..7).  The minimality guard is off by the
  flags = 0 domain and the stack-underflow branch is SCR-078's row, not this
  one.
patches: none
source_citations:
  - interpreter.cpp:929-953 (case OP_1ADD .. OP_0NOTEQUAL)
  - script.h:246-271 (CScriptNum constructor, width and minimality guards)
  - script.h:342-373 (CScriptNum::serialize)
  - script.h:376-391 (set_vch sign-magnitude decode)
  - interpreter.cpp:423-425 (vchTrue/vchFalse statics)
  - interpreter.cpp:46-61 (CastToBool)
  - interpreter.cpp:1877-1878 (VerifyScript tail, EVAL_FALSE)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp and
  script.h at the pin, not the whole EvalScript.  The slice is specialised to
  flags = 0, so the MINIMALDATA guard is settled false; operand length is a
  symbolic input of the harness, so the width guard is exercised, not assumed.
  L uses the six op_* handlers copied verbatim from twin/ops_ir.py by
  findings/wave16/07-numeric-ops/tools/mk_num_leaf.py; init/push/tail/pack is
  cell harness.  The bounded runtime primitives (decode_num, encode_num,
  cast_to_bool, memcpy, memcmp) are the twin/runtime.inc bodies unrolled to an
  8-byte element; the rewrite of serialize into a constant-indexed little-
  endian word is byte-for-byte equal in output and is documented in notes.md.
  Alive2 compares C and L directly; SAW verifies both against an independent
  Cryptol model (tools/num.cry) written from script.h/interpreter.cpp and the
  Lean equations.  The model was cross-checked against the C leg on 200k
  random and structured samples.  This is a bounded op cell, not a whole-engine
  equivalence proof.  No Core source patch is used.
---
