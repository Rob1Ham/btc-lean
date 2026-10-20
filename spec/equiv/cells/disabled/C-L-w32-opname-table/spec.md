---
# Cell disabled/C-L-w32-opname-table
contract: b547fafb5fc5a6c3370f916d800418db37dec7c78d88fc4cd209a436a6a6e187
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: disabled/C-L-w32-opname-table
family: disabled-opcodes
tool_status: both-green (symbolic, all 256 wire bytes)
precondition: |
  - `w` is a wire byte 0x00..0xff.  No script, flags, stack, or tx context.
  - cell_opname returns the name id assigned by src/gen_opname.py: 0 for
    "OP_UNKNOWN", otherwise a positive index into the sorted union of every
    name literal in the two tables.
postcondition: |
  - every byte with a GetOpName case returns that case's name id, including
    the fifteen disabled bytes (0x7e..0x99) and 0xff OP_INVALIDOPCODE;
  - every byte without a case returns 0 = "OP_UNKNOWN": the direct-push
    bytes 0x01..0x4b and the reserved window 0xbb..0xfe.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-173
scr_row_coverage: >-
  full for the row: the complete script.cpp:19-157 name table is compared
  against the Lean opNameWire table over every byte, including the fall-through
  "OP_UNKNOWN" window. The 113 named bytes and 143 unnamed bytes are both
  exercised. Display-only row (consensus: false in the ledger).
patches: none
source_citations:
  - script.cpp:19-157 (GetOpName; no default case, falls through to
    return "OP_UNKNOWN" at :157)
  - PDW68.lean:253-405 (opNameWire)
  - PDW68.lean:185-215 (opNameKnown row-face residue; the push-gap note)
  - PDW68.lean:415-430 (opNameWire_table spot checks)
trust_note: >
  Both legs are literal data tables, not handler semantics.  core_names.txt
  is transcribed from the pinned script.cpp switch; lean_names.txt is
  transcribed independently from PDW68.lean.  The generator assigns ids from
  the sorted union and deliberately does not compare the two tables, so a
  divergence is caught by Alive2 (different id for some reachable byte) and
  by SAW against the Cryptol table generated from core_names.txt.  The id
  assignment proves name identity, not the spelling beyond the data files'
  literals; a shared misreading of a name string is the known limit of a
  table cell.  No consensus, crypto, or execution semantics are claimed.
---
