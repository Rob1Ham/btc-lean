---
# Cell control-flow/C-L-conditional-stack
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-conditional-stack
family: control-flow
tool_status: both-green (symbolic, bounded condition stack depth 0-2)
precondition: |
  - one dispatch followed by loop exit; the opcode selector is 0=OP_ELSE
    (0x67), 1=OP_ENDIF (0x68), anything else=OP_NOP (0x61).
  - symbolic fExec and symbolic condition stack (n in {0,1,2}, top bit and
    second bit); n > 2 is outside the cell domain.
  - no value stack, no flags, no sigversion input: these opcodes do not read
    them.
postcondition: |
  - OP_NOP with fExec == false is skipped by the [OP_IF..OP_ENDIF] gate: the
    switch body does not run and the condition stack is unchanged.
  - OP_ELSE/OP_ENDIF are in [OP_IF..OP_ENDIF], so they are dispatched even
    when fExec == false.
  - OP_ELSE on an empty condition stack: UNBALANCED_CONDITIONAL (20);
    otherwise the top is toggled.
  - OP_ENDIF on an empty condition stack: UNBALANCED_CONDITIONAL (20);
    otherwise one entry is popped.
  - after the dispatch, a non-empty condition stack is
    UNBALANCED_CONDITIONAL (20) at loop exit.
  - packed observable: result(2) | error(6) | n(2) | v0 | v1 | executed.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-061, SCR-062, SCR-063, SCR-064
scr_row_coverage: >-
  full branch coverage for the declared one-dispatch domain — SCR-061 is
  OP_ELSE with a non-empty stack (toggle) and with an empty stack (error 20);
  SCR-062 is OP_ENDIF with an empty stack (error 20) alongside the popping
  arm; SCR-063 is the loop-exit check on a non-empty condition stack (error
  20, reached by a skipped OP_NOP and by OP_ENDIF leaving depth 1); SCR-064 is
  the gate itself, showing an in-range opcode dispatched with fExec=false and
  an out-of-range opcode skipped. Missing from this cell: full script
  sequencing (more than one opcode), nesting deeper than 2, and the IF/NOTIF
  push side (separate cell C-L-if-notif). Those are domain bounds of the
  abstraction, not unexercised named branches.
patches: none
source_citations:
  - interpreter.cpp:493 (fExec || [OP_IF..OP_ENDIF] dispatch gate)
  - interpreter.cpp:647-653 (case OP_ELSE)
  - interpreter.cpp:655-661 (case OP_ENDIF)
  - interpreter.cpp:1245-1246 (non-empty condition stack after the loop)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at
  the pin: the two case bodies and the pre-dispatch gate are verbatim, and the
  loop-exit check is the same predicate; only the condition-stack container is
  replaced by the bounded (n, v0, v1) harness struct. L is a direct
  transcription of the Lean model Defs.lean:893-900 plus the gate at
  Defs.lean:851-853 and the final non-empty check; error ordinals come from
  core_ord. Alive2 compares C and L over all inputs; SAW verifies each leg
  separately against an independent Cryptol predicate. This is a bounded
  one-dispatch cell, not a whole-script proof. No Core source patch is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: none (not a REDTEAM gate cell)
---
