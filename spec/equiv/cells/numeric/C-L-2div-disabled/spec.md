---
# Cell numeric/C-L-2div-disabled
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: numeric/C-L-2div-disabled
family: numeric
tool_status: both-green
precondition: |
  - one-input script consisting of a single opcode; flags = 0, so
    DISCOURAGE_OP_SUCCESS is clear and any sigversion-specific policy flag is
    off.
  - cell_gate models EvalScript's wire gate (interpreter.cpp:471-489) for the
    whole 32-bit wire word: every opcode 0x00..0xff and every non-opcode word.
  - cell_tap_scan models ExecuteWitnessScript's OP_SUCCESSx pre-pass
    (interpreter.cpp:1846-1862) over a one-opcode tapscript, again for the
    whole 32-bit wire word.
postcondition: |
  - cell_gate: a wire in Core's 15-element disabled set yields
    (result 0, error 17 = DISABLED_OPCODE); every other wire yields
    (result 2 = "no terminal decision at this layer", error 0).
  - cell_tap_scan: a wire satisfying IsOpSuccess yields
    (result 1 = terminal success, error 0); every other wire yields
    (result 2, error 0).
  - wire 0x8e (OP_2DIV, script.h:156) is in the disabled set and in the
    OP_SUCCESS set (OP_SUCCESS142), so it is rejected in BASE and WITNESS_V0
    and succeeds in tapscript *without EvalScript ever running*.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-092
scr_row_coverage: >-
  partial — the EvalScript gate is proved C-vs-L for every wire word (this is
  the edge that decides 0x8e in BASE and WITNESS_V0), and the tapscript
  OP_SUCCESS142 pre-pass is proved on the C leg against the Cryptol model for
  every wire word.  What is not proved C-vs-L is the tapscript edge itself:
  the twin has no tapscript engine (witness v0/v1 and tapscript return
  TWIN_INVALID_UNSUPPORTED, result 3 — twin/generator.md:409, E4), so there is
  no L counterpart of ExecuteWitnessScript's pre-pass to compare against.
  Remaining gap: add the OP_SUCCESSx pre-pass to the twin, then compare it to
  cell_tap_scan with Alive2.  Nothing in the row is claimed as proved on the L
  side for tapscript.
patches: none
source_citations:
  - interpreter.cpp:471-489 (disabled-opcode disjunction; unconditional)
  - script.cpp:365-371 (IsOpSuccess, BIP342)
  - interpreter.cpp:1841-1862 (ExecuteWitnessScript OP_SUCCESSx pre-pass)
  - script.h:155-156 (OP_2MUL = 0x8d, OP_2DIV = 0x8e)
  - interpreter.cpp:897-923 (OP_EQUAL block; the OP_NOTEQUAL case is commented out)
  - runtime.inc:396-407 (twin disabled_wire)
  - runtime.inc:613-614 (twin applies disabled_wire before dispatch)
  - Defs.lean:455-462 (disabledWire), 463-469 (isOpSuccessWire),
    479-492 (opSuccessScan), 1213-1215 (ordered OP_SUCCESS rule)
trust_note: >
  C is a line-cited source-excerpt slice of interpreter.cpp and script.cpp at
  the pin: the disabled disjunction is transcribed with the opcode names and
  values from script.h, and IsOpSuccess verbatim.  L calls disabled_wire,
  which the generator copies byte-identically from twin/runtime.inc, so the L
  leg is the twin's own predicate rather than a re-transcription.  The
  result tags (0 error, 1 terminal success, 2 no decision) are cell harness
  naming the outcomes of the gate layer; they are not consensus values.
  Alive2 compares cell_gate C-vs-L; SAW verifies cell_gate on both legs and
  cell_tap_scan on the C leg against the independent Cryptol model
  tools/num.cry (pGate, pTapScan).  This is a wire-table cell, not an
  execution trace: it proves which wires each layer accepts or rejects, not
  what a longer script does after the gate.  No Core patch.
---
