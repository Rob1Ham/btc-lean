---
# Cell control-flow/C-L-if-notif
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-if-notif
family: control-flow
tool_status: both-green (symbolic, all byte values, element length 0-2)
precondition: |
  - one dispatch of OP_IF or OP_NOTIF in isolation; no other opcode runs.
  - leaf inputs: opcode (IF/NOTIF), fExec, sigversion (0=base,
    1=witnessV0, 2=tapscript), SCRIPT_VERIFY_MINIMALIF flag, stack depth,
    and the top element at a fixed length in {0,1,2}.
  - the condition stack is empty before the opcode (vfExec.back() is
    undefined), so the cell observes the pushed value and the new depth.
  - every byte value is symbolic (2^8 for len 1, 2^16 for len 2); stack
    depth is symbolic.
postcondition: |
  - fExec == false: success, push false, no pop, argument not inspected.
  - fExec == true and depth == 0: INVALID_STACK_OPERATION (18).
  - TAPSCRIPT and argument not in {{}, {1}}: TAPSCRIPT_MINIMALIF (51).
  - WITNESS_V0 with the MINIMALIF flag and argument not in {{}, {1}}:
    MINIMALIF (31).
  - otherwise: push CastToBool(arg), inverted for NOTIF, and pop one element.
  - packed observable: result(2) | error(6) | depth(8) | vf_n(2) | vf0(1).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-056, SCR-058, SCR-059, SCR-060
scr_row_coverage: >-
  full branch coverage for the declared domain — SCR-056 (CastToBool of the
  top, NOTIF inverts, then pop) is exercised for every byte value at lengths
  0-2 and for IF and NOTIF; SCR-058 is the TAPSCRIPT minimal-argument arm
  (error 51) together with its accepting arm; SCR-059 is the witness-v0
  MINIMALIF policy arm (error 31) with the flag both set and clear; SCR-060 is
  the fExec=false arm, where the cell shows the element is neither inspected
  nor popped (depth unchanged, vf0=false). Domain bound: element length 0-2
  (the twin leaf domain) and a single opcode; lengths >= 3 are a stated domain
  gap, not an unexercised named branch. sigversion values outside {0,1,2} are
  unreachable enum values and behave as base in both legs.
patches: none
source_citations:
  - interpreter.cpp:613-645 (case OP_IF / OP_NOTIF)
  - interpreter.cpp:46-59 (CastToBool)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at
  the pin: the OP_IF/OP_NOTIF case body is verbatim, CastToBool is inlined at
  each fixed length, and only the element length is fixed per exported
  function. L is a direct transcription of the Lean model
  spec/core/Bitcoin/Interpreter/Defs.lean:878-891, not twin/ops_ir.py's OP_IF
  handler (see notes.md: that handler omits both MINIMALIF arms). Alive2
  compares C and L over all inputs; SAW verifies each leg separately against
  an independent Cryptol predicate. This is a bounded single-op cell, not a
  whole-engine equivalence proof. No Core source patch is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: none (not a REDTEAM gate cell)
---
