---
# Cell e2-numeric/C-L-w32-disabled-2div
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: e2-numeric/C-L-w32-disabled-2div
family: numeric
tool_status: both-green (symbolic; legacy/witness-v0 every fExec, tapscript every 2-byte script and both discourage values)
precondition: |
  - one script consisting of the single opcode wire 0x8e (OP_2DIV) for the
    legacy/witness-v0 arms; fExec is symbolic (executed or unexecuted).
  - for the tapscript arm, a two-byte script [b0, b1] with every byte value
    symbolic, and empty initial main and alt stacks.
  - flags = 0 except that the tapscript arm leaves DISCOURAGE_OP_SUCCESS
    symbolic; base sigversion for `cell_base`, witness-v0 for
    `cell_witness_v0`, tapscript for `cell_tapscript`.
postcondition: |
  - legacy and witness-v0: SCRIPT_ERR_DISABLED_OPCODE (17) with an empty
    stack, for both fExec values.  The disabled check precedes the fExec
    branch, so an unexecuted 0x8e is still rejected.
  - tapscript: ExecuteWitnessScript's OP_SUCCESS pre-scan decodes the script
    with GetOp and returns success (result=1) the moment it decodes an
    OP_SUCCESS opcode; 0x8e is OP_SUCCESS142 (141..142 in IsOpSuccess), so
    [0x8e, b1] and [b0, 0x8e] where 0x8e is decoded as an opcode succeed
    with an empty stack.  With DISCOURAGE_OP_SUCCESS the same scan returns
    SCRIPT_ERR_DISCOURAGE_OP_SUCCESS (36).
  - if the scan decodes no OP_SUCCESS (0x8e was push data, or a truncated
    push fails to decode), the cell returns the harness sentinel result=3,
    error=1: the rest of tapscript execution is outside this cell.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-092
scr_row_coverage: >-
  full — the row's three edges are all covered: (a) 0x8e is OP_2DIV and is
  in the disabled list, so legacy and witness-v0 reject it with error 17
  before fExec (symbolically for both fExec values); (b) tapscript treats it
  as OP_SUCCESS142, and the cell verifies the GetOp-decoded pre-scan for
  every two-byte tapscript, including when 0x8e is opcode 0 at index 0 or
  opcode 1 at index 1, and including scripts whose trailing bytes would not
  decode; (c) DISCOURAGE_OP_SUCCESS yields error 36.  The cell also shows the
  scan tests decoded opcodes, not raw bytes, by including the push-consuming
  cases.  Full script validation after a negative pre-scan (and >2-byte
  scripts) is outside this cell but is not an edge named by SCR-092.
patches: none
source_citations:
  - script.h:155-156 (OP_2MUL = 0x8d, OP_2DIV = 0x8e; no OP_NOTEQUAL)
  - interpreter.cpp:443-467 (EvalScript prologue; disabled check before fExec)
  - interpreter.cpp:1846-1862 (ExecuteWitnessScript tapscript pre-scan)
  - script.cpp:365-371 (IsOpSuccess; 141..142 includes 0x8e)
  - script.cpp:313-363 (CScript::GetOp)
  - interpreter.cpp:70 (SCRIPT_ERR_DISCOURAGE_OP_SUCCESS)
  - Defs.lean:455-462 (disabledWire), 463-476 (isOpSuccessWire)
  - Defs.lean:479-492 (opSuccessScan), 815-845 (stepBody check 3)
  - Defs.lean:1211-1216 (executeWitnessScript tapscript branch)
  - Lean Parser/Defs.lean:206-229 (getOpAux / getOp)
trust_note: >
  C is a line-cited source-excerpt slice of Core's EvalScript prologue,
  ExecuteWitnessScript pre-scan and CScript::GetOp at the pin.  L is a
  reviewed transliteration of the Lean interpreter definitions, not a
  twin/ops_ir.py handler: the twin's runtime has no tapscript OP_SUCCESS
  pre-scan and applies its disabled_wire under every sigversion
  (twin/runtime.inc:613-614), so a verbatim twin handler would be the wrong
  model for the tapscript arm.  src/ops.txt is therefore empty and the
  provenance gate is not applicable; the transliteration is bounded to the
  two-byte script and is loop-free.  The packed observable is shared harness.
  This is a bounded op cell, not a whole-engine equivalence proof.  No Core
  source patch is used.
---
