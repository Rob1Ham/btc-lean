---
# Cell control-flow/C-L-bad-opcode
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-bad-opcode
family: control-flow
tool_status: both-green (symbolic over wire class, fExec, sigversion, opCount)
precondition: |
  - one dispatch of a selected wire opcode: 0=OP_RESERVED (0x50),
    1=OP_VER (0x62), 2=OP_VERIF (0x65), 3=OP_VERNOTIF (0x66).
  - symbolic fExec, symbolic sigversion (0=base, 1=witnessV0, 2=tapscript),
    and symbolic starting opcode counter.
  - no value stack: none of these opcodes reads the stack; the counter is
    observed because the budget is charged before dispatch.
postcondition: |
  - the opcode budget is charged first: BASE/WITNESS_V0 and wire > 0x60
    increment the counter, and 202 or more is OP_COUNT (7), which takes
    precedence over BAD_OPCODE.
  - OP_VERIF/OP_VERNOTIF are inside [OP_IF..OP_ENDIF], so they are dispatched
    even when fExec == false and are BAD_OPCODE (16) in unexecuted branches.
  - OP_RESERVED/OP_VER are skipped when fExec == false (success, counter
    still charged for OP_VER) and are BAD_OPCODE (16) when executed.
  - packed observable: result(2) | error(6) | opCount(9)@8.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-065, SCR-066
scr_row_coverage: >-
  full branch coverage — SCR-065 is the unexecuted-branch BAD_OPCODE arm
  (OP_VERIF and OP_VERNOTIF with fExec=false, error 16) and it also exercises
  the budget-before-dispatch precedence; SCR-066 is BAD_OPCODE when executed
  (all four wires with fExec=true) and the unexecuted OP_VER/OP_RESERVED arm
  that passes without BAD_OPCODE. Both rows are covered for every byte class,
  both sigversion counting modes, and the full counter range. Missing: the
  other default-arm opcodes (OP_RESERVED1/OP_RESERVED2) are the same default
  branch and are not separately instantiated; they are the same branch, not
  an unexercised named branch.
patches: none
source_citations:
  - interpreter.cpp:459-463 (opcode budget, MAX_OPS_PER_SCRIPT == 201)
  - interpreter.cpp:493 (fExec || [OP_IF..OP_ENDIF] dispatch gate)
  - interpreter.cpp:1227-1228 (default: SCRIPT_ERR_BAD_OPCODE)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at
  the pin: the budget block, the gate, and the `default:` BAD_OPCODE return are
  verbatim; the wire selector is cell harness. L is a direct transcription of
  the Lean model Defs.lean:824-829 (budget), :851-853 (gate), and the
  `.badOpcode` arms; error ordinals come from core_ord. Alive2 compares C and
  L over all inputs; SAW verifies each leg separately against an independent
  Cryptol predicate. This is a bounded single-dispatch cell, not a
  whole-script proof. No Core source patch is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: none (not a REDTEAM gate cell)
---
