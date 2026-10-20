---
# Cell push-encoding/C-L-w32-push-parse
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-w32-push-parse
family: push-encoding
tool_status: both-green (symbolic over 8 script bytes and length 0..8)
precondition: |
  - single opcode at offset 0 of an 8-byte script buffer; valid length n = 0..8.
  - the eight script bytes are symbolic; no earlier opcode executes, so no
    runtime error can precede a decode failure.
  - base sigversion; flags do not affect GetScriptOp.
  - EvalScript's element-size/op-count/disabled checks are not part of this
    cell; it is the decode step it calls (interpreter.cpp:487-488).
postcondition: |
  - parse success: ok=1, wire byte = script[0], data length and next offset
    exactly as GetScriptOp, payload lanes = script[next-dlen .. next-1].
  - PUSHDATA1/2/4: the length prefix is 1/2/4 LE bytes; if the prefix or the
    declared payload does not fit in the remaining script, parse fails.
  - parse failure: ok=0, error = SCRIPT_ERR_BAD_OPCODE (16), dlen=0, next=0.
  - both legs agree on both observables for every input.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-045
scr_row_coverage: >-
  full for the 8-byte domain — SCR-045 is "pushdata1/2/4 length parsing;
  truncation ⇒ false (⇒ BAD_OPCODE in EvalScript)".  The cell covers every
  opcode byte, every 1/2/4-byte LE length value, every truncation point of
  the length prefix and of the payload, and maps the failure to
  SCRIPT_ERR_BAD_OPCODE exactly as EvalScript does.  It is a single-opcode
  script, so the Lean eager-parse versus Core streaming error-precedence seam
  (F-DIV-001) is out of scope and cannot fire; scripts with a malformed tail
  after an earlier runtime error remain the F-DIV-001 seam and are not
  claimed here.
patches: none
source_citations:
  - script.cpp:313-363 (GetScriptOp)
  - interpreter.cpp:487-488 (GetOp failure => SCRIPT_ERR_BAD_OPCODE)
  - Parser/Defs.lean:206-229 (getOpAux / getOp)
  - Parser/Defs.lean:421-431 (parseWire, all-or-nothing)
  - twin/runtime.inc:242-283 (generated twin decode_op)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core script.cpp at the
  pin, restricted to pc = begin and an 8-byte buffer.  L is the Lean getOp
  transcribed from the generated twin's decode_op at offset 0.  Payload
  copying is bounded to 8 lanes; the payload sink is zero-filled for the
  unused lanes on both legs.  The cell proves the decode step and its
  BAD_OPCODE mapping for a one-opcode script, not EvalScript's ordering over
  multiple opcodes.  No Core source patch is used.
---
