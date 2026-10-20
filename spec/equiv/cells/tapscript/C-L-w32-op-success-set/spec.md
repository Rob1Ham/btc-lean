---
# Cell tapscript/C-L-w32-op-success-set
cell: C-L-w32-op-success-set
family: tapscript
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (total symbolic byte predicate)
precondition: |
  - Cell seam: `IsOpSuccess` over one wire byte.  No parse, no OP_SUCCESS
    pre-scan, no flags, no execution.
  - The input is any 8-bit wire value 0x00..0xff.  `opcodetype` in Core is an
    enum over int whose only observed property here is its numeric value, so
    the uint8 domain is exactly the domain of bytes that can appear in a
    script.
postcondition: |
  - `cell_is_op_success(w)` returns 1 iff w is in
    {80, 98, 126..129, 131..134, 137..138, 141..142, 149..153, 187..254},
    else 0, for every w in 0x00..0xff.
  - Both legs return the same value in both directions.  The complement is
    0..79, 81..97, 99..125, 130, 135..136, 139..140, 143..148, 154..186, 255.
  - OP_RESERVED (0x50 = 80) is in the set; the push opcodes 0x00..0x4f and
    0x51..0x60 are all outside it.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-152
scr_row_coverage: |
  full.  SCR-152 is exactly the set
  {80,98,126-129,131-134,137-138,141-142,149-153,187-254} at
  script.cpp:IsOpSuccess:365-371.  The cell is total over all 256 byte values
  and is not a closed witness.  The execution consequence (early success /
  DISCOURAGE_OP_SUCCESS) is SCR-153/154, a separate cell; this cell claims only
  the membership table the row names.
patches: none
source_citations:
  - script.cpp:365-371 (bool IsOpSuccess(const opcodetype& opcode))
  - script.h:604-605 (IsOpSuccess declaration)
  - spec/core/Bitcoin/Interpreter/Defs.lean:463-468 (isOpSuccessWire)
  - BIP342 "OP_SUCCESSx" table (the ledger row's byte list)
trust_note: >
  C is the verbatim IsOpSuccess body from script.cpp at the pin, wrapped in a
  uint8_t entry point.  L is a reviewed transliteration of the Lean predicate
  written in the Lean disjunction order (the twin has no IsOpSuccess handler, so
  mk_leaf.py emits nothing for it).  The SAW specification is an independent
  interval-table formulation in src/cell.cry; Alive2 compares the -O2
  canonical forms of the two IR functions directly (two-file mode,
  `--always-verify`).  No Core source patch is used.  No claim about parsing or
  execution is made.
mutant: >
  Proposed, not executed: change 149..153 to 149..154 in src/l_leaf.cpp.
  Expected Alive2 counterexample at w=154; SAW proof failure for the L leg.
---
