---
# Cell push-encoding/C-L-w32-fexec-push
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-w32-fexec-push
family: push-encoding
tool_status: both-green (bounded symbolic over MINIMALDATA, two fixed scripts)
precondition: |
  - base sigversion; empty input stack; MINIMALDATA symbolic (both values).
  - fixed 6-byte script [cond, OP_IF, 0x01 0x01, OP_ENDIF, OP_1], where the
    direct push 0x01 0x01 carries the one-byte value {1} and is non-minimal
    (canonical encoding is OP_1).
  - cond = OP_0 (empty/false) or OP_1 (true): cell_fexec_false /
    cell_fexec_true.
  - no other opcode executes; the executor is a six-step unrolled slice, not
    a general loop.
postcondition: |
  - cond = OP_0: the IF branch is not taken, the non-minimal push is
    unexecuted, and the script passes with stack [{1}] for either MINIMALDATA
    value.
  - cond = OP_1: with MINIMALDATA off the push executes and the script passes
    with stack [{1},{1}]; with MINIMALDATA on the executed non-minimal push
    fails with SCRIPT_ERR_MINIMALDATA (25).
  - packed observable: res(2) | err(6) | depth(2) | top len(2) | top byte(8);
    both legs agree for every MINIMALDATA value.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-049
scr_row_coverage: >-
  full for the row's premise — SCR-049 is "fExec-gated (unexecuted non-minimal
  pushes OK)".  The cell exercises the gate from a script whose fExec is
  derived by executing OP_0/OP_1 + OP_IF, not from an assumed bit; it proves
  the unexecuted non-minimal push is not an error under MINIMALDATA and that
  the same push is an error when executed.  It does not cover other fExec
  constructions (ELSE, nested IF, NOTIF) or multi-byte payloads; those are
  wider E2/E5 work, not hidden extensions of this cell.
patches: none
source_citations:
  - interpreter.cpp:476-503 (GetOp, size, op budget, disabled, fExec push gate)
  - interpreter.cpp:613-661 (OP_IF/OP_NOTIF/OP_ENDIF, unexecuted IF pushes false)
  - interpreter.cpp:527-546 (OP_1 push)
  - script.cpp:373-396 (CheckMinimalPush)
  - interpreter.cpp:1876-1880 (EVAL_FALSE tail)
  - Defs.lean:816-846 (stepBody order and fExec push gate)
  - Defs.lean:878-900 (OP_IF/NOTIF/ENDIF)
  - twin/runtime.inc:607-640 (generated twin loop shape)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at
  the pin, specialised to the fixed six-byte script and a <=1-byte element
  domain.  L is the Lean stepBody/OP_IF/ENDIF semantics transcribed from the
  generated twin.  The loop is unrolled exactly six times because the script
  is fixed; this is a bounded script cell, not an EvalScript loop proof.  No
  Core source patch is used.
---
