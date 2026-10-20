---
# Cell push-encoding/C-L-pushonly
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-pushonly
family: push-encoding
tool_status: both-green (symbolic bounded laws)
precondition: |
  - script length 1 (one symbolic byte) and 2 (two symbolic bytes).
  - every byte value 0..255 is symbolic; no stack is involved.
postcondition: |
  - true iff every decoded opcode is <= OP_16 (0x60) and every push decodes;
    truncated length fields make the answer false.
  - OP_RESERVED (0x50) is push-type (row SCR-052's explicit case).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-052
scr_row_coverage: full — the row is the per-opcode membership rule
  (opcode <= OP_16 counts as push, OP_RESERVED included). Every opcode byte is
  symbolic in the 1-byte law, and the 2-byte law additionally covers the
  pc-advance step and the truncation arm of the loop.
patches: none
source_citations:
  - src/script/script.cpp:266-286 (IsPushOnly, and the OP_RESERVED comment)
  - src/script/script.cpp:313-363 (GetScriptOp, inlined into the unrolled loop)
trust_note: >
  C is a line-cited source-excerpt slice; IsPushOnly's while loop is unrolled
  for the 1- and 2-byte scripts this cell feeds (GetScriptOp advances pc by at
  least one byte, so two guarded steps are exactly the loop). L mirrors the same
  loop with the twin's verbatim decode_op and wire test; classify_push_only's
  `while (i < size)` is unrolled for the same reason (SAW cannot execute a
  symbolically bounded loop). No source patch.
---
