---
# Cell control-flow/C-L-opcount
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-opcount
family: control-flow
tool_status: both-green (symbolic, all 256 wire opcodes and symbolic counter)
precondition: |
  - a single opcode-budget step: symbolic sigversion, symbolic 8-bit wire
    opcode, and a symbolic starting counter.
  - no stack, flags, or script bytes: the budget block reads only the
    sigversion, the opcode, and the counter.
postcondition: |
  - BASE and WITNESS_V0 charge one opcode iff wire > OP_16 (0x60);
    tapscript never charges.
  - the counter is incremented by exactly one per charged opcode.
  - the script fails with OP_COUNT (7) iff the charged counter exceeds 201
    (MAX_OPS_PER_SCRIPT); otherwise success.
  - packed observable: result(2) | error(6) | opCount(9)@8.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-067
scr_row_coverage: >-
  full — the row is "each IF counts 1 opcode". The proof is symbolic over all
  256 wire values, so it includes OP_IF = 0x63 and proves the increment is
  exactly one for it; it also covers the non-counting class (wire <= 0x60,
  including OP_RESERVED and small pushes), the tapscript no-count arm, and the
  counter boundary (201 succeeds, 202 is OP_COUNT). Missing: nothing named by
  the row; the cell proves the step, not a whole-script accumulation, which is
  a domain bound stated in notes.md.
patches: none
source_citations:
  - interpreter.cpp:459-463 (opcode budget; MAX_OPS_PER_SCRIPT == 201)
  - script.h (OP_16 == 0x60)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at
  the pin: the budget block is verbatim and only the counter is carried in the
  leaf. L is a direct transcription of the Lean budget step
  Defs.lean:824-829; the error ordinal comes from core_ord(TWIN_OP_COUNT).
  Alive2 compares C and L over all inputs; SAW verifies each leg separately
  against an independent Cryptol predicate. This is a bounded single-step
  cell, not a whole-script proof. No Core source patch is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: none (not a REDTEAM gate cell)
---
