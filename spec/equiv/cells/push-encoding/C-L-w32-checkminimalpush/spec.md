---
# Cell push-encoding/C-L-w32-checkminimalpush
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-w32-checkminimalpush
family: push-encoding
tool_status: both-green (symbolic; every call-site opcode and payload length)
precondition: |
  - base sigversion; SCRIPT_VERIFY_MINIMALDATA set, so fRequireMinimal = true.
  - the function is CheckMinimalPush at its only call site
    (interpreter.cpp:499-503), so 0 <= opcode <= OP_PUSHDATA4 (0x4e).
  - the payload is reduced to its read set: length n (uint64) and first
    payload byte b0.  CheckMinimalPush reads nothing else.
  - n is symbolic over the full 64-bit range; at EvalScript a push with
    n > 520 is rejected earlier by PUSH_SIZE (SCR-020).
postcondition: |
  - cell_minpush(n, b0, opcode) = 1 iff CheckMinimalPush(data, opcode) is
    true, 0 otherwise.  Both legs must agree for every input.
  - opcode > 0x4e is outside the call-site domain; both legs return the
    sentinel 2 there and the SAW proof is restricted to opcode <= 0x4e.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-048
scr_row_coverage: >-
  full — SCR-048 is "canonical push opcode for each data length (under
  MINIMALDATA)": the cell covers the whole CheckMinimalPush decision function
  for every payload length class (0, 1, 2..75, 76..255, 256..65535, >65535),
  every first-byte class that the function reads (0x01..0x10, 0x81, other),
  and every call-site opcode 0x00..0x4e.  It does not cover the fExec gate
  that decides whether the function is called (that is SCR-049, separate
  cell), nor PUSH_SIZE (SCR-020).
patches: none
source_citations:
  - script.cpp:373-396 (CheckMinimalPush)
  - interpreter.cpp:499-503 (the only call site; fExec and fRequireMinimal)
  - Defs.lean:529-537 (checkMinimalPush)
  - twin/runtime.inc:191-199 (generated twin transcription of the Lean def)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core script.cpp at the
  pin, reduced to the function's read set (data.size(), data[0]).  L is the
  Lean definition transcribed verbatim from the generated twin's
  check_minimal_push.  The tools compare the decision function only; they do
  not prove EvalScript, the fExec gate, or PUSH_SIZE.  No Core source patch is
  used.
---
